# FastAPI\app\api\v2\identify_feature_router.py

from fastapi import APIRouter, Request, Query
from app.services.identify_feature_service import fetch_pills_by_features

router = APIRouter()

@router.get("/feature-search", summary="알약 외형 기반 식별 검색")
async def identify_by_feature(
    request: Request,
    print_front: str = Query(None, description="알약 앞면 문자"),
    print_back: str = Query(None, description="알약 뒷면 문자"),
    drug_shape: str = Query(None, description="알약 모양"),
    color_class1: str = Query(None, description="알약 색상")
):
    try:
        # 외형 조건 기반 API 호출 및 로그 저장 포함
        result = await fetch_pills_by_features(
            request,
            print_front=print_front,
            print_back=print_back,
            drug_shape=drug_shape,
            color_class1=color_class1
        )

        return {
            "message": "✅ 알약 식별 성공",
            "results": result
        }

    except Exception as e:
        return {"error": f"❌ 처리 중 오류 발생: {str(e)}"}
