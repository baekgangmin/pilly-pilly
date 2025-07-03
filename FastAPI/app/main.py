# app/main.py
from fastapi import FastAPI
from app.api import public_api

app = FastAPI(title="Public Drug API",
              docs_url="/docs",
              redoc_url="/redoc")

@app.get("/")
def root():
    return {"message": "Pilly API is running"}

# 라우터 등록
app.include_router(public_api.router, prefix="/pill", tags=["Pill"])

