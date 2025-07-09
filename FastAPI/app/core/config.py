# 환경변수 불러오기 및 설정
# 📁 app/core/config.py
from pydantic_settings import BaseSettings 
from dotenv import load_dotenv
import os

load_dotenv()

class Settings(BaseSettings):
    service_key: str
    mongodb_uri: str
    mongodb_db_name: str
    mongodb_collection_name: str

    class Config:
        env_file = ".env"  # .env 파일에서 자동으로 로드

# 인스턴스 생성
settings = Settings()