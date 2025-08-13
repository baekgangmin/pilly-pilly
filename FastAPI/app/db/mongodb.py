#app/db/mongodb.py

# 연결 설정 및 클라이언트 관리
from motor.motor_asyncio import AsyncIOMotorClient
from app.core.config import settings
from app.db.models import SearchLog, FavoriteLog, ChatbotLog

# MongoDB 연결
client = AsyncIOMotorClient(settings.mongodb_uri)
db = client[settings.mongodb_db_name] #로그 저장
pill_db = client[settings.mongodb_db_pill_name] #데이터 저장
searchlog_collection = db[settings.mongodb_collection_name] #기존 서비스 전체 로그
favorite_collection = db[settings.mongodb_collection_name2] #즐겨찾기
chatbot_collection = db[settings.mongodb_collection_name3]  # 챗봇
auth_collection = db[settings.mongodb_collection_name4] #사용자인증
model_collection = db[settings.mongodb_collection_name5] # 모델 추론 결과
audit_collection = db[settings.mongodb_collection_name6] # 감사 로그 전용
itentify_all_collection = pill_db[settings.mongodb_identify_name]  #식별검색 전체 데이터
permit_info_all_collection = pill_db[settings.mongodb_permit_name] #허가목록 데이터
permit_detail_collection = pill_db[settings.mongodb_permit_name2] #허가상세정보 데이터



