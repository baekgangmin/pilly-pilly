#FastAPI\app\utils\tts_file_utils.py

import os
import uuid
from datetime import datetime
from typing import Tuple

TEMP_DIR = "FastAPI/temp_audio"

# 저장 함수
def save_temp_audio_file(buffer) -> Tuple[str, str]:
    os.makedirs(TEMP_DIR, exist_ok=True)
    filename = f"{uuid.uuid4().hex}.mp3"
    file_path = os.path.join(TEMP_DIR, filename)

    with open(file_path, "wb") as f:
        f.write(buffer.read())
    
    return file_path, filename


#삭제 함수 
def delete_file(path: str):
    try:
        os.remove(path)
    except FileNotFoundError:
        pass
