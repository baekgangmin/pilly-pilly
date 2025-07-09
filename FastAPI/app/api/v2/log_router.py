# app/api/v2/log_router.py

from fastapi import APIRouter, Request, HTTPException
from app.utils.logger import log_to_mongo
from app.services.permit_service import get_permit_detail, get_permit_list
from app.services.dur_service import get_dur_info
#from app.services.type_service import get_type_detail
#from app.services.ingredient_service import get_ingredient_detail

router = APIRouter()

@router.get("/log", summary="공공 API 통합 호출 및 로그 저장")
async def unified_log(
    request: Request,
    source: str,
    item_seq: str
):
    try:
        result = {}

        # ────────────────────────────────
        # 1. source 분기 - API 호출 처리
        # ────────────────────────────────
        if source == "permit":
            permit_detail = get_permit_detail(item_seq)
            permit_list = get_permit_list(item_seq)
            result["permit_detail"] = permit_detail or {}
            result["permit_list"] = permit_list or {}

        elif source == "dur":
            endpoints = [
                "getDurPrdlstInfoList03",  # 품목정보
                "getUsjntTabooInfoList03", # 병용금기
                "getOdsnAtentInfoList03",  # 노인주의
                "getSpcifyAgrdeTabooInfoList03",  # 특정연령
                "getCpctyAtentInfoList03", # 용량주의
                "getPwnmTabooInfoList03"   # 임부금기
            ]
            for ep in endpoints:
                api_result = get_dur_info(ep, item_seq)

                # ✅ 리스트 형태일 경우 첫 원소만 dict로 정제, 없으면 빈 dict
                if isinstance(api_result, list):
                    result[ep] = api_result[0] if api_result else {}
                elif isinstance(api_result, dict):
                    result[ep] = api_result
                else:
                    result[ep] = {}

        # elif source == "type":
        #     result["type"] = get_type_detail(item_seq) or {}

        # elif source == "ingredient":
        #     result["ingredient"] = get_ingredient_detail(item_seq) or {}

        else:
            raise HTTPException(status_code=400, detail="❌ 지원하지 않는 source입니다.")

        # ────────────────────────────────
        # 2. MongoDB 로그 저장
        # ────────────────────────────────
        query = {"source": source, "item_seq": item_seq}
        await log_to_mongo(request, query, result)

        # ────────────────────────────────
        # 3. 프론트로 반환
        # ────────────────────────────────
        return {
            "message": "✅ API 호출 성공",
            "results": result
        }

    except Exception as e:
        raise HTTPException(status_code=500, detail=f"❌ 서버 오류: {str(e)}")
