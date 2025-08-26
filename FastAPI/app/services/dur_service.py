# app/services/dur_service.py
from __future__ import annotations
import os
import asyncio
from typing import Dict, Any, List, Optional, Tuple
from datetime import datetime, timedelta

import httpx
from json import JSONDecodeError

from app.core.errors import ExternalApiError 

# ──────────────────────────────────────────────────────────────────────────────
# 환경설정
# ──────────────────────────────────────────────────────────────────────────────
SERVICE_KEY = os.getenv("SERVICE_KEY") 
if not SERVICE_KEY:
    # 서비스키 누락은 개발 초반에 바로 터지도록
    raise RuntimeError("ENV SERVICE_KEY is not set")

# 네트워크/재시도/커넥션 관리
HTTP_TIMEOUT = httpx.Timeout(connect=3.0, read=5.0, write=5.0, pool=5.0)
HTTP_LIMITS = httpx.Limits(max_connections=50, max_keepalive_connections=20, keepalive_expiry=30.0)

# 전체 API 상수
BASE_PREFIX = "https://apis.data.go.kr/1471000/DURPrdlstInfoService03"
MAX_RESULTS = 100
PAGINATED_ENDPOINTS = {"getUsjntTabooInfoList03"}  # 병용금기만 페이지네이션

# (옵션) 인메모리 캐시
USE_CACHE = os.getenv("DUR_USE_CACHE", "true").lower() == "true"
CACHE_TTL_MIN = int(os.getenv("DUR_CACHE_TTL_MIN", "60"))  # 기본 60분
_CACHE: dict[Tuple[str, str], Tuple[datetime, List[Dict[str, Any]]]] = {}

# ──────────────────────────────────────────────────────────────────────────────
# 내부 유틸
# ──────────────────────────────────────────────────────────────────────────────
async def _get_with_retry(
    client: httpx.AsyncClient,
    url: str,
    params: Dict[str, Any],
    tries: int = 2,
) -> Optional[httpx.Response]:
    """연결/읽기 타임아웃에 대해 짧게 재시도."""
    last_exc: Optional[Exception] = None
    for i in range(tries):
        try:
            return await client.get(url, params=params)
        except (httpx.ConnectTimeout, httpx.ReadTimeout) as e:
            last_exc = e
            await asyncio.sleep(0.3 * (i + 1))
    return None

def _cache_get(endpoint: str, item_seq: str) -> Optional[List[Dict[str, Any]]]:
    if not USE_CACHE:
        return None
    key = (endpoint, item_seq)
    now = datetime.utcnow()
    if key in _CACHE:
        ts, val = _CACHE[key]
        if now - ts < timedelta(minutes=CACHE_TTL_MIN):
            return val
        else:
            _CACHE.pop(key, None)
    return None

def _cache_put(endpoint: str, item_seq: str, items: List[Dict[str, Any]]) -> None:
    if not USE_CACHE:
        return
    _CACHE[(endpoint, item_seq)] = (datetime.utcnow(), items)

# ──────────────────────────────────────────────────────────────────────────────
# 메인 함수 (비동기)
# ──────────────────────────────────────────────────────────────────────────────
async def get_dur_info(endpoint: str, item_seq: str) -> List[Dict[str, Any]]:
    """
    DUR 엔드포인트 호출 (비동기 httpx + 재시도 + (옵션)캐시 + 페이지네이션)
    반환: items(list[dict]) — 최대 MAX_RESULTS 까지
    예외: ExternalApiError 로 래핑
    """
    # 1) 캐시 확인
    cached = _cache_get(endpoint, item_seq)
    if cached is not None:
        return cached

    base_url = f"{BASE_PREFIX}/{endpoint}"
    all_items: List[Dict[str, Any]] = []
    page_no = 1
    num_of_rows = 100

    try:
        async with httpx.AsyncClient(timeout=HTTP_TIMEOUT, limits=HTTP_LIMITS, follow_redirects=True) as client:
            while True:
                params = {
                    "serviceKey": SERVICE_KEY,
                    "type": "json",
                    "itemSeq": item_seq,
                    "pageNo": page_no,
                    "numOfRows": num_of_rows,
                }

                r = await _get_with_retry(client, base_url, params, tries=2)
                if r is None:
                    raise ExternalApiError("DUR timeout", status_code=504, context={"endpoint": endpoint})

                # 5xx → 업스트림 문제로 간주
                if r.status_code >= 500:
                    raise ExternalApiError(f"DUR upstream {r.status_code}", status_code=502, context={"endpoint": endpoint})

                # 4xx → 파라미터/키 문제일 수 있음 (운영상 502로 묶어도 무방)
                if r.status_code >= 400:
                    raise ExternalApiError(f"DUR http {r.status_code}", status_code=502, context={"endpoint": endpoint, "body": r.text})

                # JSON 파싱
                try:
                    data = r.json()
                except (JSONDecodeError, ValueError) as e:
                    raise ExternalApiError("DUR invalid JSON", status_code=502, context={"endpoint": endpoint, "msg": str(e)})

                body = data.get("body", {}) if isinstance(data, dict) else {}
                items = body.get("items", [])
                total_count = int(body.get("totalCount", 0) or 0)

                # 항목 수집
                if isinstance(items, dict):
                    all_items.append(items)
                elif isinstance(items, list):
                    all_items.extend(items)

                # 수집 개수 제한
                if len(all_items) >= MAX_RESULTS:
                    all_items = all_items[:MAX_RESULTS]
                    break

                # 페이지네이션 종료 조건
                if endpoint not in PAGINATED_ENDPOINTS:
                    break
                # total_count가 0이거나 이미 다 모았으면 종료
                if total_count == 0 or len(all_items) >= total_count:
                    break

                page_no += 1

        # 캐시 저장
        _cache_put(endpoint, item_seq, all_items)
        return all_items

    except ExternalApiError:
        raise
    except Exception as e:
        # 기타 예외는 502로 래핑
        raise ExternalApiError("DUR failure", status_code=502, context={"endpoint": endpoint, "msg": str(e)})

# ──────────────────────────────────────────────────────────────────────────────
# 정제
# ──────────────────────────────────────────────────────────────────────────────
def normalize_dur_info(endpoint: str, items: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
    def extract_common_fields(item: Dict[str, Any]) -> Dict[str, Any]:
        normalized_item = {k.strip(): v for k, v in item.items()}
        return {
            "typeName": normalized_item.get("TYPE_NAME"),
            "itemName": item.get("ITEM_NAME"),
            "prohibitContent": item.get("PROHBT_CONTENT"),
            "remark": item.get("REMARK"),
        }

    def extract_combination_fields(item: Dict[str, Any]) -> Dict[str, Any]:
        return {
            "typeName": item.get("TYPE_NAME"),
            "itemName": item.get("ITEM_NAME"),
            "mixtureItemName": item.get("MIXTURE_ITEM_NAME"),
            "mixtureIngredient": item.get("MIXTURE_INGR_KOR_NAME"),
            "prohibitContent": item.get("PROHBT_CONTENT"),
            "remark": item.get("REMARK"),
        }

    normalized: List[Dict[str, Any]] = []
    for item in items or []:
        if endpoint == "getUsjntTabooInfoList03":  # 병용금기
            normalized.append(extract_combination_fields(item))
        else:
            normalized.append(extract_common_fields(item))

    # 빈 객체 제거
    return [n for n in normalized if any(n.values())]

