#app/db/mongodb.py

# 연결 설정 및 클라이언트 관리
from motor.motor_asyncio import AsyncIOMotorClient
from app.core.config import settings
from app.db.models import SearchLog

# MongoDB 연결
client = AsyncIOMotorClient(settings.mongodb_uri)
db = client[settings.mongodb_db_name]
collection = db[settings.mongodb_collection_name]

# 로그 저장 함수
async def save_search_log(log: SearchLog):
    await collection.insert_one(log.model_dump())

