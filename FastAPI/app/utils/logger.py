# 로그 저장
# app/utils/logger.py
import logging
from fastapi import Request
from app.db.models import SearchLog
from app.db.mongodb import collection

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
# MongoDB 로그 저장 함수
# ──────────────────────────────────────────────
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


async def log_to_mongo(request: Request, query: dict, results: dict):
    await save_search_log(request, query, results)
