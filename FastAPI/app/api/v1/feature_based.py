# 2-1, 2-2: 특징기반 식별 검색

# 📁 app/api/v1/feature_based.py
from fastapi import APIRouter, Request
from pydantic import BaseModel
from typing import Optional, Dict, Any
from app.services.identify_feature_service import fetch_pills_by_features

router = APIRouter(prefix="/v1", tags=["Feature Search"])

class FeatureSearchRequest(BaseModel):
    front_text: Optional[str] = None
    back_text: Optional[str] = None
    shape: Optional[str] = None
    color: Optional[str] = None

@router.post("/feature-search", response_model=Dict[str, Any])
async def search_pills_by_features_api(request: Request, body: FeatureSearchRequest):
    results = await fetch_pills_by_features(
        request=request,
        front_text=body.front_text,
        back_text=body.back_text,
        shape=body.shape,
        color=body.color,
    )
    return {"results": results}