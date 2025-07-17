#app\utils\request_utils.py
# 네트워크/요청 관련 유틸

from fastapi import Request

def get_user_ip(request: Request) -> str:
    return request.client.host if request.client else "unknown"


''' 캐시+uuid
import uuid
from fastapi import Response, Request

def get_or_create_anon_id(request: Request, response: Response) -> str:
    anon_id = request.cookies.get("anonymous_id")
    if not anon_id:
        anon_id = str(uuid.uuid4())
        response.set_cookie(
            key="anonymous_id", 
            value=anon_id, 
            max_age=60*60*24*365,  # max_age(쿠키유효기간:1년간 유지)
            httponly=True,
            samesite="Lax"
            )  
    return anon_id
    '''