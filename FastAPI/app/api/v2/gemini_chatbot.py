#FastAPI\app\api\v2\gemini_chatbot.py
import time
from fastapi import APIRouter, Request, HTTPException, UploadFile, File, Form
from typing import Dict, Any, Optional
from PIL import Image
from pydantic import BaseModel
from app.services.gemini_client import parse_drug_info_json, ask_gemini
from app.services.gemini_image_model import ask_gemini_with_image
from app.utils.logger import log_chatbot_to_mongo  # ✅ 로그 저장 함수
from typing import Dict
import io

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
@router.post("/chatbot", summary="약정보+사용자 질문")
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
    print(f"📌 [API /챗봇-사용자 질문] 처리 시간: {elapsed}초")

    return {
        "answer": answer
    }


#-----------------
# gemini 이용 모델
#----------------
class PromptRequest2(BaseModel):
    user_input: str
    image_obj: str

@router.post("/chatbot/gemini", summary="알약 외형정보")
async def get_chat_model(
    user_input: str = Form(...), # 텍스트 필드는 Form(...)으로 받습니다.
    image_file: Optional[UploadFile] = File(None) # 이미지 파일은 File(...)로 받습니다.
) -> Dict:
    start_time = time.time()
    
    image_to_process = None
    if image_file:
        try:
            # UploadFile의 내용을 비동기적으로 읽어옵니다.
            image_bytes = await image_file.read()
            # 바이트 스트림을 PIL Image 객체로 변환합니다.
            image_to_process = Image.open(io.BytesIO(image_bytes))
        except Exception as e:
            # 이미지 파일이 유효하지 않거나 처리 중 오류 발생 시
            raise HTTPException(status_code=400, detail=f"이미지 파일 처리 중 오류 발생: {str(e)}")

    # Gemini 응답
    # ask_gemini_with_image 함수에 PIL Image 객체를 전달합니다.
    answer = ask_gemini_with_image(
        user_input="user_input",     # Form으로 받은 user_input 사용
        image_obj=image_to_process # 처리된 PIL Image 객체 전달
    )

    elapsed = round(time.time() - start_time, 4)
    print(f"📌 [API /챗봇-외형식별] 처리 시간: {elapsed}초")

    return {
        "answer": answer
    }