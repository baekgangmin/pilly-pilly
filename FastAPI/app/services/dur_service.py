# app/services/dur_service.py

import os
import requests
from fastapi import HTTPException
from dotenv import load_dotenv

load_dotenv(dotenv_path=".env", override=True)
SERVICE_KEY = os.getenv("SERVICE_KEY")

def get_dur_info(endpoint: str, item_seq: str) -> dict:
    """
    DUR API에서 endpoint를 기준으로 요청을 보냄.
    endpoint 예시: getDurPrdlstInfoList03, getDurSeobangInfoList03 등
    """
    base_url = f"https://apis.data.go.kr/1471000/DURPrdlstInfoService03/{endpoint}"
    params = {
        "serviceKey": SERVICE_KEY,
        "type": "json",
        "itemSeq": item_seq,
        "pageNo": 1,
        "numOfRows": 10,
    }

    try:
        response = requests.get(base_url, params=params, timeout=10)
        response.raise_for_status()
        data = response.json()
        return data["body"]["items"] if "body" in data and "items" in data["body"] else {}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"DUR API 호출 실패: {str(e)}")
