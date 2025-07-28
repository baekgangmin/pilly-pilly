#FastAPI\app\api\v2\tts_router.py
from fastapi import APIRouter, Query, Request, Depends
#from app.core.dependencies import get_current_user
from pydantic import BaseModel
from fastapi.responses import StreamingResponse, JSONResponse
import time
import sys
import os
import shutil
import re
import json


# 경로설정
base_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', 'RealTime_zeroshot_TTS_ko'))
sys.path.append(base_dir)
from app.custom_tts import Custom_TTS

router = APIRouter()
tts = Custom_TTS()
tts.set_model(language='KR')

# 요청 바디 구조 정의
class TTSRequest(BaseModel):
    text: str

# 전처리: 줄바꿈, 특수문자 제거
def clean_text(text: str) -> str:
    text = re.sub(r"[*~_\\\"-]+", "", text)     # 특수문자 제거
    text = re.sub(r"\s*\n\s*", ". ", text)      # 줄바꿈 마침표로 치환
    text = re.sub(r"\s+", " ", text)            # 다중 공백 제거
    return text.strip()

# (1) POST: 텍스트 → 음성 파일 생성
@router.post("/tts")
async def generate_tts(req: TTSRequest):
    start_time = time.time()

    # 입력 텍스트를 안전하게 JSON 문자열로 직렬화
    payload = {"text": req.text}
    json_payload = json.dumps(payload, ensure_ascii=False)

    # JSON 문자열 → 텍스트만 추출
    text_only = json.loads(json_payload)["text"]

    # 텍스트 정제
    clean_input = clean_text(text_only)

    # 음성 생성
    tts.make_speech(clean_input)

    # 고유한 파일명으로 저장
    timestamp = int(time.time())
    src_path = os.path.join("output", "tmp.wav")
    result_filename = f"result_{timestamp}.wav"
    dst_path = os.path.join("output", result_filename)
    shutil.copy(src_path, dst_path)

    elapsed = round(time.time() - start_time, 4)
    print(f"📌 [TTS 처리 시간]: {elapsed}초")

    return {
        "message": "TTS 음성 생성 완료",
        "filename": result_filename,
        "elapsed": elapsed
    }

# (2) GET: 파일명으로 음성 반환
@router.get("/tts_stream")
async def get_tts_file(name: str = Query(..., description="생성된 wav 파일명")):
    file_path = os.path.join("output", name)

    if not os.path.exists(file_path):
        return {"error": f"{name} 파일이 존재하지 않습니다"}

    file_like = open(file_path, mode="rb")
    return StreamingResponse(file_like, media_type="audio/wav")
