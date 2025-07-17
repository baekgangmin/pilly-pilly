#FastAPI\app\api\v2\tts_router.py

from fastapi import APIRouter, BackgroundTasks, Query
from fastapi.responses import StreamingResponse, FileResponse
from services.tts_service import generate_tts_audio
from utils.tts_file_utils import save_temp_audio_file, delete_file

router = APIRouter()

@router.post("/tts")
def tts_endpoint(text: str):
    audio = generate_tts_audio(text)
    return StreamingResponse(audio, media_type="audio/mpeg")


@router.get("/tts/temp")
def speak_and_save(
    background_tasks: BackgroundTasks,
    text: str = Query(..., description="음성으로 변환할 텍스트"),
):
    buffer = generate_tts_audio(text)
    file_path, filename = save_temp_audio_file(buffer)
    background_tasks.add_task(delete_file, file_path)
    return FileResponse(path=file_path, media_type="audio/mpeg", filename=filename)