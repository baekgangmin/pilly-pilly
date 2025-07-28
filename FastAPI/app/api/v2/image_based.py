# app/api/v2/image_based.py
# 사용자 이미지 입력 받기, YOLO 추론, top_5 후보 리스트 반환
import time
import io
import os
from fastapi import APIRouter, UploadFile, File, HTTPException, Request, Depends
from PIL import Image
from app.core.dependencies import get_current_user  # 🔐 인증 미들웨어
from app.inference.yolo_cls import predict_pill, get_main_bbox, preprocess_image
from app.services.permit_service import get_permit_summary
from datetime import datetime

router = APIRouter()

UPLOAD_DIR = "app/inference/imput_img"
os.makedirs(UPLOAD_DIR, exist_ok=True)

@router.post("/image-search", summary="이미지 기반 알약 예측 및 요약 조회")
async def image_search_summary(
    request: Request, 
    file: UploadFile = File(...),
    user_id: str = Depends(get_current_user)
):
    start_time = time.time()
    try:
        image_bytes = await file.read()
        try:
            image = Image.open(io.BytesIO(image_bytes)).convert("RGB")
        except Exception as e:
            raise HTTPException(status_code=400, detail=f"이미지 열기 실패: {str(e)}")

        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        filename = f"{timestamp}_{file.filename}"
        save_path = os.path.join(UPLOAD_DIR, filename)
        with open(save_path, "wb") as f:
            f.write(image_bytes)
        print(f"✅ 업로드 이미지 저장: {save_path}")

        # ✅ 1. YOLO Detection으로 bbox 추출
        bbox = get_main_bbox(image)
        if bbox is None:
            return {"message": "❌ 알약 bbox를 찾을 수 없습니다.", "top_k": [], "summary": []}

        # ✅ 2. bbox 기준 이미지 전처리 (400px + 패딩)
        processed_image = preprocess_image(image, bbox)

        # ✅ 3. YOLO-CLS 분류 모델 예측
        item_seq_list, predictions, top1_item_seq = predict_pill(processed_image)

        if not item_seq_list:
            return {"message": "❌ 알약 식별 실패", "top_k": [], "summary": []}

        # ✅ 4. 각 item_seq에 대한 요약 정보 조회
        summary_list = [get_permit_summary(seq) for seq in item_seq_list]

        elapsed = round(time.time() - start_time, 4)
        print(f"📌 [API /image_search] 처리 시간: {elapsed}초")

        return {
            "message": "✅ 후보 알약 요약 조회 완료",
            "top_k": predictions,
            "summary": summary_list
        }

    except Exception as e:
        raise HTTPException(status_code=500, detail=f"❌ 서버 오류: {str(e)}")

