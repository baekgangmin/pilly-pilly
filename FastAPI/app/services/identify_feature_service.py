#FastAPI\app\services\identify_feature_service.py
from fastapi import HTTPException, Request
from app.utils.logger import logger
from app.db.mongodb import itentify_all_collection, collection
from app.db.models import SearchLog
from pymongo import ASCENDING
import re

async def fetch_pills_by_features(
    request: Request,
    print_front: str = None,
    print_back: str = None,
    drug_shape: str = None,
    color_class1: str = None
):
    try:
        # 검색 조건 구성 (None 제거)
        query_filter = {}

        if print_front:
            query_filter["PRINT_FRONT"] = {"$regex": print_front, "$options": "i"}
        if print_back:
            query_filter["PRINT_BACK"] = {"$regex": f"^{re.escape(print_back)}$", "$options": "i"}
        if drug_shape:
            query_filter["DRUG_SHAPE"] = {"$regex": f"^{re.escape(drug_shape)}$", "$options": "i"}
        if color_class1:
            query_filter["COLOR_CLASS1"] = {"$regex": f"^{re.escape(color_class1)}$", "$options": "i"}

        # MongoDB에서 필터링 검색
        items = [item async for item in itentify_all_collection.find(query_filter)]  # 결과 안정성을 위해 정렬

        # 🪵 로그 추가
        logger.debug(f"[쿼리 조건] {query_filter}")
        logger.debug(f"[결과 수] {len(items)}")

        # MongoDB ObjectId 제거 (JSON 직렬화 오류 방지)
        for item in items:
            item.pop("_id", None)

        # 검색 로그 저장
        query_log = {"source": "identify"}
        if print_front: query_log["print_front"] = print_front
        if print_back: query_log["print_back"] = print_back
        if drug_shape: query_log["drug_shape"] = drug_shape
        if color_class1: query_log["color_class1"] = color_class1

        log = SearchLog(
            user_id=request.client.host,
            query=query_log,
            results={"items": items}
        )
        await collection.insert_one(log.model_dump())

        logger.info(f"🔍 feature search (from DB) | user={request.client.host} | count={len(items)}")
        return items

    except Exception as e:
        logger.error(f"❌ DB 검색 실패: {str(e)}")
        raise HTTPException(status_code=500, detail="DB 조회 오류가 발생했습니다.")
    
