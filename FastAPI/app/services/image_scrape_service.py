# app/services/image_scrape_service.py
from __future__ import annotations

import base64
import re
from typing import Optional, Tuple, Dict, List
from urllib.parse import urljoin

import httpx
from bs4 import BeautifulSoup

# 네 UA/헤더 – 필요시 .env에서 끌어오도록 바꿔도 됨
UA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) PillResolverBot/1.0"
BASE_MFDS = "https://nedrug.mfds.go.kr"

DEFAULT_HEADERS: Dict[str, str] = {
    "User-Agent": UA,
    "Referer": "https://nedrug.mfds.go.kr",
    "Accept-Language": "ko-KR,ko;q=0.9",
}

DATA_URI_RE = re.compile(
    r'data:image/(png|jpe?g|gif|webp);base64,([A-Za-z0-9+/=\s]+)',
    re.I | re.DOTALL,
)


def _set_reasonable_encoding(resp: httpx.Response, fallback: str = "utf-8") -> None:
    if resp.encoding:
        return
    ctype = resp.headers.get("Content-Type", "")
    if "euc-kr" in ctype.lower() or "cp949" in ctype.lower():
        resp.encoding = "euc-kr"
        return
    head = resp.content[:2048].decode("utf-8", errors="ignore")
    m = re.search(r'charset=([\w\-]+)', head, re.I)
    resp.encoding = m.group(1) if m else fallback


async def _fetch_image_bytes(client: httpx.AsyncClient, url: str) -> Optional[Tuple[bytes, str]]:
    """이미지 URL을 받아 바이트+콘텐츠타입 가져오기."""
    r = await client.get(url, timeout=10.0, follow_redirects=True)
    if r.status_code != 200:
        return None
    ctype = r.headers.get("Content-Type", "")
    if not ctype.lower().startswith("image/"):
        return None
    return r.content, ctype.split(";")[0].strip()


def _decode_data_uri(data_uri: str) -> Optional[Tuple[bytes, str]]:
    m = DATA_URI_RE.search(data_uri)
    if not m:
        return None
    mime = m.group(1).lower()
    b64 = re.sub(r"\s+", "", m.group(2))
    try:
        data = base64.b64decode(b64, validate=False)
        if len(data) < 1024:
            return None
        ctype = "image/jpeg" if mime in ("jpg", "jpeg") else f"image/{mime}"
        return data, ctype
    except Exception:
        return None


async def scrape_mfds_image(item_seq: str) -> Optional[Tuple[bytes, str, str]]:
    """
    MFDS 상세/캐시 페이지에서 이미지 바이트 추출.
    return: (bytes, content_type, source_tag) or None
    """
    async with httpx.AsyncClient(headers=DEFAULT_HEADERS, follow_redirects=True) as client:
        # 상세 페이지 (302로 cache 이동 가능)
        r = await client.get(
            f"{BASE_MFDS}/pbp/CCBBB01/getItemDetail",
            params={"itemSeq": item_seq},
            timeout=10.0,
        )
        if r.status_code != 200:
            return None

        _set_reasonable_encoding(r)
        html = r.text
        soup = BeautifulSoup(html, "lxml")

        # 1) data:image 직접
        #    (페이지에 data-uri로 박혀있는 경우)
        #    img[src^="data:image/"] 가 있으면 우선
        for img in soup.select("img[src]"):
            src = img.get("src", "")
            if src.startswith("data:image/"):
                got = _decode_data_uri(src)
                if got:
                    data, ctype = got
                    return data, ctype, "mfds_datauri"

        # 2) itemImageDownload 링크
        for img in soup.select("img[src]"):
            src = img.get("src", "")
            if "itemImageDownload" in src:
                abs_url = src if src.startswith("http") else urljoin(BASE_MFDS, src)
                got = await _fetch_image_bytes(client, abs_url)
                if got:
                    data, ctype = got
                    return data, ctype, "mfds_download"

        # 3) HTML 전체에서 백업 정규식 (상대/절대 경로)
        m = re.search(r"(?:https?:)?//nedrug\.mfds\.go\.kr[^\s\"'<>)]*itemImageDownload[^\s\"'<>)]*|/pbp/cmn/itemImageDownload[^\s\"'<>)]*", html, re.I)
        if m:
            raw = m.group(0).replace("\\/", "/")
            abs_url = raw if raw.startswith("http") else urljoin(BASE_MFDS, raw)
            got = await _fetch_image_bytes(client, abs_url)
            if got:
                data, ctype = got
                return data, ctype, "mfds_html_fallback"

        # 4) 마지막: HTML 내 data:image 스캔
        m2 = DATA_URI_RE.search(html)
        if m2:
            got = _decode_data_uri(m2.group(0))
            if got:
                data, ctype = got
                return data, ctype, "mfds_datauri_html"

    return None
