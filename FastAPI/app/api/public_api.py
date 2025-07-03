#  app/api/public_api.py
from fastapi import APIRouter, Query
from app.services.drug_api import get_pill_by_name

router = APIRouter()

@router.get("/search")
def search_pill(item_seq: str = Query(...)):
    return get_pill_by_name(item_seq)