# app/api/v1/permit_log.py
from fastapi import APIRouter, Request, Query, HTTPException
from app.services.permit_service import get_full_detail
from app.utils.logger import save_search_log

router = APIRouter()

@router.get("/permit/log", summary="제품 허가 상세정보 + 로그 저장")
async def permit_log_endpoint(
    request: Request,
    item_seq: str = Query(..., description="제품 고유 item_seq")
):
    # 1. API 호출
    try:
        result = get_full_detail(item_seq)
        items = result.get("body", {}).get("items", [])
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

    # 2. 로그 저장
    query = {"item_seq": item_seq}
    results = items if items else []
    await save_search_log(request, query, results)

    # 3. 응답 반환
    return {
        "message": "✅ 제품 허가 상세정보 조회 및 로그 저장 성공",
        "query": query,
        "count": len(results),
        "results": results
    }