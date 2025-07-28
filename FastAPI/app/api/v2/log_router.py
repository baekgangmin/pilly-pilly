# app/api/v2/log_router.py
import time
from fastapi import APIRouter, Request, HTTPException, Depends
from typing import List, Dict

from app.utils.logger import log_to_mongo
from app.services.permit_service import get_permit_combined
from app.services.dur_service import get_dur_info
from app.services.dur_service import normalize_dur_info
from app.services.e_drug_service import get_edrug_info
from app.core.dependencies import get_current_user  # 🔐 인증 미들웨어

router = APIRouter()

@router.post("/log", summary="여러 item_seq에 대한 API 통합조회")
async def get_combined_info(
    request: Request, 
    item_seqs: List[str],
    user_id: str = Depends(get_current_user)
    ):
    start_time = time.time()
    try:
        final_result: Dict[str, dict] = {}

        for item_seq in item_seqs:
            # ✅ permit 정보
            permit = get_permit_combined(item_seq)

            # ✅ dur 정보
            endpoints = [
                "getUsjntTabooInfoList03",
                "getOdsnAtentInfoList03",
                "getSpcifyAgrdeTabooInfoList03",
                "getCpctyAtentInfoList03",
                "getPwnmTabooInfoList03"
            ]
            dur_result = {
                ep: normalize_dur_info(ep, get_dur_info(ep, item_seq))
                for ep in endpoints
            }
            # ✅ e약은요 정보
            edrug_result = get_edrug_info(item_seq)

            # 개별 result 구성
            item_result = {
                "permit": permit,
                "dur": dur_result,
                "edrug": edrug_result
            }

            final_result[item_seq] = item_result
            end_time = time.time()
            elapsed = round(end_time - start_time, 4)
            print(f"📌 [API /log] 처리 시간: {elapsed}초")

            # MongoDB 로그 저장 (item 단위)
            query = {"source": "multi", "item_seq": item_seq}
            await log_to_mongo(request, query, item_result, user_id)

        return {
            "message": "통합조회 및 로그 저장 완료",
            "results": final_result
        }

    except Exception as e:
        raise HTTPException(status_code=500, detail=f"❌ 서버 오류: {str(e)}")