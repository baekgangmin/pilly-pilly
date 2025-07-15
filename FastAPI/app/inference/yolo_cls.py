# YOLO8v_nano_cls  모델 로드 및 예측
# app/inference/yolo_cls.py
from ultralytics import YOLO
import torch
from PIL import Image, ImageOps
import torchvision.transforms as transforms
import json
import os

# 모델 로드
model_path = r"C:\Users\302-26\pilly-pilly\FastAPI\app\models\best_cls.pt"
model = YOLO(model_path)


# 이미지 전처리 함수
def preprocess_image(image: Image.Image):
    # 1. 중앙 정렬하여 정사각형 패딩
    padded = ImageOps.pad(image, (224, 224), method=Image.BICUBIC, color=(255, 255, 255))
    
    # 2. Tensor 변환
    transform = transforms.ToTensor()
    return transform(padded).unsqueeze(0)

############
# 예측 함수
def predict_pill(image: Image.Image):
    input_tensor = preprocess_image(image)

    results = model.predict(input_tensor, verbose=False)[0]

    # JSON에서 item_seq 매핑
    with open("app/inference/class_id_to_item_seq.json", "r", encoding="utf-8") as f:
        class_map = json.load(f)

    predictions = []
    item_seq_list = []

    if hasattr(results, "probs") and results.probs is not None:
        probs_tensor = results.probs.data  # tensor of shape [num_classes]

        # ✅ top5 추출
        top5_scores, top5_indices = torch.topk(probs_tensor, k=5)

        for i in range(5):
            class_id = top5_indices[i].item()
            label = results.names[class_id]
            score = top5_scores[i].item()
            item_seq = results.names[class_id]
            predictions.append({
                "label": item_seq,
                "score": round(score * 100, 2),
                "item_seq": item_seq
            })
            item_seq_list.append(item_seq)

        # ✅ 가장 확률 높은 예측
        top1_item_seq = predictions[0]["item_seq"]

        # 🔍 디버깅용 출력
        print("Top-5 예측:")
        for p in predictions:
            print(f"- {p['label']} ({p['score']}) → item_seq: {p['item_seq']}")

        # ✅ 추가: results.probs.top5도 출력
        print("📌 results.probs.top5:", results.probs.top5)
        print("📌 results.probs.top1:", results.probs.top1)

    else:
        print("⚠️ result.probs가 None입니다.")
        top1_item_seq = "unknown"
        item_seq_list = []

    return item_seq_list, predictions, top1_item_seq
    
