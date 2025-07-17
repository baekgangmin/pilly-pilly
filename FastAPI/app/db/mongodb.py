#app/db/mongodb.py

# 연결 설정 및 클라이언트 관리
from motor.motor_asyncio import AsyncIOMotorClient
from app.core.config import settings
from app.db.models import SearchLog, FavoriteLog, ChatbotLog

# MongoDB 연결
client = AsyncIOMotorClient(settings.mongodb_uri)
db = client[settings.mongodb_db_name]
collection = db[settings.mongodb_collection_name] #기존 서비스 전체 로그
favorite_collection = db[settings.mongodb_collection_name2] #즐겨찾기
chatbot_collection = db[settings.mongodb_collection_name3]  # 챗봇
itentify_all_collection = db[settings.mongodb_identify_name]  #식별검색 전체 약 캐시


# 로그 저장 함수
async def save_search_log(log: SearchLog):
    await collection.insert_one(log.model_dump())

# 즐겨찾기 저장 함수
async def save_favorite_log(log: FavoriteLog):
    await favorite_collection.insert_one(log.model_dump())

# 챗봇 로그 저장 함수
async def save_chatbot_log(log: ChatbotLog):
    await chatbot_collection.insert_one(log.model_dump())

