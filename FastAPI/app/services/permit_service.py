import requests
import os
from dotenv import load_dotenv
from fastapi import HTTPException

load_dotenv()
SERVICE_KEY = os.getenv("SERVICE_KEY")

def get_full_detail(item_seq: str):
    base_url = "https://apis.data.go.kr/1471000/DrugPrdtPrmsnInfoService06/getDrugPrdtPrmsnDtlInq05"
    params = {
        "serviceKey": SERVICE_KEY,
        "type": "json",
        "item_seq": item_seq,
        "pageNo": 1,
        "numOfRows": 10
    }

    try:
        response = requests.get(base_url, params=params, timeout=10)
        response.raise_for_status()
        data = response.json()
        return data
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"공공 API 호출 실패: {str(e)}")