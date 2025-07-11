# app/services/dur_service.py

import os
import requests
from fastapi import HTTPException
from dotenv import load_dotenv

load_dotenv(dotenv_path=".env", override=True)
SERVICE_KEY = os.getenv("SERVICE_KEY")
'''
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
'''
def get_dur_info(endpoint: str, item_seq: str) -> list:
    """
    DUR API에서 endpoint를 기준으로 요청을 보냄.
    endpoint 예시: getDurPrdlstInfoList03, getDurSeobangInfoList03 등
    항상 리스트 형태로 응답값을 표준화하여 반환함.
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

        items = data.get("body", {}).get("items", [])
        if not items:
            return []
        if isinstance(items, list):
            return items
        elif isinstance(items, dict):
            return [items]
        else:
            return []
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"DUR API 호출 실패: {str(e)}")
    
'''
# 정제 #
'''
def normalize_dur_info(endpoint: str, items: list) -> list:
    def extract_common_fields(item):
        return {
            "type_name": item.get("TYPE_NAME"),
            "item_name": item.get("ITEM_NAME"),
            "prohibit_content": item.get("PROHBT_CONTENT"),
            "remark": item.get("REMARK")
        }

    def extract_combination_fields(item):
        return {
            "type_name": item.get("TYPE_NAME"),
            "item_name": item.get("ITEM_NAME"),
            "mixture_item_name": item.get("MIXTURE_ITEM_NAME"),
            "mixture_ingredient": item.get("MIXTURE_INGR_KOR_NAME"),
            "prohibit_content": item.get("PROHBT_CONTENT"),
            "remark": item.get("REMARK")
        }

    normalized = []
    for item in items:
        if endpoint == "getUsjntTabooInfoList03":  # 병용금기
            normalized.append(extract_combination_fields(item))
        else:  # 나머지 DUR
            normalized.append(extract_common_fields(item))

    return [n for n in normalized if any(n.values())]