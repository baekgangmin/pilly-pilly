# 📄 app/api/v2/admin_page.py

from fastapi import APIRouter, HTTPException, Query, Response, Depends
from bson import ObjectId
from datetime import datetime
from app.db.mongodb import model_collection, db
from app.core.dependencies import require_admin
from motor.motor_asyncio import AsyncIOMotorGridFSBucket

router = APIRouter()
fs_bucket = AsyncIOMotorGridFSBucket(db)


@router.get("/admin/logs", summary="예측 로그 목록 조회", dependencies=[Depends(require_admin)])
async def get_logs(
    page: int = Query(1, gt=0),
    limit: int = Query(50, le=100),
    user_id: str = Query(None),
    start: str = Query(None, description="시작일자 (YYYY-MM-DD)"),
    end: str = Query(None, description="종료일자 (YYYY-MM-DD)")
):
    skip = (page - 1) * limit
    query = {}

    # ✅ 날짜 필터링 조건 추가
    if start or end:
        try:
            date_filter = {}
            if start:
                date_filter["$gte"] = datetime.strptime(start, "%Y-%m-%d")
            if end:
                date_filter["$lte"] = datetime.strptime(end, "%Y-%m-%d")
            query["timestamp"] = date_filter
        except ValueError:
            raise HTTPException(status_code=400, detail="날짜 형식은 YYYY-MM-DD 이어야 합니다.")

    # ✅ user_id 필터 추가
    if user_id:
        query["user_id"] = user_id

    # ✅ 쿼리 수행
    cursor = model_collection.find(query).sort("timestamp", -1).skip(skip).limit(limit)
    logs = []
    async for doc in cursor:
        logs.append({
            "id": str(doc["_id"]),
            "user_id": doc.get("user_id"),
            "filename": doc.get("filename"),
            "timestamp": doc.get("timestamp"),
            "image_file_id": str(doc.get("image_file_id", "")),
            "ocr_keywords": doc.get("ocr_keywords", []),
            "top_k": doc.get("top_k", [])
        })

    total = await model_collection.count_documents(query)
    return {
        "total": total,
        "page": page,
        "logs": logs
    }


@router.get("/admin/stats/summary", summary="날짜별 통계 요약 조회", dependencies=[Depends(require_admin)])
async def get_daily_summary(
    user_id: str = Query(None),
    start: str = Query(None, description="시작일자 (YYYY-MM-DD)"),
    end: str = Query(None, description="종료일자 (YYYY-MM-DD)")
):
    try:
        match = {}
        if user_id:
            match["user_id"] = user_id
        if start or end:
            date_filter = {}
            if start:
                date_filter["$gte"] = datetime.strptime(start, "%Y-%m-%d")
            if end:
                date_filter["$lte"] = datetime.strptime(end, "%Y-%m-%d")
            match["timestamp"] = date_filter

        # 날짜별로 group하여 통계 요약
        pipeline = [
            {"$match": match},
            {"$group": {
                "_id": {
                    "date": {"$dateToString": {"format": "%Y-%m-%d", "date": "$timestamp"}},
                },
                "count": {"$sum": 1},
                "top_keywords": {"$push": "$ocr_keywords"},
                "top_drugs": {"$push": "$top_k"}
            }},
            {"$sort": {"_id.date": 1}}
        ]

        results = await model_collection.aggregate(pipeline).to_list(length=None)
        summary = []
        for day in results:
            summary.append({
                "date": day["_id"]["date"],
                "count": day["count"],
                "ocr_keywords": sum(day["top_keywords"], []),  # flatten
                "top_k_items": sum([tk for tk in day["top_drugs"]], [])  # flatten
            })

        return {"summary": summary}
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"에러 발생: {str(e)}")
    

@router.get("/admin/image/{image_file_id}", summary="GridFS 이미지 다운로드", dependencies=[Depends(require_admin)])
async def get_image_file(image_file_id: str):
    try:
        file = await fs_bucket.open_download_stream(ObjectId(image_file_id))
        content = await file.read()
        return Response(content, media_type="image/png")  # 필요시 image/jpeg로 변경
    except Exception:
        raise HTTPException(status_code=404, detail="이미지 파일을 찾을 수 없습니다.")