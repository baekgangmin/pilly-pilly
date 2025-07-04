
from fastapi import HTTPException
import os
import requests

SERVICE_KEY = os.getenv("SERVICE_KEY")

def fetch_pills_by_features(front_text=None, back_text=None, shape=None, color=None):
    base_url = "https://apis.data.go.kr/1471000/MdcinGrnIdntfcInfoService02/getMdcinGrnIdntfcInfoList02"
    params = {
        "serviceKey": SERVICE_KEY,
        "type": "json",
        "pageNo": 1,
        "numOfRows": 3,
    }

    if front_text: params["PRINT_FRONT"] = front_text
    if back_text: params["PRINT_BACK"] = back_text
    if shape: params["DRUG_SHAPE"] = shape
    if color: params["COLOR_CLASS1"] = color

    try:
        response = requests.get(base_url, params=params, timeout=10)
        response.raise_for_status()
        result = response.json()
        print("📦 응답 구조:", result)

        # case 1: dict 응답
        if isinstance(result, dict):
            items = result.get("body", {}).get("items", [])
            return items if isinstance(items, list) else []

        # case 2: list 응답
        elif isinstance(result, list):
            return result

        else:
            raise HTTPException(status_code=500, detail="응답 형식이 예상과 다릅니다.")

    except Exception as e:
        print("❌ API 예외 발생:", e)
        raise HTTPException(status_code=500, detail=str(e))