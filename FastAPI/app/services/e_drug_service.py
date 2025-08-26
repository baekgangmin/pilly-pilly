# FastAPI\app\services\e_drug_service.py
from __future__ import annotations

import os
import asyncio
from typing import Dict, Any, Optional, Tuple
from datetime import datetime, timedelta

import httpx
from json import JSONDecodeError

from app.core.errors import ExternalApiError

SERVICE_KEY = os.getenv("SERVICE_KEY")
if not SERVICE_KEY:
    raise RuntimeError("ENV SERVICE_KEY is not set")

BASE_URL = "https://apis.data.go.kr/1471000/DrbEasyDrugInfoService/getDrbEasyDrugList"

# httpx 설정
HTTP_TIMEOUT = httpx.Timeout(connect=3.0, read=5.0, write=5.0, pool=5.0)
HTTP_LIMITS = httpx.Limits(max_connections=50, max_keepalive_connections=20, keepalive_expiry=30.0)

# (옵션) 인메모리 캐시
USE_CACHE = os.getenv("EDRUG_USE_CACHE", "true").lower() == "true"
CACHE_TTL_MIN = int(os.getenv("EDRUG_CACHE_TTL_MIN", "60"))
_CACHE: dict[str, Tuple[datetime, Dict[str, Any]]] = {}


def split_text(text: Optional[str]) -> list[str]:
    if not text:
        return []
    return [line.strip() for line in text.strip().split("\n") if line.strip()]


async def _get_with_retry(
    client: httpx.AsyncClient,
    url: str,
    params: Dict[str, Any],
    tries: int = 2,
) -> Optional[httpx.Response]:
    last_exc: Optional[Exception] = None
    for i in range(tries):
        try:
            return await client.get(url, params=params)
        except (httpx.ConnectTimeout, httpx.ReadTimeout) as e:
            last_exc = e
            await asyncio.sleep(0.3 * (i + 1))
    return None


def _cache_get(item_seq: str) -> Optional[Dict[str, Any]]:
    if not USE_CACHE:
        return None
    now = datetime.utcnow()
    if item_seq in _CACHE:
        ts, val = _CACHE[item_seq]
        if now - ts < timedelta(minutes=CACHE_TTL_MIN):
            return val
        else:
            _CACHE.pop(item_seq, None)
    return None


def _cache_put(item_seq: str, data: Dict[str, Any]) -> None:
    if not USE_CACHE:
        return
    _CACHE[item_seq] = (datetime.utcnow(), data)


async def get_edrug_info(item_seq: str) -> Dict[str, Any]:
    """
    e약은요 요약정보 호출 (비동기 httpx + 재시도 + (옵션)캐시)
    반환 dict: 없으면 {}.
    예외는 ExternalApiError 로 래핑.
    """
    # 캐시
    cached = _cache_get(item_seq)
    if cached is not None:
        return cached

    params = {
        "serviceKey": SERVICE_KEY,
        "type": "json",
        "itemSeq": item_seq,
        "pageNo": 1,
        "numOfRows": 1,
    }

    try:
        async with httpx.AsyncClient(timeout=HTTP_TIMEOUT, limits=HTTP_LIMITS, follow_redirects=True) as client:
            r = await _get_with_retry(client, BASE_URL, params, tries=2)
            if r is None:
                raise ExternalApiError("eDrug timeout", status_code=504, context={"endpoint": "e_drug"})

            if r.status_code >= 500:
                raise ExternalApiError(f"eDrug upstream {r.status_code}", status_code=502, context={"endpoint": "e_drug"})
            if r.status_code >= 400:
                raise ExternalApiError(f"eDrug http {r.status_code}", status_code=502, context={"endpoint": "e_drug", "body": r.text})

            try:
                data = r.json()
            except (JSONDecodeError, ValueError) as e:
                raise ExternalApiError("eDrug invalid JSON", status_code=502, context={"endpoint": "e_drug", "msg": str(e)})

            items = (data.get("body", {}) or {}).get("items", []) if isinstance(data, dict) else []
            if not items:
                result: Dict[str, Any] = {}
                _cache_put(item_seq, result)
                return result

            raw = items[0]
            result = {
                "itemName": raw.get("itemName"),
                "effect": split_text(raw.get("efcyQesitm")),         # 효능
                "dosage": split_text(raw.get("useMethodQesitm")),    # 사용법
                "warning": split_text(raw.get("atpnWarnQesitm")),    # 주의사항 경고
                "precautions": split_text(raw.get("atpnQesitm")),    # 주의사항
                "interactions": split_text(raw.get("intrcQesitm")),  # 상호작용
                "sideEffects": split_text(raw.get("seQesitm")),      # 부작용
            }

            _cache_put(item_seq, result)
            return result

    except ExternalApiError:
        raise
    except Exception as e:
        raise ExternalApiError("eDrug failure", status_code=502, context={"endpoint": "e_drug", "msg": str(e)})
