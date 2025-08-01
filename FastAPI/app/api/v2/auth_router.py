from fastapi import APIRouter, Request
from app.services.token_service import create_jwt_token

router = APIRouter()

@router.api_route("/auth/token", summary="익명 사용자 토큰 발급", methods=["POST", "OPTIONS"])
async def issue_token(request: Request):
    user_ip = request.client.host
    token = create_jwt_token({"sub": user_ip})  # ✅ dict 형태
    return {"token": token, "user_id": user_ip}