# app/api/v2/log_router.py
import time
from fastapi import APIRouter, Request, HTTPException, Depends
from typing import List, Dict
import traceback

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
        print(f"📥 [DEBUG] 요청 item_seqs: {item_seqs}")
        print(f"👤 [DEBUG] 요청 사용자 ID: {user_id}")

        final_result: Dict[str, dict] = {}

        for item_seq in item_seqs:
            print(f"🔍 [DEBUG] 현재 처리 중인 item_seq: {item_seq}")

            try:
                permit = get_permit_combined(item_seq)
                print(f"✅ [DEBUG] permit 완료")

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
                print(f"✅ [DEBUG] dur 완료")

                edrug_result = get_edrug_info(item_seq)
                print(f"✅ [DEBUG] edrug 완료")

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
                print(f"❌ [ERROR] item_seq={item_seq} 처리 중 오류 발생: {inner_e}")
                traceback.print_exc()

        elapsed = round(time.time() - start_time, 4)
        print(f"📌 [API /log] 총 처리 시간: {elapsed}초")

        return {
            "message": "통합조회 및 로그 저장 완료",
            "results": final_result
        }

    except Exception as e:
        print(f"🔥 [FATAL] 전체 처리 실패: {e}")
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=f"❌ 서버 오류: {str(e)}")