#  app/api/public_api.py
from fastapi import APIRouter, Query
from app.services.drug_api import get_pill_by_name
from pydantic import BaseModel
from typing import Optional

router = APIRouter(prefix="/pill", tags=["Pill API"])

class PillDetail(BaseModel):
    item_seq: str
    item_name: str
    shape: Optional[str]
    color: Optional[str]

@router.get("/search", response_model=PillDetail, summary="알약 상세 검색", description="item_seq 기준으로 알약 상세 정보를 반환합니다.")
async def search_pill(
    item_seq: str = Query(..., description="알약 고유 식별자 (item_seq)")
):
    """
    ## 알약 상세 검색 API
    - 공공데이터포털을 통해 item_seq로 약품 상세 정보를 가져옵니다.
    - 실제 사용 시 FastAPI 백엔드에서 공공 API를 호출합니다.
    """
    return get_pill_by_name(item_seq)