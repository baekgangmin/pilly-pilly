# YOLO8v_nano_cls  모델 로드 및 예측
# app/inference/yolo_cls.py
from ultralytics import YOLO
import torch
from PIL import Image, ImageOps
import torchvision.transforms as transforms
import json


# 모델 로드
model_path = r"C:\Users\302-26\pilly-pilly\FastAPI\app\models\best_cls.pt"
model = YOLO(model_path)

def preprocess_image(image: Image.Image, target_size=(980, 1280)):
    target_bbox_width_ratio = 286 / 976
    target_bbox_height_ratio = 278 / 1280

    orig_w, orig_h = image.size

    crop_w = int(orig_w * target_bbox_width_ratio)
    crop_h = int(orig_h * target_bbox_height_ratio)

    center_x, center_y = orig_w // 2, orig_h // 2
    left = max(center_x - crop_w // 2, 0)
    top = max(center_y - crop_h // 2, 0)
    right = min(center_x + crop_w // 2, orig_w)
    bottom = min(center_y + crop_h // 2, orig_h)

    cropped = image.crop((left, top, right, bottom))

    if cropped.width > 286 or cropped.height > 278:
        scale_ratio = min(286 / cropped.width, 278 / cropped.height)
    else:
        scale_ratio = max(286 / cropped.width, 278 / cropped.height)

    new_w = int(cropped.width * scale_ratio)
    new_h = int(cropped.height * scale_ratio)
    resized_pill = cropped.resize((new_w, new_h), resample=Image.BICUBIC)

    final_canvas = Image.new("RGB", target_size, (0, 0, 0))
    paste_x = (target_size[0] - resized_pill.width) // 2
    paste_y = (target_size[1] - resized_pill.height) // 2
    final_canvas.paste(resized_pill, (paste_x, paste_y))

    return final_canvas

# ✅ 예측 함수
def predict_pill(image: Image.Image):
    results = model.predict(image, verbose=False)[0]

    with open("app/inference/class_id_to_item_seq.json", "r", encoding="utf-8") as f:
        class_map = json.load(f)

    predictions = []
    item_seq_list = []

    if hasattr(results, "probs") and results.probs is not None:
        probs_tensor = results.probs.data
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

        top1_item_seq = predictions[0]["item_seq"]

        print("Top-5 예측:")
        for p in predictions:
            print(f"- {p['label']} ({p['score']}) → item_seq: {p['item_seq']}")
        print("📌 results.probs.top5:", results.probs.top5)
        print("📌 results.probs.top1:", results.probs.top1)

    else:
        print("⚠️ result.probs가 None입니다.")
        top1_item_seq = "unknown"
        item_seq_list = []

    return item_seq_list, predictions, top1_item_seq

