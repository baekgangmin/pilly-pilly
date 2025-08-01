# app/services/dur_service.py

import os
import requests
from fastapi import HTTPException
from dotenv import load_dotenv

load_dotenv(dotenv_path=".env", override=True)
SERVICE_KEY = os.getenv("SERVICE_KEY")

# 모든 병용금기값 호출(100개제한)
MAX_RESULTS = 100
PAGINATED_ENDPOINTS = ["getUsjntTabooInfoList03"]

def get_dur_info(endpoint: str, item_seq: str) -> list:
    base_url = f"https://apis.data.go.kr/1471000/DURPrdlstInfoService03/{endpoint}"
    all_items = []
    page_no = 1
    num_of_rows = 100

    try:
        while True:
            params = {
                "serviceKey": SERVICE_KEY,
                "type": "json",
                "itemSeq": item_seq,
                "pageNo": page_no,
                "numOfRows": num_of_rows,
            }

            response = requests.get(base_url, params=params, timeout=10)
            response.raise_for_status()
            data = response.json()
            body = data.get("body", {})
            items = body.get("items", [])
            total_count = int(body.get("totalCount", 0))  # ✅ 실 데이터 기준

            # 항목 수집
            if isinstance(items, dict):
                all_items.append(items)
            elif isinstance(items, list):
                all_items.extend(items)

            # ✅ 수집 개수 제한 적용
            if len(all_items) >= MAX_RESULTS:
                all_items = all_items[:MAX_RESULTS]
                break

            if endpoint not in PAGINATED_ENDPOINTS or len(all_items) >= total_count:
                break

            page_no += 1

        return all_items

    except Exception as e:
        raise HTTPException(status_code=500, detail=f"DUR API 호출 실패: {str(e)}")
    
'''
# 정제 #
'''
def normalize_dur_info(endpoint: str, items: list) -> list:
    def extract_common_fields(item):
        normalized_item = {k.strip(): v for k, v in item.items()}
        return {
            "typeName": normalized_item.get("TYPE_NAME"),
            "itemName": item.get("ITEM_NAME"),
            "prohibitContent": item.get("PROHBT_CONTENT"),
            "remark": item.get("REMARK")
        }

    def extract_combination_fields(item):
        return {
            "typeName": item.get("TYPE_NAME"),
            "itemName": item.get("ITEM_NAME"),
            "mixtureItemName": item.get("MIXTURE_ITEM_NAME"),
            "mixtureIngredient": item.get("MIXTURE_INGR_KOR_NAME"),
            "prohibitContent": item.get("PROHBT_CONTENT"),
            "remark": item.get("REMARK")
        }

    normalized = []
    for item in items:
        if endpoint == "getUsjntTabooInfoList03":  # 병용금기
            normalized.append(extract_combination_fields(item))
        else:  # 나머지 DUR
            normalized.append(extract_common_fields(item))

    return [n for n in normalized if any(n.values())]