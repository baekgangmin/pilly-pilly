#FastAPI\app\services\identify_feature_service.py
import os
import requests
from fastapi import HTTPException, Request
from app.core.config import settings
from app.utils.logger import logger
from app.db.mongodb import collection
from app.db.models import SearchLog

SERVICE_KEY = os.getenv("SERVICE_KEY")

async def fetch_pills_by_features(
    request: Request,
    print_front: str = None,
    print_back: str = None,
    drug_shape: str = None,
    color_class1: str = None
):
    base_url = "https://apis.data.go.kr/1471000/MdcinGrnIdntfcInfoService02/getMdcinGrnIdntfcInfoList02"

    params = {
        "serviceKey": SERVICE_KEY,
        "type": "json",
        "pageNo": 1,
        "numOfRows": 100,
    }

    # 공공API 요구 사항: 대문자 파라미터 이름
    if print_front: params["PRINT_FRONT"] = print_front
    if print_back: params["PRINT_BACK"] = print_back
    if drug_shape: params["DRUG_SHAPE"] = drug_shape
    if color_class1: params["COLOR_CLASS1"] = color_class1

    try:
        response = requests.get(base_url, params=params, timeout=10)
        response.raise_for_status()
        result = response.json()

        # 공공 API 응답 구조: body > items
        items = result.get("body", {}).get("items", []) if isinstance(result, dict) else []

        # 로그 저장 시 타입 오류 방지 (None 제거 + results는 dict 형태)
        query = {"source": "identify"}
        if print_front: query["print_front"] = print_front
        if print_back: query["print_back"] = print_back
        if drug_shape: query["drug_shape"] = drug_shape
        if color_class1: query["color_class1"] = color_class1

        log = SearchLog(
            user_id=request.client.host,
            query=query,
            results={"items": items}  # ❗ list → dict 감싸기
        )
        await collection.insert_one(log.model_dump())

        logger.info(f"🔍 feature search | user={request.client.host} | count={len(items)}")
        return items if isinstance(items, list) else []

    except Exception as e:
        logger.error(f"❌ API 호출 실패: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))
    
