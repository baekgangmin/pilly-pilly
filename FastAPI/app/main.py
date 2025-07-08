# app/main.py
from fastapi import FastAPI
from app.api.v1.feature_based import router as feature_router
from app.api.v1.image_based import router as image_router
from app.api.v1 import feature_based, image_based
from app.api.v1.test_log import router as test_log_router

app = FastAPI(
    title="Pill Feature API",
    version="0.1.0",
    description="색상, 모양, 텍스트 기반 의약품 식별 API"
)

# 실제 기능 라우터
app.include_router(feature_router, prefix="/api/v1/pill", tags=["feature"])
app.include_router(image_router, prefix="/api/v1/image", tags=["image"])

#test
app.include_router(test_log_router, prefix="/api/v1/test", tags=["log"])
