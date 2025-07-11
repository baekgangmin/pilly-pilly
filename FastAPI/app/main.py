# app/main.py
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.api.v2.log_router import router as log_router_router
from app.api.v2.image_based import router as image_router
from app.api.v2.identify_feature_based import router as identify_feature_router


app = FastAPI(
    title="PilypPilly API",
    version="0.2.0",
    description="의약품 정보 조회"
)

# ✅ CORS 미들웨어 설정 추가
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # 개발 중에는 전체 허용
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# 실제 기능 라우터
app.include_router(log_router_router, prefix="/api/v2", tags=["item_seq에 대한 공공 API 통합 조회"])
app.include_router(image_router, prefix="/api/v2", tags=["이미지 기반 알약 예측 및 요약조회"])
app.include_router(identify_feature_router, prefix="/api/v2", tags=["알약 외형 기반 식별 검색 및 요약조회"])

