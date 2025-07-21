# app/api/v2/tts_router.py

from fastapi import APIRouter, Query
from fastapi.responses import StreamingResponse
from app.services.custom_tts_service import tts_module

import re
import tempfile
from pydub import AudioSegment
from io import BytesIO

router = APIRouter()

@router.get("/tts", summary="Custom TTS 텍스트 → MP3 스트리밍")
async def tts_custom(q: str = Query(..., description="음성으로 변환할 텍스트")):
    # 1. 텍스트 정제
    safe_q = re.sub(r"[*_~`]+", "", q)

    # 2. TTS 생성 (WAV)
    output_wav_path = tts_module.make_speech(safe_q)

    # 3. WAV → MP3 변환 (메모리로)
    audio = AudioSegment.from_wav(output_wav_path)
    mp3_fp = BytesIO()
    audio.export(mp3_fp, format="mp3")
    mp3_fp.seek(0)

    return StreamingResponse(mp3_fp, media_type="audio/mpeg")
