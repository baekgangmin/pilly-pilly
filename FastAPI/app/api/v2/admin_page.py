# 📄 app/api/v2/admin_page.py
from typing import Optional
from fastapi import APIRouter, HTTPException, Query, Response, Depends, Request
from bson import ObjectId
from datetime import datetime
from motor.motor_asyncio import AsyncIOMotorGridFSBucket

from app.db.mongodb import (
    db,
    model_collection,          # model_logs
    auth_collection,           # auth_logs (사용자 레지스트리)
    chatbot_collection,        # chat_logs
    favorite_collection,       # user_favorite_logs
    searchlog_collection,      # search_logs  (settings.mongodb_collection_name)
    audit_collection,          # audit_logs
)

from app.core.dependencies import require_admin
from app.db.crud.admin_action import log_admin_action

router = APIRouter()
fs_bucket = AsyncIOMotorGridFSBucket(db)

# ======================
# [모델 성능 통계]
# ======================
@router.get("/admin/logs", summary="[모델 성능 통계] 로그 목록 조회", dependencies=[Depends(require_admin)])
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
            "top_k": doc.get("top_k", []),
            "summary": doc.get("summary", [])
        })

    total = await model_collection.count_documents(query)
    return {
        "total": total,
        "page": page,
        "logs": logs
    }


@router.get("/admin/summary", summary="[모델 성능 통계] 날짜별 통계 요약 조회", dependencies=[Depends(require_admin)])
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
                "_id": {"date": {"$dateToString": {"format": "%Y-%m-%d", "date": "$timestamp"}}},
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
    

@router.get("/admin/image/{image_file_id}", summary="[모델 성능 통계] GridFS 이미지 다운로드", dependencies=[Depends(require_admin)])
async def get_image_file(image_file_id: str):
    try:
        file = await fs_bucket.open_download_stream(ObjectId(image_file_id))
        content = await file.read()
        return Response(content, media_type="image/png")  # 필요시 image/jpeg로 변경
    except Exception:
        raise HTTPException(status_code=404, detail="이미지 파일을 찾을 수 없습니다.")
    

# ======================
# [관리자/감사]
# ======================

@router.delete("/admin/user/{user_id}", summary="[관리자/감사] 사용자 차단")
async def block_user(
    user_id: str,
    request: Request,
    admin_id: str = Depends(require_admin),
):
    res = await auth_collection.update_one({"user_id": user_id}, {"$set": {"is_blocked": True}})
    if res.matched_count == 0:
        raise HTTPException(status_code=404, detail="해당 user_id가 없습니다.")
    await log_admin_action(request, admin_id, action="block_user", target_user_id=user_id)
    return {"message": f"{user_id} 사용자 차단 완료"}

@router.put("/admin/user/{user_id}/unblock", summary="[관리자/감사] 사용자 차단 해제")
async def unblock_user(
    user_id: str,
    request: Request,
    admin_id: str = Depends(require_admin),
):
    res = await auth_collection.update_one({"user_id": user_id}, {"$set": {"is_blocked": False}})
    if res.matched_count == 0:
        raise HTTPException(status_code=404, detail="해당 user_id가 없습니다.")
    
    await log_admin_action(request, admin_id, action="unblock_user", target_user_id=user_id)
    return {"message": f"{user_id} 사용자 차단 해제 완료"}


