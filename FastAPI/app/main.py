# app/main.py
from fastapi import FastAPI
from app.api.v2.log_router import router as log_router
from app.api.v2.identify_feature_router import router as identify_feature_router
#from app.api.v1.test_log import router as test_log_router
from app.api.v2 import log_router


app = FastAPI(
    title="Pill Feature API",
    version="0.1.0",
    description="의약품 식별 API"
)

# 실제 기능 라우터
#app.include_router(feature_router, prefix="/api/v1/pill", tags=["feature"])
#app.include_router(image_router, prefix="/api/v1/image", tags=["image"])
#app.include_router(permit_log_router, prefix="/api/v1", tags=["허가정보 로그"])
app.include_router(log_router.router, prefix="/api/v2/log", tags=["image 검색 통합 라우터"])
app.include_router(identify_feature_router, prefix="/api/v2", tags=["식별 검색 통합 라우터"])

#test-확인완료
#app.include_router(test_log_router, prefix="/api/v1/test", tags=["log"])
