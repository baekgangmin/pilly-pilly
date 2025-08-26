# 📄 app/api/v2/admin_page.py
from typing import Optional, Literal, Dict, List
from fastapi import APIRouter, HTTPException, Query, Response, Depends, Request
from bson import ObjectId
from datetime import datetime, timedelta
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

@router.get("/admin/stats/blocked-users", summary="[시스템 통계] 현재 차단된 사용자 수", dependencies=[Depends(require_admin)])
async def stats_blocked_users():
    """
    auth_collection에서 is_blocked가 true인 사용자 수를 반환합니다.
    """
    try:
        # is_blocked가 true인 문서의 개수를 세기
        blocked_count = await auth_collection.count_documents({"is_blocked": True})
        return {"blocked_count": blocked_count}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"차단된 사용자 수 조회 실패: {str(e)}")
        
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

# ======================
# [어플 시스템 통계]
# ======================

@router.get("/admin/stats/today", summary="[시스템 통계] TODAY(사용량) 집계", dependencies=[Depends(require_admin)])
async def stats_today(
    tz_offset_minutes: int = Query(0, description="클라이언트 타임존 오프셋(분). 예: KST(한국)는 540"),
):
    """
    오늘 기준 사용자 사용량 통계:
      - total_users_today: 오늘 접속( last_access )한 고유 user 수
      - new_users_today: 오늘 최초 생성( created_at )된 user 수
      - returning_users_today: 총방문자 - 신규 (재방문 사용자 수)
    """
    # 간단하게: 로컬 기준 오늘 날짜만 구하기
    from datetime import timezone
    now_utc = datetime.now(timezone.utc)
    local_now = now_utc + timedelta(minutes=tz_offset_minutes)
    
    # 로컬 기준 오늘 날짜 (YYYY-MM-DD)
    today_local = local_now.strftime("%Y-%m-%d")
    
    # UTC로 변환: 오늘 00:00:00 ~ 내일 00:00:00
    start_utc = datetime.strptime(today_local, "%Y-%m-%d") - timedelta(minutes=tz_offset_minutes)
    end_utc = start_utc + timedelta(days=1)
    
    print(f"DEBUG: today_local={today_local}, start_utc={start_utc}, end_utc={end_utc}")

    # 1. 오늘 접속자 (last_access가 오늘인 사용자)
    total_users_today = await auth_collection.count_documents({
        "last_access": {"$gte": start_utc, "$lt": end_utc}
    })

    # 2. 오늘 신규 (created_at이 오늘인 사용자)
    new_users_today = await auth_collection.count_documents({
        "created_at": {"$gte": start_utc, "$lt": end_utc}
    })

    # 3. 재방문 = 총방문자 - 신규
    returning_users_today = total_users_today - new_users_today
    
    return {
        "range_local": {
            "start": today_local,
            "end": today_local,
            "tz_offset_minutes": tz_offset_minutes,
        },
        "total_users_today": total_users_today,
        "new_users_today": new_users_today,
        "returning_users_today": returning_users_today,
    }

def _parse_local_start_utc(date_str: str, offset_min: int) -> datetime:
    d = datetime.strptime(date_str, "%Y-%m-%d")
    # 로컬 00:00 -> UTC
    return d - timedelta(minutes=offset_min)

def _parse_local_end_exclusive_utc(date_str: str, offset_min: int) -> datetime:
    d = datetime.strptime(date_str, "%Y-%m-%d")
    # 로컬 다음날 00:00 -> UTC (끝 지점은 미포함)
    return d + timedelta(days=1) - timedelta(minutes=offset_min)

