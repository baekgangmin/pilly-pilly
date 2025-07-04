# app/main.py
from fastapi import FastAPI
from app.api import public_api
from app.routers import pill_router

app = FastAPI(
    title="약물 특징 기반 검색 API",
    description="FastAPI로 구현된 공공 API 연동 약품 식별 시스템",
    docs_url="/docs",
    redoc_url="/redoc"
)

app.include_router(public_api.router)
app.include_router(pill_router.router)

