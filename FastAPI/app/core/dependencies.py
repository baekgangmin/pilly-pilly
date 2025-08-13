# DB 또는 인증 등의 공통 의존성 관리

# 📁 app/core/dependencies.py
from typing import Optional
from fastapi import Request, Header, HTTPException, status, Depends
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials

from app.db.mongodb import db, auth_collection
from app.services.token_service import verify_jwt_token
from app.core.config import settings

# -----------------------------
# DB 주입
# -----------------------------
def get_db():
    return db

# -----------------------------
# 공통: 차단 여부 검사 유틸
# -----------------------------
async def _ensure_not_blocked(user_id: str) -> None:
    """
    user_id 기준으로 auth_logs(auth_collection) 조회하여 차단 여부 검사.
    차단이면 403.
    """
    if not user_id:
        raise HTTPException(status_code=401, detail="유효하지 않은 사용자 식별자")
    doc = await auth_collection.find_one({"user_id": user_id}, {"is_blocked": 1})
    if doc and doc.get("is_blocked", False) is True:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="해당 계정은 접근이 차단되었습니다."
        )

# -----------------------------
# JWT 기반 인증 + 차단 검사
# -----------------------------
security = HTTPBearer()

async def get_current_user(credentials: HTTPAuthorizationCredentials = Depends(security)) -> str:
    """
    Authorization: Bearer <JWT>
    - JWT 검증 (sub=user_id)
    - 차단 검사(_ensure_not_blocked)
    - 정상 시 user_id 반환
    """
    token = credentials.credentials
    try:
        payload = verify_jwt_token(token)
        user_id: Optional[str] = payload.get("sub")
        await _ensure_not_blocked(user_id)
        return user_id
    except ValueError:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid or expired token")

# -----------------------------
# 관리자 인증 (X-ADMIN-KEY)
# -----------------------------
async def require_admin(request: Request) -> str:
    """
    관리자 전용 키로 인증.
    """
    admin_key = request.headers.get("X-ADMIN-KEY")
    if not admin_key or admin_key != settings.admin_key:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="관리자 인증 실패: 유효하지 않은 X-ADMIN-KEY"
        )
    return "admin"