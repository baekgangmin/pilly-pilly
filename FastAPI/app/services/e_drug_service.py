#e약은요 요약정보
# FastAPI\app\services\e_drug_service.py

import os
import requests
from fastapi import HTTPException
from dotenv import load_dotenv
from app.core.errors import ExternalApiError
from json import JSONDecodeError

load_dotenv(dotenv_path=".env", override=True)
SERVICE_KEY = os.getenv("SERVICE_KEY")

#+정제
def split_text(text):
    if not text:
        return []
    return [line.strip() for line in text.strip().split("\n") if line.strip()]


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
        try:
            data = response.json()
        except JSONDecodeError:
            raise ExternalApiError("eDrug invalid JSON", status_code=502, context={"endpoint": "e_drug"})
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
    except requests.exceptions.Timeout:
        raise ExternalApiError("eDrug timeout", status_code=504, context={"endpoint": "e_drug"})
    except requests.exceptions.HTTPError as e:
        code = e.response.status_code if e.response is not None else 502
        raise ExternalApiError(f"eDrug HTTP {code}", status_code=502, context={"endpoint": "e_drug"})
    except ExternalApiError:
        raise
    except Exception as e:
        raise ExternalApiError("eDrug failure", status_code=502, context={"msg": str(e)})