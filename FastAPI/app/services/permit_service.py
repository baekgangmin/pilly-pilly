# (2), (3) 제품 허가 정보 : YOLO_cls->item_aeq 기반
#FastAPI\app\services\permit_service.py
import os
import requests
from fastapi import HTTPException
from dotenv import load_dotenv

load_dotenv(dotenv_path=".env", override=True)
SERVICE_KEY = os.getenv("SERVICE_KEY")

def get_permit_detail(item_seq: str) -> dict:
    base_url = "https://apis.data.go.kr/1471000/DrugPrdtPrmsnInfoService06/getDrugPrdtPrmsnDtlInq05"
    params = {
        "serviceKey": SERVICE_KEY,
        "type": "json",
        "item_seq": item_seq,
        "pageNo": 1,
        "numOfRows": 1,
    }

    try:
        response = requests.get(base_url, params=params, timeout=10)
        response.raise_for_status()
        data = response.json()
        return data["body"]["items"][0]  # 핵심 데이터 반환
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"API 호출 실패: {str(e)}")
    

def get_permit_list(item_seq: str) -> dict:
    base_url = "https://apis.data.go.kr/1471000/DrugPrdtPrmsnInfoService06/getDrugPrdtPrmsnInq06"
    params = {
        "serviceKey": SERVICE_KEY,
        "type": "json",
        "item_seq": item_seq,
        "pageNo": 1,
        "numOfRows": 1,
    }

    try:
        response = requests.get(base_url, params=params, timeout=10)
        response.raise_for_status()
        data = response.json()
        return data["body"]["items"][0]
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"[List] API 호출 실패: {str(e)}")