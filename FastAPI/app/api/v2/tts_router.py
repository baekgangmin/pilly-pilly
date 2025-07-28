#FastAPI\app\api\v2\tts_router.py
'''
from fastapi import APIRouter, BackgroundTasks, Query, Depends
from fastapi.responses import StreamingResponse, FileResponse
from app.core.dependencies import get_current_user  # 🔐 인증 미들웨어
#from app.services.tts_service import generate_tts_audio
#from app.utils.tts_file_utils import save_temp_audio_file, delete_file

import re
from pathlib import Path
from gtts import gTTS
from io import BytesIO

router = APIRouter()

@router.get("/tts", summary="TTS 텍스트 → MP3 스트리밍")
async def tts_direct(
    query: str = Query(..., description="음성으로 변환할 텍스트"), 
    lang: str = "ko", 
    #user=Depends(get_current_user)
    ):
    # 텍스트 정제 및 파일명 안전화
    safe_q = re.sub(r"[*_~`]+", "", query)

    # 메모리에 TTS 생성
    mp3_fp = BytesIO()
    tts = gTTS(safe_q, lang=lang)
    tts.write_to_fp(mp3_fp)
    mp3_fp.seek(0)

    return StreamingResponse(mp3_fp, media_type="audio/mpeg")


@router.get("/tts/temp", summary="오디오 RAM저장 -> 삭제")
async def speak_and_save(
    background_tasks: BackgroundTasks,
    text: str = Query(..., description="음성으로 변환할 텍스트"),
):
    buffer = generate_tts_audio(text)
    file_path, filename = save_temp_audio_file(buffer)
    background_tasks.add_task(delete_file, file_path)
    return FileResponse(path=file_path, media_type="audio/mpeg", filename=filename)
'''