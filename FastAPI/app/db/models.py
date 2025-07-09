# 저장할 로그 데이터 모델
#FastAPI\app\db\models.py
from pydantic import BaseModel, Field
from typing import List, Dict, Optional, Any
from datetime import datetime
from pytz import timezone

#한국 서울시간 적용
def seoul_now():
    return datetime.now(timezone('Asia/Seoul'))


class SearchLog(BaseModel):
    user_id: str
    query: Dict[str, str]             # 예: {"source": "permit", "item_seq": "1234"}
    results: Dict[str, Any]          # 예: {"permit": {...}, "dur": {...}}
    timestamp: datetime = Field(default_factory=seoul_now)