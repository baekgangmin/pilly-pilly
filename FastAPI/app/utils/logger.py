# 로그 저장
# app/utils/logger.py
import logging
from fastapi import Request
from app.db.models import SearchLog, FavoriteLog
from app.db.mongodb import collection, favorite_collection
from app.utils.formatter import seoul_now 

# ──────────────────────────────────────────────
# 로거 설정
# ──────────────────────────────────────────────
logger = logging.getLogger("pill-logger")
logger.setLevel(logging.INFO)

if not logger.handlers:
    handler = logging.StreamHandler()
    formatter = logging.Formatter("[%(asctime)s] %(levelname)s - %(message)s")
    handler.setFormatter(formatter)
    logger.addHandler(handler)


# ──────────────────────────────────────────────
# MongoDB 로그 저장 함수 (검색)
# ──────────────────────────────────────────────
# 내부 호출 함수
async def save_search_log(request: Request, query: dict, results: dict):
    try:
        log = SearchLog(
            user_id=request.client.host,
            query=query,
            results=results
        )
        await collection.insert_one(log.model_dump())
        logger.info(f"✅ 로그 저장 완료 | IP={request.client.host} | 결과 키 수={len(results)}")
    except Exception as e:
        logger.error(f"❌ 로그 저장 실패: {str(e)}")

#외부 호출 함수
async def log_to_mongo(request: Request, query: dict, results: dict):
    await save_search_log(request, query, results)


# ──────────────────────────────────────────────
# MongoDB 즐겨찾기 로그 저장 함수
# ──────────────────────────────────────────────
async def save_favorite_log(request: Request, item_seq: str, item_name: str, image_url: str, source: str = "app"):
    try:
        log = FavoriteLog(
            user_id=request.client.host,
            item_seq=item_seq,
            item_name=item_name,
            image_url=image_url,
            source=source,
            timestamp=seoul_now()
            # timestamp는 생략 시 자동 생성됨
        )
        await favorite_collection.insert_one(log.model_dump())
        logger.info(f"⭐ 즐겨찾기 저장 완료 | IP={request.client.host} | 약명={item_name}")
    except Exception as e:
        logger.error(f"❌ 즐겨찾기 저장 실패: {str(e)}")

# 외부 호출 함수
async def log_favorite_to_mongo(request: Request, item_seq: str, item_name: str, image_url: str, source: str = "app"):
    await save_favorite_log(request, item_seq, item_name, image_url, source)