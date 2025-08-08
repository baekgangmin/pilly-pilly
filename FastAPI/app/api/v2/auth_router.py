#FastAPI\app\api\v2\auth_router.py
import uuid
from fastapi import APIRouter, Request, Response
from app.services.token_service import create_jwt_token
from app.services.log_service import log_or_update_anon_user

router = APIRouter()

#캐시+UUID -> 토큰 발급
def get_or_create_anon_id(request: Request, response: Response) -> str:
    anon_id = request.cookies.get("anonymous_id")
    if not anon_id:
        anon_id = str(uuid.uuid4())
        response.set_cookie(
            key="anonymous_id",
            value=anon_id,
            max_age=60 * 60 * 24 * 365,  # 1년
            httponly=True,
            samesite="Lax"
        )
    return anon_id

@router.api_route("/auth/token", summary="익명 사용자 토큰 발급", methods=["POST", "OPTIONS"])
async def issue_token(request: Request, response: Response):
    user_ip = request.client.host
    anon_id = get_or_create_anon_id(request, response)
    token = create_jwt_token({"sub": anon_id})  # ✅ dict 형태
    await log_or_update_anon_user(user_id=anon_id, request=request)
    return {"token": token, "user_id": anon_id}