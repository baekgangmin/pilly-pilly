# app/api/v2/log_router.py (변경 발췌)
import asyncio
import anyio
from fastapi import APIRouter, Request, HTTPException, Depends
from typing import List, Dict
import traceback

from app.services.permit_service import get_permit_combined
from app.services.dur_service import get_dur_info, normalize_dur_info  # get_dur_info: async
from app.services.e_drug_service import get_edrug_info                # 이제 async
from app.services.log_service import log_to_mongo
from app.core.dependencies import get_current_user
from app.db.crud.user_auth import upsert_anonymous_user
from app.utils.logger import logger_drugs

router = APIRouter()

DUR_ENDPOINTS = [
    "getUsjntTabooInfoList03",
    "getOdsnAtentInfoList03",
    "getSpcifyAgrdeTabooInfoList03",
    "getCpctyAtentInfoList03",
    "getPwnmTabooInfoList03",
]

@router.post("/log", summary="여러 item_seq에 대한 API 통합조회")
async def get_combined_info(
    request: Request, 
    item_seqs: List[str],
    user_id: str = Depends(get_current_user)
):
    start = anyio.current_time()
    await upsert_anonymous_user(user_id, request)
    try:
        final_result: Dict[str, dict] = {}

        for item_seq in item_seqs:
            try:
                # 허가정보, DUR들, eDrug를 동시에 실행
                async def _permit():
                    with anyio.move_on_after(6.0) as scope:
                        p = await get_permit_combined(item_seq)
                    return {} if scope.cancel_called else p

                async def _one_dur(ep: str):
                    with anyio.move_on_after(5.0) as scope:
                        items = await get_dur_info(ep, item_seq)
                    return ep, ([] if scope.cancel_called else items)

                async def _edrug():
                    with anyio.move_on_after(5.0) as scope:
                        data = await get_edrug_info(item_seq)   # ← 여기 await 추가
                    return {} if scope.cancel_called else data

                dur_tasks = [_one_dur(ep) for ep in DUR_ENDPOINTS]
                permit, dur_pairs, edrug_result = await asyncio.gather(
                    _permit(),
                    asyncio.gather(*dur_tasks),
                    _edrug(),
                )

                dur_result = {ep: normalize_dur_info(ep, items) for ep, items in dur_pairs}

                item_result = {
                    "permit": permit,
                    "dur": dur_result,
                    "edrug": edrug_result,
                }
                final_result[item_seq] = item_result

                query = {"source": "multi", "item_seq": item_seq}
                await log_to_mongo(request, user_id, query, item_result)

            except Exception as inner_e:
                logger_drugs.error(f"❌ item_seq={item_seq} 처리 중 오류: {inner_e}")
                logger_drugs.error(traceback.format_exc())

        elapsed = round(anyio.current_time() - start, 4)
        logger_drugs.info(f"[약 정보 검색] user_id={user_id} | item_seqs={','.join(item_seqs)} | 총 처리 시간={elapsed}s")
        return {"message": "통합조회 및 로그 저장 완료", "results": final_result}

    except Exception as e:
        logger_drugs.error(f"[FATAL] 전체 처리 실패: {e}")
        logger_drugs.error(traceback.format_exc())
        raise HTTPException(status_code=500, detail=f"❌ 서버 오류: {str(e)}")
