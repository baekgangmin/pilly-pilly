from fastapi import APIRouter, Request, Depends
from pydantic import BaseModel
from typing import Optional, List
from app.utils.logger import log_favorite_to_mongo
from app.utils.request_utils import get_user_ip  # IP 기반 사용자 식별 함수
from app.db.mongodb import favorite_collection

router = APIRouter()

# ──────────────────────────────────────────────
# 요청 바디용 스키마
# ──────────────────────────────────────────────
class FavoriteRequest(BaseModel):
    folder_name: str
    item_seq: str
    item_name: str
    image_url: Optional[str] = None
    source: Optional[str] = "app"

# ──────────────────────────────────────────────
# 즐겨찾기 로그 저장 엔드포인트
# ──────────────────────────────────────────────
@router.post("/favorite")
async def save_favorite_log_api(request: Request, payload: FavoriteRequest):
    await log_favorite_to_mongo(
        request=request,
        folder_name = payload.folder_name,
        item_seq=payload.item_seq,
        item_name=payload.item_name,
        image_url=payload.image_url,
        source=payload.source
    )
    return {
        "message": "즐겨찾기 로그 저장 완료",
        "folderName": payload.folder_name,
        "itemSeq": payload.item_seq,
        "itemName": payload.item_name,
        "imageUrl": payload.image_url,
        "source": payload.source
    }

# ──────────────────────────────────────────────
# 즐겨찾기 여부 확인용 API
# ──────────────────────────────────────────────
@router.get("/favorites", response_model=List[str])
async def get_favorite_item_seqs(user_id: str = Depends(get_user_ip)):
    """
    현재 사용자의 즐겨찾기 약물 item_seq 목록을 반환함.
    Flutter에서 item_seq 비교용으로 사용됨.
    """
    favorites = favorite_collection.find({"user_id": user_id})
    item_seqs = [f["item_seq"] for f in favorites]
    return item_seqs