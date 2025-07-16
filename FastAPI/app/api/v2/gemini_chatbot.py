#FastAPI\app\api\v2\gemini_chatbot.py
import time
from fastapi import APIRouter, Request, HTTPException
from typing import Dict, Any
from pydantic import BaseModel
from app.services.gemini_client import parse_drug_info_json, ask_gemini
from app.utils.logger import log_chatbot_to_mongo  # ✅ 로그 저장 함수
from typing import Dict

router = APIRouter()

# ──────────────────────────────────────────────
# 요청 모델
# ──────────────────────────────────────────────

class PromptRequest(BaseModel):
    drug_info: Dict[str, Any]
    user_input: str

# ──────────────────────────────────────────────
# Gemini 추천 챗봇 엔드포인트
# ──────────────────────────────────────────────
@router.post("/chatbot")
async def get_chat_recommendation(request: Request, payload: PromptRequest) -> Dict:
    start_time = time.time()
    # 파싱
    drug_summary = parse_drug_info_json(payload.drug_info)
    if drug_summary.startswith("[파싱 오류]"):
        raise HTTPException(status_code=400, detail=drug_summary)

    # Gemini 응답
    answer = ask_gemini(drug_summary, payload.user_input)

    # 로그 저장
    await log_chatbot_to_mongo(
        request=request,
        drug_info=payload.drug_info,
        drug_summary=drug_summary,
        user_input=payload.user_input,
        answer=answer
    )

    elapsed = round(time.time() - start_time, 4)
    print(f"📌 [API /챗봇] 처리 시간: {elapsed}초")

    return {
        "answer": answer
    }