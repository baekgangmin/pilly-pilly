'''# app/api/v2/image_resolve_router.py
from fastapi import APIRouter, HTTPException, Depends
from pydantic import BaseModel
from typing import Optional, List
from app.services.image_scrape_service import resolve_image_via_web
from app.core.rate_limit import rate_limit_user, concurrency_limit

router = APIRouter()

class ResolveReq(BaseModel):
    itemSeq: Optional[str] = None
    itemName: Optional[str] = None

class ResolveRes(BaseModel):
    itemSeq: Optional[str] = None
    imageUrl: Optional[str] = None
    source: str  # cache|mfds_html|health_html|none

@router.post(
    "/image-resolve", summary="이미지 스크래핑",
    response_model=ResolveRes, 
    dependencies=[Depends(rate_limit_user("image_resolve", limit=30, window_s=60)),
                  Depends(concurrency_limit("image_resolve", per_user=1, global_limit=4))]
)
async def resolve_web(req: ResolveReq):
    if not (req.itemSeq or req.itemName):
        raise HTTPException(status_code=400, detail={"code":"BAD_REQUEST","message":"itemSeq or itemName required"})
    url, src = await resolve_image_via_web(req.itemSeq, req.itemName)
    return ResolveRes(itemSeq=req.itemSeq, imageUrl=url, source=src)
'''

# app/api/v2/image_scrape_router.py
from __future__ import annotations
from typing import AsyncGenerator
from fastapi import APIRouter, HTTPException, Query
from starlette.responses import StreamingResponse
from app.services.image_cache_check_service import get_or_fetch_image

router = APIRouter()


async def _iter_gridfs(stream) -> AsyncGenerator[bytes, None]:
    """GridFS 파일을 chunk 단위로 스트리밍."""
    # motor GridOut.readchunk() 사용
    read = 0
    length = getattr(stream, "length", None)
    while True:
        chunk = await stream.readchunk()
        if not chunk:
            break
        read += len(chunk)
        yield chunk
        if length is not None and read >= length:
            break


@router.get("/image-scrape/{item_seq}" , summary="이미지 스크래핑",)
async def get_image(
    item_seq: str,
    refresh: bool = Query(False, description="true면 캐시 무시하고 재스크랩 시도"),
):
    """
    프록시 스트리밍:
    - GridFS에 저장된 이미지를 스트리밍으로 내려줌
    - 캐시 만료 또는 refresh=true면 스크래핑 → 저장 → 스트리밍
    """
    stream, ctype, info = await get_or_fetch_image(item_seq, force_refresh=refresh)
    if not stream or not ctype:
        raise HTTPException(status_code=404, detail="image not found")

    headers = {
        "Cache-Control": "public, max-age=86400",  # 프론트 캐싱(하루) — 필요에 맞게 조정
        "X-Image-From": info.get("from") or "",
        "X-Image-Source": (info.get("source") or ""),
    }
    return StreamingResponse(_iter_gridfs(stream), media_type=ctype, headers=headers)


@router.head("/image-scrape-check/{item_seq}" , summary="이미지 스크래핑 확인",)
async def head_image(item_seq: str):
    """
    간단 HEAD — 존재만 검사. (필요시 Content-Length 등 메타를 붙여도 됨)
    """
    stream, ctype, _ = await get_or_fetch_image(item_seq, force_refresh=False)
    if not stream or not ctype:
        raise HTTPException(status_code=404)
    # 길이가 있다면 같이 내려주기
    headers = {}
    if getattr(stream, "length", None) is not None:
        headers["Content-Length"] = str(stream.length)
    return StreamingResponse(iter(()), media_type=ctype, headers=headers)
