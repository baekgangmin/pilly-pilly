# app/main.py
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.api.v2.log_router import router as log_router
from app.api.v2.favorite_log_router import router as favorite_router
from app.api.v2.image_based import router as image_router
from app.api.v2.identify_feature_based import router as identify_feature_router
from app.api.v2.gemini_chatbot import router as gemini_chatbot
from app.api.v2.tts_router import router as tts_router


app = FastAPI(
    title="PilypPilly API",
    version="0.1.1",
    description="의약품 정보 조회"
)

# ✅ CORS 미들웨어 설정 추가
app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://192.168.0.46:8080"],  # 동일 네트워크만 허용
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# 실제 기능 라우터
app.include_router(log_router, prefix="/api/v2", tags=["item_seq에 대한 공공 API 통합 조회 및 로그 저장"])
app.include_router(image_router, prefix="/api/v2", tags=["이미지 기반 알약 예측 및 요약조회"])
app.include_router(identify_feature_router, prefix="/api/v2", tags=["알약 외형 기반 식별 검색 및 요약조회"])
app.include_router(gemini_chatbot, prefix="/api/v2", tags=["Gemini 챗봇"])
app.include_router(tts_router, prefix="/api/v2", tags=["tts 변환적제삭제"])
app.include_router(favorite_router, prefix="/api/v2", tags=["즐겨찾기 저장"])

