# YOLO8v_nano_cls  모델 로드 및 예측
# app/inference/yolo_cls.py
from ultralytics import YOLO
import torch
from PIL import Image, ImageOps
from app.utils.model_utils import get_dominant_color, calculate_color_similarity
import os
import torchvision.transforms as transforms
import json
import time
import logging
import numpy as np

logger = logging.getLogger(__name__)

# YOLO detection 모델 로드
detect_model_path = r"C:\Users\302-26\pilly-pilly\FastAPI\app\models\best_detec.pt"
det_model = YOLO(detect_model_path)  # 알약 detection 모델 경로

def get_main_bbox(image: Image.Image):
    """YOLO 모델을 통해 가장 확신도 높은 알약 bbox 추출"""
    results = det_model.predict(image, verbose=False)[0]

    if results.boxes is None or len(results.boxes.xyxy) == 0:
        return None  # bbox 없음

    # 신뢰도 기준 가장 높은 bbox 선택
    confidences = results.boxes.conf
    bboxes = results.boxes.xyxy
    max_idx = torch.argmax(confidences).item()
    return bboxes[max_idx].cpu().tolist()

# cls 모델 로드
model_path = r"C:\Users\302-26\pilly-pilly\FastAPI\app\models\best_cls2.pt"
model = YOLO(model_path)

def preprocess_image(image: Image.Image, bbox: list, save_debug: bool = True) -> Image.Image:
    """
    YOLO detection 결과 bbox를 기준으로 이미지 전처리

    1. bbox 영역만 crop
    2. 긴 쪽을 400px로 리사이즈 (비율 유지)
    3. 640x640 검정 배경 중앙에 패딩 삽입

    Args:
        image: 원본 PIL 이미지
        bbox: [x1, y1, x2, y2] 리스트(float) 형식의 좌표

    Returns:
        YOLO-CLS 입력용 (640x640) 이미지
    """
    # 1. bbox crop
    x1, y1, x2, y2 = map(int, bbox)
    cropped = image.crop((x1, y1, x2, y2))

    # 2. 비율 유지 리사이즈 (긴 쪽 400px)
    width, height = cropped.size
    if width >= height:
        new_w = 400
        new_h = int(400 * height / width)
    else:
        new_h = 400
        new_w = int(400 * width / height)

    resized = cropped.resize((new_w, new_h), Image.BICUBIC)

    # 3. 640x640 검정 배경에 가운데 삽입
    final_image = Image.new("RGB", (640, 640), (0, 0, 0))
    paste_x = (640 - new_w) // 2
    paste_y = (640 - new_h) // 2
    final_image.paste(resized, (paste_x, paste_y))

    #저장
    if save_debug:
        os.makedirs("output", exist_ok=True)
        timestamp = time.strftime("%Y%m%d_%H%M%S")
        final_image.save(f"app/inference/output_pre/ouput_{timestamp}.png")

    return final_image

# ✅ 예측 함수
def predict_pill(image: Image.Image):
    start_time = time.time()
    results = model.predict(image, verbose=False)[0]

    predictions = []
    item_seq_list = []

    if hasattr(results, "probs") and results.probs is not None:
        probs_tensor = results.probs.data
        top5_scores, top5_indices = torch.topk(probs_tensor, 10)

        for i in range(10):
            class_id = top5_indices[i].item()
            score = top5_scores[i].item()
            item_seq = results.names[class_id]
            predictions.append({
                "label": item_seq,
                "score": round(score * 100, 2),
                "item_seq": item_seq
            })
            item_seq_list.append(item_seq)

        top1_item_seq = predictions[0]["item_seq"]

        print("Top-10 예측:")
        for p in predictions:
            print(f"- {p['label']} ({p['score']}) → item_seq: {p['item_seq']}")

    else:
        print("⚠️ result.probs가 None입니다.")
        top1_item_seq = "unknown"
        item_seq_list = []

    elapsed = round(time.time() - start_time, 4)
    logger.info(f"[CLS 모델추론] 처리 시간: {elapsed}초")

    return item_seq_list, predictions, top1_item_seq
'''
def predict_pill(image: Image.Image):
    start_time = time.time()

    # 🔍 모델 추론
    results = model.predict(image, verbose=False)[0]

    # 🎨 입력 이미지의 대표 색상
    input_color = get_dominant_color(image, crop_ratio=0.4)

    predictions = []
    item_seq_list = []

    if hasattr(results, "probs") and results.probs is not None:
        probs_tensor = results.probs.data
        topk = 30
        top_scores, top_indices = torch.topk(probs_tensor, k=topk)

        for i in range(topk):
            class_id = top_indices[i].item()
            item_seq = results.names[class_id]  # ✅ class_id → item_seq 직접 매핑
            score = top_scores[i].item()

            pred_img_path = f"app/inference/image_color/{item_seq}.png"
            if not os.path.exists(pred_img_path):
                continue

            pred_image = Image.open(pred_img_path).convert("RGB")
            pred_color = get_dominant_color(pred_image)
            similarity = calculate_color_similarity(input_color, pred_color)
            normalized_similarity = similarity / 441.6729

            predictions.append({
                "label": item_seq,
                "score": round(score * 100, 2),
                "item_seq": item_seq,
                "color_similarity": normalized_similarity
            })

        # 🎯 색상 유사도 기반 Top-5 필터링
        predictions.sort(key=lambda x: x["color_similarity"])   # 낮을수록 유사
        #predictions = [p for p in predictions if p["color_similarity"] < 6.0]
        predictions = predictions[:15]
        item_seq_list = [p["item_seq"] for p in predictions]
        top1_item_seq = predictions[0]["item_seq"]

        print("🎯 필터링된 Top-10 예측:")
        for p in predictions:
            print(f"- {p['label']} | Score: {p['score']} | Similarity: {p['color_similarity']:.4f}")

    else:
        print("⚠️ result.probs가 None입니다.")
        top1_item_seq = "unknown"
        item_seq_list = []
        predictions = []

    elapsed = round(time.time() - start_time, 4)
    logger.info(f"[CLS 모델추론] 처리 시간: {elapsed}초")

    return item_seq_list, predictions, top1_item_seq
'''