#FastAPI\app\services\tts_service.py
'''
import re
from gtts import gTTS
from io import BytesIO

# 특수문자 정제
def clean_text(text: str) -> str:
    return re.sub(r"[*_~`.]+", "", text)

def generate_tts_audio(text: str) -> BytesIO:
    cleaned = clean_text(text)
    print(f"[TTS 요청] 정제된 텍스트: {cleaned}")
    mp3_fp = BytesIO()
    tts = gTTS(cleaned, lang="ko")
    tts.write_to_fp(mp3_fp)
    mp3_fp.seek(0)
    print(f"[TTS 완료] MP3 크기: {mp3_fp.getbuffer().nbytes} bytes")
    return mp3_fp
'''