@router.get(
    "/admin/stats/usage-series", summary="[시스템 통계] 사용자 사용량 시계열(일/주/월)", dependencies=[Depends(require_admin)]
)
async def stats_usage_series(
    granularity: Literal["day", "week", "month"] = Query("day"),
    start: str = Query(..., description="YYYY-MM-DD (로컬 기준, 필수)"),
    end: str = Query(..., description="YYYY-MM-DD (포함, 로컬 기준, 필수)"),
    tz_offset_minutes: int = Query(0, description="클라이언트 타임존 오프셋(분)"),
):
    """
    그래프용 시계열(일/주/월) 집계.
      - total_users: 버킷 내 접속(last_access)한 '고유 user 수'
      - new_users: 버킷 내 'created_at'이 처음 기록된 사용자 수
      - returning_users: 버킷 내 접속하면서 created_at이 버킷 시작보다 이전인 '재방문' 사용자 수
      - anonymous_users: 버킷 내 접속 + is_anonymous=True 사용자 수
    """
    # UTC 범위 산출
    start_utc = _parse_local_start_utc(start, tz_offset_minutes)
    end_utc_excl = _parse_local_end_exclusive_utc(end, tz_offset_minutes)

    # Mongo 파이프라인: 로컬 오프셋을 더해 'local_*' 필드로 만든 뒤 dateTrunc
    unit = granularity  # "day" | "week" | "month"
    pipeline = [
        {"$match": {"last_access": {"$gte": start_utc, "$lt": end_utc_excl}}},
        {"$addFields": {
            "local_last": {"$dateAdd": {"startDate": "$last_access", "unit": "minute", "amount": tz_offset_minutes}},
            "local_created": {"$dateAdd": {"startDate": "$created_at", "unit": "minute", "amount": tz_offset_minutes}},
        }},
        # 버킷 시작(로컬 기준-월요일)을 구함
        {"$addFields": {
        "bucket": {"$dateTrunc": {"date": "$local_last", "unit": unit, "startOfWeek": "monday"}},
        "is_returning": {"$lt": [
            "$local_created",
            {"$dateTrunc": {"date": "$local_last", "unit": unit, "startOfWeek": "monday"}}
        ]},
        }},
        # 1단계: (bucket, user_id)별로 통합해 고유 사용자 수를 세기 위한 기반 마련
        {"$group": {
            "_id": {"bucket": "$bucket", "user_id": "$user_id"},
            "any_is_anonymous": {"$max": "$is_anonymous"},
            "any_is_returning": {"$max": "$is_returning"},
            "created_at_one": {"$first": "$local_created"},
            "bucket_start": {"$first": "$bucket"},  # 버킷 시작 시간 추가
        }},
        # 2단계: 버킷별 집계(고유 사용자 기준)
        {"$group": {
            "_id": "$_id.bucket",
            "total_users": {"$sum": 1},
            "anonymous_users": {"$sum": {"$cond": ["$any_is_anonymous", 1, 0]}},
            "returning_users": {"$sum": {"$cond": ["$any_is_returning", 1, 0]}},
            # new_users: created_at이 '해당 버킷'에 속하면 신규로 카운트
            # $dateTrunc를 사용해서 정확한 버킷 비교
            "new_users": {"$sum": {"$cond": [
                {"$eq": [
                    {"$dateTrunc": {"date": "$created_at_one", "unit": unit, "startOfWeek": "monday"}},
                    "$bucket_start"
                ]},
                1, 0
            ]}},
        }},
        {"$project": {
            "_id": 0,
            "bucket": "$_id",
            "total_users": 1,
            "new_users": 1,
            "returning_users": 1,
            "anonymous_users": 1,
        }},
        {"$sort": {"bucket": 1}},
    ]

    rows = await auth_collection.aggregate(pipeline, allowDiskUse=True).to_list(length=None)
    
    # 디버깅용 로그 (실제 운영에서는 제거)
    print(f"DEBUG: unit={unit}, tz_offset_minutes={tz_offset_minutes}")
    print(f"DEBUG: start_utc={start_utc}, end_utc_excl={end_utc_excl}")
    print(f"DEBUG: first few rows={rows[:3] if rows else 'empty'}")

    # 빈 버킷 채우기(옵션) — 그래프가 끊기지 않게
    def step_add(d: datetime) -> datetime:
        if unit == "day": return d + timedelta(days=1)
        if unit == "week": return d + timedelta(weeks=1)
        # month: 간단 구현(매월 1일 기준). 세밀한 말일 처리 필요 시 calendar lib 사용.
        month = d.month + 1
        year = d.year + (1 if month > 12 else 0)
        month = month if month <= 12 else 1
        return datetime(year, month, 1)

    # 로컬 기준 버킷 라인업 만들고 rows에 없는 건 0으로 채움
    # (버킷은 로컬 시작 기준이므로, start 로컬의 버킷 시작부터 end 로컬의 다음 버킷 시작 직전까지)
    # 먼저 로컬 버킷 시작을 구함
    start_local = (start_utc + timedelta(minutes=tz_offset_minutes))
    end_local_excl = (end_utc_excl + timedelta(minutes=tz_offset_minutes))
    def trunc_local(d: datetime) -> datetime:
        if unit == "day":   return datetime(d.year, d.month, d.day)
        if unit == "week":
            # ISO week 시작(월요일) 기준. 필요 시 일요일 시작으로 변경 가능.
            wd = (d.weekday())  # 0=Mon
            floored = datetime(d.year, d.month, d.day) - timedelta(days=wd)
            return floored
        # month
        return datetime(d.year, d.month, 1)

    cursor = trunc_local(start_local)
    buckets_local: List[datetime] = []
    while cursor < end_local_excl:
        buckets_local.append(cursor)
        cursor = step_add(cursor)

    # rows의 bucket은 '로컬시간 버킷(datetime)'(tz-naive) 그대로
    by_bucket: Dict[str, dict] = { r["bucket"].isoformat(): r for r in rows }

    series = []
    for b_local in buckets_local:
        key = b_local.isoformat()
        r = by_bucket.get(key)
        if not r:
            series.append({
                "bucket": key,
                "total_users": 0,
                "new_users": 0,
                "returning_users": 0,
                "anonymous_users": 0,
            })
        else:
            series.append({
                "bucket": key,
                "total_users": r["total_users"],
                "new_users": r["new_users"],
                "returning_users": r["returning_users"],
                "anonymous_users": r["anonymous_users"],
            })

    return {
        "granularity": granularity,
        "range_local": {"start": start, "end": end, "tz_offset_minutes": tz_offset_minutes},
        "series": series,
    }


