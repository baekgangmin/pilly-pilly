# YOLO8v_cls  모델 로드 및 예측 알고리즘
# app/inference/image_model.py
import torch
import time
import logging
import numpy as np
import os
from ultralytics import YOLO
from PIL import Image
from app.utils.model_utils import get_dominant_color, calculate_color_similarity
from app.utils.ocr_utils import detect_text_pill
from app.utils.logger import logger_model


detect_model_path = "app/models/best_detec.pt"
cls_model_path = "app/models/best_cls.pt"
det_model = YOLO(detect_model_path)
cls_model = YOLO(cls_model_path)

# 전처리: 크롭, 리사이즈
def get_main_bbox(image: Image.Image):
    results = det_model.predict(image, verbose=False)[0]
    if results.boxes is None or len(results.boxes.xyxy) == 0:
        return None
    confidences = results.boxes.conf
    bboxes = results.boxes.xyxy
    max_idx = torch.argmax(confidences).item()
    return bboxes[max_idx].cpu().tolist()

def preprocess_image(image: Image.Image, bbox: list, save_debug: bool = True) -> Image.Image:
    x1, y1, x2, y2 = map(int, bbox)
    cropped = image.crop((x1, y1, x2, y2))
    width, height = cropped.size
    new_w, new_h = (400, int(400 * height / width)) if width >= height else (int(400 * width / height), 400)
    resized = cropped.resize((new_w, new_h), Image.BICUBIC)
    final_image = Image.new("RGB", (640, 640), (0, 0, 0))
    final_image.paste(resized, ((640 - new_w) // 2, (640 - new_h) // 2))
    if save_debug:
        os.makedirs("app/inference/output_pre", exist_ok=True)
        timestamp = time.strftime("%Y%m%d_%H%M%S")
        final_image.save(f"app/inference/output_pre/output_{timestamp}.png")
    return final_image

# 색상 간의 거리 기반 유사도 측정

def predict_pill_with_ocr_color(
        image: Image.Image, 
        color_json: dict, 
        label_json: dict, 
        mode="cosine",
        alpha=0.3, 
        beta=0.3, 
        gamma=0.4,
        user_id:str=None):
    total_start = time.time()

    # ✅ 1. YOLO Detection + Preprocessing
    det_start = time.time()
    bbox = get_main_bbox(image)
    if bbox is None:
        logger_model.warning("❌ Bounding box 추출 실패")
        return [], [], []
    processed = preprocess_image(image, bbox)
    logger_model.info(f"[YOLO-Detect] 처리 시간: {round(time.time() - det_start, 4)}초")

    # ✅ 2. YOLO Classification
    cls_start = time.time()
    results = cls_model.predict(processed, verbose=False)[0]
    if not hasattr(results, "probs") or results.probs is None:
        logger_model.warning("⚠️ YOLO 분류 확률(probs) 없음")
        return [], [], []
    probs_tensor = results.probs.data
    class_names = cls_model.names
    logger_model.info(f"[YOLO-Cls] 처리 시간: {round(time.time() - cls_start, 4)}초")

    # ✅ 3. 색상 추출 (중심부 평균 RGB)
    color_start = time.time()
    cropped_np = np.array(image.crop(bbox))
    h, w, _ = cropped_np.shape
    ch, cw = int(h * 0.2), int(w * 0.2)
    sh, sw = (h - ch) // 2, (w - cw) // 2
    center_crop = cropped_np[sh:sh+ch, sw:sw+cw]
    mean_rgb = np.mean(center_crop, axis=(0, 1))
    logger_model.info(f"[색상 추출] 처리 시간: {round(time.time() - color_start, 4)}초")

    # ✅ 4. OCR 텍스트 감지
    ocr_start = time.time()
    ocr_keywords = detect_text_pill(image)
    print(f"OCR 키워드 추출 결과: {ocr_keywords}")
    logger_model.info(f"[OCR 분석] 처리 시간: {round(time.time() - ocr_start, 4)}초")

    # ✅ 5. 최종 점수 계산 (YOLO + OCR + 색상 유사도)
    score_start = time.time()
    scored = []
    for idx in range(len(probs_tensor)):
        item_seq = class_names[idx]
        yolo_score = probs_tensor[idx].item()
        ocr_score = 1 if any(word in label_json.get(item_seq, "").upper() for word in ocr_keywords) else 0
        color_score = calculate_color_similarity(mean_rgb, color_json.get(item_seq, [0, 0, 0]), mode)
        final_score = alpha * yolo_score + beta * ocr_score + gamma * color_score
        scored.append((item_seq, final_score, yolo_score, ocr_score, color_score))

    if not scored:
        logger_model.warning("❌ 최종 후보 없음")
        return [], [], ocr_keywords

    scored.sort(key=lambda x: x[1], reverse=True)
    logger_model.info(f"[점수 계산] 처리 시간: {round(time.time() - score_start, 4)}초")

    # ✅ 결과 출력
    scored = [
        {
            "item_seq": item,
            "final_score": round(final or 0.0, 4),
            "yolo_score": round(yolo or 0.0, 4),
            "ocr_score": ocr or 0.0,
            "color_score": round(color or 0.0, 4)
        } for item, final, yolo, ocr, color in scored[:20]
    ]

    # ✅ 전체 처리 시간
    logger_model.info(f"[전체 추론 시간]: user_id={user_id}, {round(time.time() - total_start, 4)}초")

    return scored, bbox, ocr_keywords
