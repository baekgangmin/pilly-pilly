# app/main.py
from app.core.config import settings
from fastapi import FastAPI, Depends
from fastapi.middleware.cors import CORSMiddleware
from app.api.v2.auth_router import router as auth_router
from app.api.v2.log_router import router as log_router
from app.api.v2.favorite_log_router import router as favorite_router
from app.api.v2.image_based import router as image_router
from app.api.v2.identify_feature_based import router as identify_feature_router
from app.api.v2.gemini_chatbot import router as gemini_chatbot
from app.api.v2.admin_page import router as admin
from app.api.v2.keyword_feature_based import router as text_feature_based
from app.api.v2.image_scrape_router import router as image_scrape
from app.core.errors import register_exception_handlers
from app.core.rate_limit import RateLimitMiddleware
from starlette.staticfiles import StaticFiles
import logging
import os 

  
#전역 로깅 설정
os.makedirs("logs", exist_ok=True)

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
    handlers=[
        logging.FileHandler("logs/inference.log", encoding="utf-8"),
        logging.StreamHandler()
    ]
)
  
app = FastAPI(
    title="PilypPilly API",
    version="1.0.1",
    description="의약품 정보 조회",
)
#에러 전담 핸들러
register_exception_handlers(app) 

# 1) CORS 미들웨어 설정
origins = [origin.strip() for origin in settings.allowed_origins.split(",")]

app.add_middleware(
    CORSMiddleware,
    allow_origins=origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*", "X-ADMIN-KEY", "Content-Type", "Authorization"],
)

# 2) 전역 레이트리밋(실행 제한)
app.add_middleware(
    RateLimitMiddleware,
    user_limit=100, user_window=60,  # 사용자 기준 분당 100회
    ip_limit=60,  ip_window=60,      # IP 기준 분당 60회
)

# 어플 라우터
app.include_router(auth_router, tags=["토큰 발급"])
app.include_router(log_router, prefix="/api/v2", tags=["item_seq에 대한 공공 API 통합 조회 및 로그 저장"])
app.include_router(image_router, prefix="/api/v2", tags=["이미지 기반 알약 예측 및 요약조회"])
app.include_router(identify_feature_router, prefix="/api/v2", tags=["알약 외형 기반 식별 검색 및 요약조회"])
app.include_router(text_feature_based, tags=["키워드 통합검색 및 요약조회"])
app.include_router(gemini_chatbot, prefix="/api/v2", tags=["Gemini 챗봇"])
app.include_router(favorite_router, prefix="/api/v2", tags=["즐겨찾기 저장"])
app.include_router(image_scrape, tags=["이미지 스크래핑 조회"])

#웹 라우터
app.include_router(admin, tags=["관리자페이지"])