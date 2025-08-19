# app/services/image_service.py
from __future__ import annotations

import os
from datetime import datetime, timedelta, timezone
from typing import Optional, Tuple, Dict, Any

from motor.motor_asyncio import AsyncIOMotorGridOut

from app.db.crud.image_scrape_cache import (
    get_meta,
    open_stream_by_item_seq,
    save_bytes,
)
from app.services.image_scrape_service import scrape_mfds_image


IMAGE_REFRESH_DAYS = int(os.getenv("IMAGE_REFRESH_DAYS", "30"))
REFRESH_TTL = timedelta(days=IMAGE_REFRESH_DAYS)


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


def _is_fresh(updated_at: Optional[datetime]) -> bool:
    if not updated_at:
        return False
    return (_utcnow() - updated_at) < REFRESH_TTL


async def get_or_fetch_image(
    item_seq: str,
    force_refresh: bool = False,
) -> Tuple[Optional[Any], Optional[str], Dict[str, Any]]:
    """
    1) 메타 캐시가 신선하면 → GridFS 스트림 반환
    2) 강제 갱신 또는 캐시 만료/없음 → 스크래핑 → 저장 → 스트림 반환
    3) 스크래핑 실패 & 기존 캐시 있으면 → 기존(오래된) 스트림 반환(stale=True)
    return: (stream, content_type, info_dict)
      - info_dict: {"from": "cache|scraped|stale", "source": "...", "meta": {...}}
    """
    meta = await get_meta(item_seq)
    if meta and not force_refresh and _is_fresh(meta.get("updatedAt")):
        stream_meta = await open_stream_by_item_seq(item_seq)
        if stream_meta:
            stream, meta2 = stream_meta
            return stream, meta2.get("contentType"), {"from": "cache", "source": meta2.get("source"), "meta": meta2}

    # 스크래핑 시도
    scraped = await scrape_mfds_image(item_seq)
    if scraped:
        data, ctype, source = scraped
        saved_meta = await save_bytes(
            item_seq=item_seq,
            data=data,
            content_type=ctype,
            source=source,
            filename=f"{item_seq}",
        )
        stream_meta = await open_stream_by_item_seq(item_seq)
        if stream_meta:
            stream, meta2 = stream_meta
            return stream, meta2.get("contentType"), {"from": "scraped", "source": source, "meta": meta2}

    # 스크래핑 실패 ─ 기존 캐시라도 있으면 stale로 반환
    if meta:
        stream_meta = await open_stream_by_item_seq(item_seq)
        if stream_meta:
            stream, meta2 = stream_meta
            return stream, meta2.get("contentType"), {"from": "stale", "source": meta2.get("source"), "meta": meta2}

    # 완전 실패
    return None, None, {"from": "none", "source": None, "meta": None}
