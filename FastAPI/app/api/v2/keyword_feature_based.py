# app\api\v2\keyword_feature_based.py
from fastapi import APIRouter, Request, Query, Depends
from app.services.permit_service import search_permit_by_keywords
from app.core.dependencies import get_current_user
from app.db.crud.user_auth import upsert_anonymous_user

router = APIRouter()

@router.get("/keyword-search", summary="통합검색 (제품명/성분 한글/영문)")
async def permit_unified_search(
    request: Request,
    keyword: str = Query(..., description="검색 키워드 (2자 이상, 공백/쉼표 구분)"),
    user_id: str = Depends(get_current_user)
):
    await upsert_anonymous_user(user_id, request)
    results = await search_permit_by_keywords(
        request, 
        keyword,
        user_id)
    return {
        "message": "✅ 통합검색 성공",
        "results": results
    }