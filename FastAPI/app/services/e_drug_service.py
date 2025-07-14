#e약은요 요약정보
# FastAPI\app\services\e_drug_service.py

import os
import requests
from fastapi import HTTPException
from dotenv import load_dotenv

load_dotenv(dotenv_path=".env", override=True)
SERVICE_KEY = os.getenv("SERVICE_KEY")

#+정제
def split_text(text):
    if not text:
        return []
    return [line.strip() for line in text.strip().split("\n") if line.strip()]
'''
def get_edrug_info(item_seq: str) -> dict:
    base_url = "https://apis.data.go.kr/1471000/DrbEasyDrugInfoService/getDrbEasyDrugList"
    params = {
        "serviceKey": SERVICE_KEY,
        "type": "json",
        "itemSeq": item_seq,
        "pageNo": 1,
        "numOfRows": 1,
    }

    try:
        response = requests.get(base_url, params=params, timeout=10)
        response.raise_for_status()
        data = response.json()
        items = data.get("body", {}).get("items", [])
        if not items:
            return {}

        raw = items[0]
        return {
            "itemName": raw.get("itemName"), #품목명
            "efcyQesitm": raw.get("efcyQesitm"), #효능
            "useMethodQesitm": raw.get("useMethodQesitm"), #사용법
            "atpnWarnQesitm": raw.get("atpnWarnQesitm"), #주의사항경고
            "atpnQesitm": raw.get("atpnQesitm"), #주의사항
            "intrcQesitm": raw.get("intrcQesitm"), #상호작용
            "seQesitm": raw.get("seQesitm") #부작용
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"e약은요 API 호출 실패: {str(e)}")
'''

def get_edrug_info(item_seq: str) -> dict:
    base_url = "https://apis.data.go.kr/1471000/DrbEasyDrugInfoService/getDrbEasyDrugList"
    params = {
        "serviceKey": SERVICE_KEY,
        "type": "json",
        "itemSeq": item_seq,
        "pageNo": 1,
        "numOfRows": 1,
    }

    try:
        response = requests.get(base_url, params=params, timeout=10)
        response.raise_for_status()
        data = response.json()
        items = data.get("body", {}).get("items", [])
        if not items:
            return {}

        raw = items[0]
        return {
            "itemName": raw.get("itemName"),
            "effect": split_text(raw.get("efcyQesitm")),         # 효능
            "dosage": split_text(raw.get("useMethodQesitm")),  # 사용법
            "warning": split_text(raw.get("atpnWarnQesitm")),    # 주의사항 경고
            "precautions": split_text(raw.get("atpnQesitm")),            # 주의사항
            "interactions": split_text(raw.get("intrcQesitm")),          # 상호작용
            "sideEffects": split_text(raw.get("seQesitm"))                 # 부작용
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"e약은요 API 호출 실패: {str(e)}")