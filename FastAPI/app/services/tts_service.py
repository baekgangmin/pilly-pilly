#FastAPI\app\services\tts_service.py

import re
from gtts import gTTS
from io import BytesIO

# 특수문자 정제
def clean_text(text: str) -> str:
    return re.sub(r"[*_~`.]+", "", text)

def generate_tts_audio(text: str) -> BytesIO:
    cleaned = clean_text(text)
    tts = gTTS(cleaned, lang="ko")
    mp3_fp = BytesIO()
    tts.write_to_fp(mp3_fp)
    mp3_fp.seek(0)
    return mp3_fp
