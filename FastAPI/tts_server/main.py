from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from starlette.responses import RedirectResponse
from dotenv import load_dotenv
from app.tts_router import router as tts_router
import os

env_path = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..', '.env'))
load_dotenv(dotenv_path=env_path)

# CORS 허용 도메인 읽기 (.env 내 "ALLOWED_ORIGINS" 키 필요)
allowed_origins = os.getenv("ALLOWED_ORIGINS_TTS", "*")
origins = [origin.strip() for origin in allowed_origins.split(",")]

app = FastAPI(
    title="TTS FastAPI Server",
    description="텍스트를 음성으로 변환하는 서버",
    version="0.1.0"
)

# ✅ CORS 미들웨어 등록
app.add_middleware(
    CORSMiddleware,
    allow_origins=origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(tts_router, tags=["tts 음성"])

