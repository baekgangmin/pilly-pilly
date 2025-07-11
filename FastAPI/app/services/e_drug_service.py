#e약은요 요약정보
# FastAPI\app\services\e_drug_service.py

import os
import requests
from fastapi import HTTPException
from dotenv import load_dotenv

load_dotenv(dotenv_path=".env", override=True)
SERVICE_KEY = os.getenv("SERVICE_KEY")

#def get_edrug_info(endpoint: str, item_seq: str) -> dict:
