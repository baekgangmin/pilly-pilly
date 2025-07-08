#app/api/v1/test_log.py
from fastapi import APIRouter, Request
from app.db.models import SearchLog
from app.utils.logger import save_search_log

router = APIRouter()

@router.get("/log/test", summary="Mongo 로그 저장 테스트")
async def test_log_save(request: Request):
    query = {"color": "white", "shape": "round"}
    results = [{"item_seq": "item_seq1"}, {"item_seq": "item_seq2"}]
    
    await save_search_log(request, query, results)
    return {"message": "✅ 로그 저장 성공", "ip": request.client.host}
