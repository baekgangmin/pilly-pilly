# app/routers/pill_router.py

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from typing import Optional, List, Any, Dict
from app.services.pill_feature_api import fetch_pills_by_features

router = APIRouter(prefix="/pill", tags=["Pill API"])

class FeatureSearchRequest(BaseModel):
    front_text: Optional[str] = None
    back_text: Optional[str] = None
    shape: Optional[str] = None
    color: Optional[str] = None

class PillInfo(BaseModel):
    item_seq: str
    item_name: str
    shape: Optional[str]
    color: Optional[str]
    print_front: Optional[str]
    print_back: Optional[str]

@router.post("/feature-search", response_model=Dict[str, Any], summary="특징 기반 알약 검색", description="모양, 색상, 텍스트 기반으로 알약을 검색합니다.")
def search_pills_by_features(request: FeatureSearchRequest):
    results = fetch_pills_by_features(
        front_text=request.front_text,
        back_text=request.back_text,
        shape=request.shape,
        color=request.color,
    )
    return {"results": results}  # 딕셔너리형태