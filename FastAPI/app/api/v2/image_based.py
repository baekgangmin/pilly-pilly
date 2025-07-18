# app/api/v2/image_based.py
# 사용자 이미지 입력 받기, YOLO 추론, top_5 후보 리스트 반환
import time
from fastapi import APIRouter, UploadFile, File, HTTPException, Request
from PIL import Image
import io
from typing import List

from app.inference.yolo_cls import predict_pill, preprocess_image
from app.services.permit_service import get_permit_summary

router = APIRouter()

@router.post("/image-search", summary="이미지 기반 알약 예측 및 요약 조회")
async def image_search_summary(request: Request, file: UploadFile = File(...)):
    start_time = time.time()
    try:
        image_bytes = await file.read()
        try:
            image = Image.open(io.BytesIO(image_bytes)).convert("RGB")
        except Exception as e:
            raise HTTPException(status_code=400, detail=f"이미지 열기 실패: {str(e)}")
        
        #전처리
        #processed_image = preprocess_image(image)

        item_seq_list, predictions, top1_item_seq = predict_pill(image)

        if not item_seq_list:
            return {"message": "❌ 알약 식별 실패", "top_k": [], "summary": []}

        # 각 item_seq에 대한 요약 정보 조회
        summary_list = [get_permit_summary(seq) for seq in item_seq_list]
        print(summary_list)

        end_time = time.time()
        elapsed = round(end_time - start_time, 4)
        print(f"📌 [API /image_serch] 처리 시간: {elapsed}초")

        return {
            "message": "✅ 후보 알약 요약 조회 완료",
            "top_k": predictions,
            "summary": summary_list
        }

    except Exception as e:
        raise HTTPException(status_code=500, detail=f"❌ 서버 오류: {str(e)}")

