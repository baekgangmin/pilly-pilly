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

# 콘솔 핸들러 구성
console_handler = logging.StreamHandler()
console_formatter = logging.Formatter("[%(asctime)s] %(levelname)s - %(message)s")
console_handler.setFormatter(console_formatter)
logger.addHandler(console_handler)

# 중복 핸들러 방지
if not logger.hasHandlers():
    logger.addHandler(console_handler)

# ──────────────────────────────────────────────
# MongoDB 로그 저장 함수
# ──────────────────────────────────────────────
async def save_search_log(request: Request, query: dict, results: list):
    try:
        log = SearchLog(
            user_id=request.client.host,
            query=query,
            results=results
        )
        await collection.insert_one(log.dict())
        logger.info(f"✅ 로그 저장 완료 | IP={request.client.host} | 결과 수={len(results)}")
    except Exception as e:
        logger.error(f"❌ 로그 저장 실패: {str(e)}")
