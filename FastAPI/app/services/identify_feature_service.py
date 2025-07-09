import os
import requests
from fastapi import HTTPException, Request
from app.core.config import settings
from app.utils.logger import logger
from app.db.mongodb import collection
from app.db.models import SearchLog

SERVICE_KEY = settings.service_key

async def fetch_pills_by_features(request: Request, front_text=None, back_text=None, shape=None, color=None):
    base_url = "https://apis.data.go.kr/1471000/MdcinGrnIdntfcInfoService02/getMdcinGrnIdntfcInfoList02"
    params = {
        "serviceKey": SERVICE_KEY,
        "type": "json",
        "pageNo": 1,
        "numOfRows": 3,
    }

    if front_text: params["PRINT_FRONT"] = front_text
    if back_text: params["PRINT_BACK"] = back_text
    if shape: params["DRUG_SHAPE"] = shape
    if color: params["COLOR_CLASS1"] = color

    try:
        response = requests.get(base_url, params=params, timeout=10)
        response.raise_for_status()
        result = response.json()
        items = result.get("body", {}).get("items", []) if isinstance(result, dict) else []

        # 로그 저장
        log = SearchLog(
            user_id=request.client.host,
            query=params,
            results=items
        )
        await collection.insert_one(log.dict())

        logger.info(f"🔍 feature search | user={request.client.host} | count={len(items)}")
        return items if isinstance(items, list) else []

    except Exception as e:
        logger.error(f"❌ API 호출 실패: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))
