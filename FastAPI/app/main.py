# app/main.py
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.api.v2 import log_router
from app.api.v2.log_router import router as log_router_router
from app.api.v2.image_based import router as image_router

from app.api.v2.identify_feature_router import router as identify_feature_router
#from app.api.v1.test_log import router as test_log_router


app = FastAPI(
    title="PilypPilly API",
    version="0.2.0",
    description="의약품 식별 API"
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
app.include_router(log_router_router, prefix="/api/v2/log", tags=["선택 item_seq 기반 통합 라우터"])
app.include_router(image_router, prefix="/api/v2", tags=["이미지 검색 요약정보 라우터"])

app.include_router(identify_feature_router, prefix="/api/v2", tags=["식별 검색 통합 라우터"])

#test-확인완료
#app.include_router(test_log_router, prefix="/api/v1/test", tags=["log"])