@router.get("/admin/stats/top-pills", summary="[시스템 통계] 알약 검색 TOP 랭크(multi)", dependencies=[Depends(require_admin)])
async def stats_top_pills(
    start: str = Query(None, description="YYYY-MM-DD (로컬 기준)"),
    end: str = Query(None, description="YYYY-MM-DD (포함, 로컬 기준)"),
    tz_offset_minutes: int = Query(0, description="클라이언트 타임존 오프셋(분)"),
    limit: int = Query(20, gt=0, le=100),
):
    """
    search_logs에서 query.source == 'multi' 인 로그만 집계.
    - itemName별 등장 횟수 TOP N
    - 확장성: permitList의 필드를 함께 투영(상세 팝업/추후 /log 조회에 활용)
    """
    match: dict = {"query.source": "multi"}

    # 날짜 범위 → UTC로 변환
    def parse_utc(date_str: str) -> datetime:
        # 사용자가 넣은 로컬 날짜의 00:00을 UTC로
        d = datetime.strptime(date_str, "%Y-%m-%d")
        return d - timedelta(minutes=tz_offset_minutes)

    if start:
        start_utc = parse_utc(start)
        match["timestamp"] = {"$gte": start_utc}
    if end:
        # end-day 의 23:59:59.999 로컬 포함되도록 다음날 00:00 직전까지
        end_utc = (parse_utc(end) + timedelta(days=1))
        match["timestamp"] = {**match.get("timestamp", {}), "$lt": end_utc}

    pipeline = [
        {"$match": match},
        # 결과 구조에서 permitList를 투영(한 건 선택 로그 구조 가정)
        {"$project": {
            "permitList": "$results.permit.permitList",
        }},
        {"$match": {"permitList.itemName": {"$exists": True}}},
        {"$group": {
            "_id": {
                "itemName": "$permitList.itemName",
                "prductType": "$permitList.prductType",
                "entpName": "$permitList.entpName",
                "specltyPblc": "$permitList.specltyPblc",
            },
            "count": {"$sum": 1},
            "examples": {"$push": "$permitList"},  # 확장성: 상세 필드 보존
        }},
        {"$sort": {"count": -1}},
        {"$limit": limit},
    ]

    rows = await searchlog_collection.aggregate(pipeline).to_list(length=None)
    data = [{
        "itemName": r["_id"]["itemName"],
        "count": r["count"],
        "prductType": r["_id"].get("prductType"),
        "entpName": r["_id"].get("entpName"),
        "specltyPblc": r["_id"].get("specltyPblc"),
        "samples": r.get("examples", [])[:1],   # 응답 경량화 (예시 최대 3개)
    } for r in rows]

    return {"rows": data, "total": len(data)}


