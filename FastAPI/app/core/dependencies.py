# DB 또는 인증 등의 공통 의존성 관리

# 📁 app/core/dependencies.py
from fastapi import Depends, HTTPException, Request
from app.db.mongodb import db

def get_db():
    return db


# FastAPI depends 인증 미들웨어

from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from app.services.token_service import verify_jwt_token
from app.core.config import settings

security = HTTPBearer()

def get_current_user(credentials: HTTPAuthorizationCredentials = Depends(security)) -> str:
    token = credentials.credentials
    try:
        payload = verify_jwt_token(token)
        return payload.get("sub")
    except ValueError:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid or expired token")

# 관리자 인증 데코레이터 함수
async def require_admin(request: Request):
    admin_key = request.headers.get("X-ADMIN-KEY")
    if not admin_key or admin_key != settings.admin_key:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="관리자 인증 실패: 유효하지 않은 X-ADMIN-KEY"
        )