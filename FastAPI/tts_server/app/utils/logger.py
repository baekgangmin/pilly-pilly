import logging
import time

logger = logging.getLogger("tts_logger")
logger.setLevel(logging.INFO)

# 로그 파일 저장 설정 (이미 되어 있다면 중복 금지)
file_handler = logging.FileHandler("logs/tts_inference.log", encoding='utf-8')
formatter = logging.Formatter("[%(asctime)s] %(levelname)s - %(message)s")
file_handler.setFormatter(formatter)
logger.addHandler(file_handler)