@router.get("/admin/stats/top-by-type", summary="[시스템 통계] 질병(제품군)별 가장 많이 검색된 알약", dependencies=[Depends(require_admin)])
async def stats_top_by_type(
    start: str = Query(None, description="YYYY-MM-DD (로컬 기준)"),
    end: str = Query(None, description="YYYY-MM-DD (포함, 로컬 기준)"),
    tz_offset_minutes: int = Query(0, description="클라이언트 타임존 오프셋(분)"),
    top_k_each: int = Query(10, gt=1, le=50, description="각 prductType별 상위 몇 개"),
):
    """
    result.permit.permitList.prductType 별로 itemName 카운트 TOP K.
    (질병군/제품군 코드별 랭킹)
    """
    match: dict = {"query.source": "multi"}

    def parse_utc(date_str: str) -> datetime:
        d = datetime.strptime(date_str, "%Y-%m-%d")
        return d - timedelta(minutes=tz_offset_minutes)

    if start:
        start_utc = parse_utc(start)
        match["timestamp"] = {"$gte": start_utc}
    if end:
        end_utc = (parse_utc(end) + timedelta(days=1))
        match["timestamp"] = {**match.get("timestamp", {}), "$lt": end_utc}

    pipeline = [
        {"$match": match},
        {"$project": {
            "permitList": "$results.permit.permitList",
        }},
        {"$match": {"permitList.itemName": {"$exists": True}, "permitList.prductType": {"$exists": True}}},
        # (prductType, itemName)로 집계
        {"$group": {
            "_id": {
                "prductType": "$permitList.prductType",
                "itemName": "$permitList.itemName",
            },
            "count": {"$sum": 1}
        }},
        {"$sort": {"_id.prductType": 1, "count": -1}},
        # prductType별로 상위 K 추리기
        {"$group": {
            "_id": "$_id.prductType",
            "items": {"$push": {"itemName": "$_id.itemName", "count": "$count"}}
        }},
        {"$project": {
            "prductType": "$_id",
            "top": {"$slice": ["$items", top_k_each]}
        }},
        {"$sort": {"prductType": 1}},
    ]

    rows = await searchlog_collection.aggregate(pipeline).to_list(length=None)
    return {"groups": rows}


@router.get("/admin/stats/identify-queries", summary="[시스템 통계] 식별(identify) 검색 쿼리 모아보기", dependencies=[Depends(require_admin)])
async def stats_identify_queries(
    start: str = Query(None, description="YYYY-MM-DD (로컬 기준)"),
    end: str = Query(None, description="YYYY-MM-DD (포함, 로컬 기준)"),
    user_id: str = Query(None, description="특정 사용자만 필터링"),
    tz_offset_minutes: int = Query(0),
    limit: int = Query(50, gt=1, le=200),
):
    """
    식별 검색(identify)의 원본 쿼리 목록(최신순).
    향후 상세 팝업/추가 통계에 활용.
    """
    match: dict = {"query.source": {"$in": ["identify"]}}
    if user_id:
        match["user_id"] = user_id

    def parse_utc(date_str: str) -> datetime:
        d = datetime.strptime(date_str, "%Y-%m-%d")
        return d - timedelta(minutes=tz_offset_minutes)

    if start:
        start_utc = parse_utc(start)
        match["timestamp"] = {"$gte": start_utc}
    if end:
        end_utc = (parse_utc(end) + timedelta(days=1))
        match["timestamp"] = {**match.get("timestamp", {}), "$lt": end_utc}

    cursor = (
        searchlog_collection
        .find(match, {"user_id": 1, "query": 1, "timestamp": 1})
        .sort("timestamp", -1)
        .limit(limit)
    )
    rows = []
    async for d in cursor:
        rows.append({
            "user_id": d.get("user_id"),
            "query": d.get("query"),
            "timestamp": d.get("timestamp"),
        })
    return {"total": len(rows), "logs": rows}


