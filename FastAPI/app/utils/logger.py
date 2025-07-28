# 로그 저장
# app/utils/logger.py
import logging
from fastapi import Request
from typing import Dict, Any
from app.db.models import SearchLog, FavoriteLog, ChatbotLog
from app.db.mongodb import collection, favorite_collection, chatbot_collection
from app.utils.formatter import seoul_now 

# ─────────────────────────────
# 로거 설정
# ─────────────────────────────
logger = logging.getLogger("uvicorn")
logger.setLevel(logging.DEBUG)

if not logger.handlers:
    handler = logging.StreamHandler()
    formatter = logging.Formatter("[%(asctime)s] %(levelname)s - %(message)s")
    handler.setFormatter(formatter)
    logger.addHandler(handler)

# ─────────────────────────────
# MongoDB (검색) 로그 저장
# ─────────────────────────────
async def save_search_log(request: Request, user_id: str, query: dict, results: dict):
    try:
        log = SearchLog(
            user_id=user_id,
            query=query,
            results=results
        )
        await collection.insert_one(log.model_dump())
        logger.info(f"✅ 통합정보 로그 저장 완료 | USER_ID={user_id} | 결과 키 수={len(results)}")
    except Exception as e:
        logger.error(f"로그 저장 실패: {str(e)}")

async def log_to_mongo(request: Request, user_id: str, query: dict, results: dict):
    await save_search_log(request, user_id, query, results)

# ─────────────────────────────
# MongoDB (즐겨찾기) 로그 저장
# ─────────────────────────────
async def save_favorite_log(request: Request, user_id: str, folder_name: str, item_seq: str, item_name: str, image_url: str, source: str = "app"):
    try:
        log = FavoriteLog(
            user_id=user_id,
            folder_name=folder_name,
            item_seq=item_seq,
            item_name=item_name,
            image_url=image_url,
            source=source,
            timestamp=seoul_now()
        )
        await favorite_collection.insert_one(log.model_dump())
        logger.info(f"⭐ 즐겨찾기 저장 완료 | USER_ID={user_id} | 약명={item_name}")
    except Exception as e:
        logger.error(f"즐겨찾기 저장 실패: {str(e)}")

async def log_favorite_to_mongo(request: Request, user_id: str, folder_name: str, item_seq: str, item_name: str, image_url: str, source: str = "app"):
    await save_favorite_log(request, user_id, folder_name, item_seq, item_name, image_url, source)

# ─────────────────────────────
# MongoDB (챗봇) 로그 저장
# ─────────────────────────────
async def log_chatbot_to_mongo(request: Request, user_id: str, drug_info: Dict[str, Any], drug_summary: str, user_input: str, answer: str, source: str = "chatbot"):
    try:
        log = ChatbotLog(
            user_id=user_id,
            drug_info=drug_info,
            drug_summary=drug_summary,
            user_input=user_input,
            answer=answer,
            source=source,
            timestamp=seoul_now()
        )
        await chatbot_collection.insert_one(log.model_dump())
        logger.info(f"🤖 챗봇 로그 저장 완료 | USER_ID={user_id} | 입력={len(user_input)}")
    except Exception as e:
        logger.error(f"챗봇 로그 저장 실패: {str(e)}")
