# app/services/custom_tts_service.py

from pathlib import Path
from custom_tts import Custom_TTS  # import 위치는 실제 경로에 따라 수정

# 전역 TTS 객체 (서버 로드시 1회 로딩)
tts_module = Custom_TTS()
tts_module.set_model(language='KR')  # 최초 한 번 로드
