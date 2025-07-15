#FastAPI\app\api\v2\gemini_chatbot.py

from fastapi import APIRouter, Request
from pydantic import BaseModel
from app.services.gemini_client import ask_gemini
from app.utils.logger import log_chatbot_to_mongo  # ✅ 로그 저장 함수
from typing import Dict

router = APIRouter()

# ──────────────────────────────────────────────
# 요청 모델
# ──────────────────────────────────────────────
class PromptRequest(BaseModel):
    prompt: str

# ──────────────────────────────────────────────
# Gemini 추천 챗봇 엔드포인트
# ──────────────────────────────────────────────
@router.post("/chatbot")
async def get_chat_recommendation(request: Request, payload: PromptRequest) -> Dict:
    # Gemini 응답
    answer = ask_gemini(payload.prompt)

    # 로그 저장
    await log_chatbot_to_mongo(
        request=request,
        user_input=payload.prompt,
        answer=answer
    )

    return {
        "answer": answer
    }