# app/api/v2/log_router.py

from fastapi import APIRouter, Request, HTTPException
from typing import List, Dict

from app.utils.logger import log_to_mongo
from app.services.permit_service import get_permit_combined
from app.services.dur_service import get_dur_info
# from app.services.type_service import get_type_detail
# from app.services.ingredient_service import get_ingredient_detail

router = APIRouter()

@router.post("/log", summary="여러 item_seq에 대한 API 통합조회")
async def get_combined_info(request: Request, item_seqs: List[str]):
    try:
        final_result: Dict[str, dict] = {}

        for item_seq in item_seqs:
            # ✅ permit 정보
            permit = get_permit_combined(item_seq)

            # ✅ dur 정보
            endpoints = [
                "getDurPrdlstInfoList03",
                "getUsjntTabooInfoList03",
                "getOdsnAtentInfoList03",
                "getSpcifyAgrdeTabooInfoList03",
                "getCpctyAtentInfoList03",
                "getPwnmTabooInfoList03"
            ]
            dur_result = {
                ep: (
                    get_dur_info(ep, item_seq)[0]
                    if isinstance(get_dur_info(ep, item_seq), list)
                    else {}
                )
                for ep in endpoints
            }

            # ✅ 개별 result 구성
            item_result = {
                "permit": permit,
                "dur": dur_result,
                # "type": ..., "ingredient": ... 추가 가능
            }

            final_result[item_seq] = item_result

            # ✅ MongoDB 로그 저장 (item 단위)
            query = {"source": "multi", "item_seq": item_seq}
            await log_to_mongo(request, query, item_result)

        return {
            "message": "✅ 통합조회 및 로그 저장 완료",
            "results": final_result
        }

    except Exception as e:
        raise HTTPException(status_code=500, detail=f"❌ 서버 오류: {str(e)}")