@router.get("/admin/stats/keyword-queries", summary="[시스템 통계] 키워드 검색 쿼리 통계", dependencies=[Depends(require_admin)])
async def stats_keyword_queries(
    start: str = Query(None, description="YYYY-MM-DD (로컬 기준)"),
    end: str = Query(None, description="YYYY-MM-DD (포함, 로컬 기준)"),
    user_id: str = Query(None, description="특정 사용자만 필터링"),
    tz_offset_minutes: int = Query(0),
    limit: int = Query(50, gt=1, le=200),
):
    """
    키워드 검색(keyword)의 통계:
    - 일자별 로그 개수
    - 키워드별 result.items 배열 개수 통계
    - 키워드별 검색 빈도
    """
    match: dict = {"query.source": {"$in": ["keyword"]}}
    if user_id:
        match["user_id"] = user_id

    def parse_utc(date_str: str) -> datetime:
        d = datetime.strptime(date_str, "%Y-%m-%d")
        return d - timedelta(minutes=tz_offset_minutes)

    if start:
        start_utc = parse_utc(start)
        match["timestamp"] = {"$gte": start_utc}
    if end:
        end_utc = (parse_utc(end) + timedelta(days=1))
        match["timestamp"] = {**match.get("timestamp", {}), "$lt": end_utc}

    # 1. 일자별 로그 개수 집계
    daily_pipeline = [
        {"$match": match},
        {"$addFields": {
            "local_date": {"$dateToString": {"format": "%Y-%m-%d", "date": "$timestamp"}}
        }},
        {"$group": {
            "_id": "$local_date",
            "count": {"$sum": 1}
        }},
        {"$sort": {"_id": 1}}
    ]
    
    daily_stats = await searchlog_collection.aggregate(daily_pipeline).to_list(length=None)
    
    # 2. 키워드별 통계 (키워드, 검색 횟수, result.items 배열 개수 통계)
    keyword_pipeline = [
        {"$match": match},
        {"$addFields": {
            "keyword": "$query.keyword",
            "items_count": {"$size": {"$ifNull": ["$results.items", []]}}
        }},
        {"$group": {
            "_id": "$keyword",
            "search_count": {"$sum": 1},
            "total_items": {"$sum": "$items_count"},
            "sample_queries": {"$push": {
                "user_id": "$user_id",
                "timestamp": "$timestamp",
                "items_count": "$items_count"
            }}
        }},
        {"$sort": {"search_count": -1}},
        {"$limit": limit}
    ]
    
    keyword_stats = await searchlog_collection.aggregate(keyword_pipeline).to_list(length=None)
    
    # 3. 키워드별 상세 로그 (최신순)
    keyword_logs_pipeline = [
        {"$match": match},
        {"$addFields": {
            "keyword": "$query.keyword",
            "items_count": {"$size": {"$ifNull": ["$results.items", []]}}
        }},
        {"$sort": {"timestamp": -1}},
        {"$limit": limit},
        {"$project": {
            "user_id": 1,
            "keyword": 1,
            "timestamp": 1,
            "items_count": 1,
            "query": 1
        }}
    ]
    
    keyword_logs = await searchlog_collection.aggregate(keyword_logs_pipeline).to_list(length=None)
    
    return {
        "daily_stats": [
            {
                "date": day["_id"],
                "count": day["count"]
            } for day in daily_stats
        ],
        "keyword_stats": [
            {
                "keyword": stat["_id"],
                "search_count": stat["search_count"],
                "total_items": stat["total_items"],
                "sample_queries": stat["sample_queries"][:1]
            } for stat in keyword_stats
        ],
        "recent_logs": [
            {
                "user_id": log.get("user_id"),
                "keyword": log.get("keyword"),
                "timestamp": log.get("timestamp"),
                "items_count": log.get("items_count"),
                "query": log.get("query")
            } for log in keyword_logs
        ],
        "summary": {
            "total_keywords": len(keyword_stats),
            "total_searches": sum(stat["search_count"] for stat in keyword_stats),
            "avg_items_per_search": round(
                sum(stat["total_items"] for stat in keyword_stats) / 
                sum(stat["search_count"] for stat in keyword_stats), 2
            ) if keyword_stats else 0
        }
    }


