# app/api/v2/log_router.py
import time
from fastapi import APIRouter, Request, HTTPException, Depends
from typing import List, Dict
import traceback

from app.services.permit_service import get_permit_combined
from app.services.dur_service import get_dur_info
from app.services.dur_service import normalize_dur_info
from app.services.e_drug_service import get_edrug_info
from app.services.log_service import log_to_mongo
from app.core.dependencies import get_current_user  # 🔐 인증 미들웨어
from app.db.crud.user_auth import upsert_anonymous_user
from app.utils.logger import logger_drugs

router = APIRouter()

@router.post("/log", summary="여러 item_seq에 대한 API 통합조회")
async def get_combined_info(
    request: Request, 
    item_seqs: List[str],
    user_id: str = Depends(get_current_user)
):
    start_time = time.time()
    await upsert_anonymous_user(user_id, request)
    try:
        print(f"📥 [DEBUG] 요청 item_seqs: {item_seqs}")
        print(f"👤 [DEBUG] 요청 사용자 ID: {user_id}")

        final_result: Dict[str, dict] = {}

        for item_seq in item_seqs:
            print(f"🔍 [DEBUG] 현재 처리 중인 item_seq: {item_seq}")

            try:
                permit = await get_permit_combined(item_seq)

                dur_result = {
                    ep: normalize_dur_info(ep, get_dur_info(ep, item_seq))
                    for ep in [
                        "getUsjntTabooInfoList03",
                        "getOdsnAtentInfoList03",
                        "getSpcifyAgrdeTabooInfoList03",
                        "getCpctyAtentInfoList03",
                        "getPwnmTabooInfoList03"
                    ]
                }

                edrug_result = get_edrug_info(item_seq)

                item_result = {
                    "permit": permit,
                    "dur": dur_result,
                    "edrug": edrug_result
                }

                final_result[item_seq] = item_result

                query = {"source": "multi", "item_seq": item_seq}
                await log_to_mongo(request, user_id, query, item_result)
                print(f"📝 [DEBUG] 로그 저장 완료")

            except Exception as inner_e:
                logger_drugs.error(f"❌ item_seq={item_seq} 처리 중 오류: {inner_e}")
                logger_drugs.error(traceback.format_exc())

        elapsed = round(time.time() - start_time, 4)
        logger_drugs.info(
            f"[약 정보 검색] user_id={user_id} | item_seqs={','.join(item_seqs)} | 총 처리 시간={elapsed}초"
        )
        print(f"📌 [API /log] 총 처리 시간: {elapsed}초")

        return {
            "message": "통합조회 및 로그 저장 완료",
            "results": final_result
        }

    except Exception as e:
        print(f"🔥 [FATAL] 전체 처리 실패: {e}")
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=f"❌ 서버 오류: {str(e)}")