# 선택형+생성형 챗봇
# FastAPI\app\services\gemini_client.py

import google.generativeai as genai
import os
import json
from app.core.config import settings
from google.api_core.exceptions import GoogleAPIError

# ──────────────────────────────────────────────
# Gemini API 키 설정
# ──────────────────────────────────────────────
'''
GEMINI_KEY_PATH = os.getenv("GEMINI_KEY_PATH")

if not os.path.exists(GEMINI_KEY_PATH):
    raise FileNotFoundError(f"GEMINI_KEY_PATH not found: {GEMINI_KEY_PATH}")

with open(GEMINI_KEY_PATH, "r") as f:
    key_data = json.load(f)

API_KEY = os.getenv("GOOGLE_API_KEY")
'''
genai.configure(api_key=settings.google_api_key)

# ──────────────────────────────────────────────
# 모델 초기화
# ──────────────────────────────────────────────
model = genai.GenerativeModel("gemini-pro")

# ──────────────────────────────────────────────
# 질문 처리 함수
# ──────────────────────────────────────────────
def ask_gemini(prompt: str) -> str:
    try:
        response = model.generate_content(prompt)
        return response.text.strip()
    except GoogleAPIError as api_err:
        return f"[API 오류] Gemini API 호출 실패: {api_err.message}"
    except Exception as e:
        return f"[예외] 처리 중 오류 발생: {str(e)}"

