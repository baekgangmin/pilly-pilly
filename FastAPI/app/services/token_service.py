#\FastAPI\app\services\token_service.py
# JWT 발급/검증

from datetime import datetime, timedelta
from jose import jwt, JWTError

from app.core.config import settings


def create_jwt_token(payload: dict) -> str:
    to_encode = payload.copy()
    expire = datetime.now() + timedelta(minutes=settings.jwt_exp_minutes)
    to_encode.update({
        "exp": expire,                 #토큰 만료 시간
        "iss": settings.jwt_issuer,    #서버 식별자
        "iat": datetime.now()          #토큰 발급 시점
    })
    encoded = jwt.encode(to_encode, settings.jwt_secret_key, algorithm=settings.jwt_algorithm)
    return encoded


def verify_jwt_token(token: str) -> dict:
    try:
        decoded = jwt.decode(
            token,
            settings.jwt_secret_key,
            algorithms=[settings.jwt_algorithm],
            issuer=settings.jwt_issuer
        )
        return decoded
    except JWTError as e:
        raise ValueError(f"인증에 실패했습니다: {e}")
