 # 1-1, 1-2: YOLO → item_seq 기반

# 📁 app/api/v1/image_based.py
from fastapi import APIRouter, Query, Request
from app.services.permit_service import get_full_detail
from app.db.models import SearchLog
from app.db.mongodb import save_search_log

router = APIRouter()
@router.get("/pill/detail")
def pill_detail(item_seq: str):
    return get_full_detail(item_seq)


# 예시 함수 내에서 로그 저장
@router.post("/search")
async def search_item(request: Request):
    # 로그 데이터 생성
    log = SearchLog(
        user_ip=request.client.host,
        search_type="image_based",
        request_params={"front_text": "분할"},
        predicted_item_seq="202005974",
        api_results={"permit": {}, "overview": {}}
    )

    # ⬅ await는 async 함수 안이므로 사용 가능
    await save_search_log(log)

    return {"message": "saved"}
