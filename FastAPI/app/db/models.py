# 저장할 로그 데이터 모델

from pydantic import BaseModel, Field
from typing import Optional
from datetime import datetime

class SearchLog(BaseModel):
    user_id: str
    query_type: str                  # 예: "feature" 또는 "image"
    query_params: dict               # 검색 시 사용된 파라미터들
    response: Optional[dict] = None  # API 응답 결과 (요약본)
    timestamp: datetime = Field(default_factory=datetime.utcnow)