@router.delete("/admin/data/{target}", summary="[관리자/감사] DB 데이터 삭제(스코프 제한)")
async def delete_data(
    target: str,
    request: Request,
    admin_id: str = Depends(require_admin),
    # 안전장치: 기본 dry_run=True, 실제 삭제는 hard=true가 필요
    dry_run: bool = Query(True, description="true면 삭제 예정 건수만 반환(기본값)"),
    hard: bool = Query(False, description="true로 해야 실제 삭제 실행"),
    # 스코프 지정
    start: Optional[str] = Query(None, description="YYYY-MM-DD"),
    end: Optional[str] = Query(None, description="YYYY-MM-DD"),
    user_id: Optional[str] = Query(None),
    older_than_days: Optional[int] = Query(None, ge=1, description="N일 이전 데이터 삭제"),
):
    targets = {
        "model_logs": model_collection,
        "search_logs": searchlog_collection,
        "chat_logs": chatbot_collection,
        "user_favorite_logs": favorite_collection,
    }
    if target not in targets:
        raise HTTPException(status_code=400, detail=f"지원 대상: {list(targets.keys())}")

    # 전량 삭제 방지: 반드시 하나 이상의 스코프 필요
    if not any([start, end, user_id, older_than_days]):
        raise HTTPException(
            status_code=400,
            detail="삭제 범위를 지정하세요(start/end, user_id, older_than_days 중 1개 이상)"
        )

    # user_favorite_logs는 전량/범위 없는 삭제 금지: user_id 필수
    if target == "user_favorite_logs" and not user_id:
        raise HTTPException(
            status_code=400,
            detail="user_favorite_logs 삭제는 user_id 파라미터가 필수입니다."
        )

    # 필터 구성
    q = {}
    if user_id:
        q["user_id"] = user_id

    if older_than_days:
        from datetime import datetime, timedelta
        cutoff = datetime.now() - timedelta(days=older_than_days)
        q["timestamp"] = {"$lte": cutoff}

    if start or end:
        from datetime import datetime
        date_filter = {}
        if start:
            date_filter["$gte"] = datetime.strptime(start, "%Y-%m-%d")
        if end:
            date_filter["$lte"] = datetime.strptime(end, "%Y-%m-%d")
        q["timestamp"] = {**q.get("timestamp", {}), **date_filter}

    col = targets[target]

    # dry_run: 삭제 예정 건수와 샘플 id 반환
    count = await col.count_documents(q)
    if dry_run and not hard:
        # 샘플 5건 미리보기
        cursor = col.find(q, {"_id": 1}).limit(5)
        sample_ids = [str(d["_id"]) async for d in cursor]
        return {
            "target": target,
            "dry_run": True,
            "filter": q,
            "delete_candidate_count": count,
            "sample_ids": sample_ids
        }

    # 실제 삭제
    # model_logs에 GridFS 이미지가 연결되어 있다면 함께 정리(권장)
    deleted_files = 0
    if target == "model_logs":
        from motor.motor_asyncio import AsyncIOMotorGridFSBucket
        fs_bucket = AsyncIOMotorGridFSBucket(db)
        # 삭제 대상 문서의 image_file_id 수집 후 GridFS 삭제
        img_ids = []
        async for d in col.find(q, {"image_file_id": 1}):
            if d.get("image_file_id"):
                img_ids.append(d["image_file_id"])
        # GridFS 삭제(존재하는 것만)
        for fid in img_ids:
            try:
                await fs_bucket.delete(ObjectId(fid))
                deleted_files += 1
            except Exception:
                pass  # 없거나 손상된 경우 스킵

    res = await col.delete_many(q)

    await log_admin_action(
        request, admin_id, action="delete_data",
        details={
            "target": target,
            "filter": q,
            "deleted_count": res.deleted_count,
            **({"deleted_gridfs_files": deleted_files} if target == "model_logs" else {})
        }
    )
    return {
        "target": target,
        "hard": True,
        "filter": q,
        "deleted_count": res.deleted_count,
        **({"deleted_gridfs_files": deleted_files} if target == "model_logs" else {})
    }


@router.get("/admin/audit-logs", summary="[관리자/감사] 목록 조회")
async def get_audit_logs(
    page: int = Query(1, gt=0),
    limit: int = Query(50, le=100),
    admin_id: Optional[str] = Query(None),
    action: Optional[str] = Query(None),
    _: str = Depends(require_admin),   # 인증만 강제
):
    skip = (page - 1) * limit
    query = {}
    if admin_id:
        query["admin_id"] = admin_id
    if action:
        query["action"] = action

    cursor = audit_collection.find(query).sort("timestamp", -1).skip(skip).limit(limit)
    results = []
    async for doc in cursor:
        results.append({
            "id": str(doc["_id"]),
            "admin_id": doc.get("admin_id"),
            "action": doc.get("action"),
            "target_user_id": doc.get("target_user_id"),
            "details": doc.get("details", {}),
            "timestamp": doc.get("timestamp"),
            "ip": doc.get("ip"),
            "endpoint": doc.get("endpoint"),
        })

    total = await audit_collection.count_documents(query)
    return {"total": total, "page": page, "logs": results}
