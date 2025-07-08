# YOLO8v_nano_cls  모델 로드 및 예측

# app/inference/yolo_cls.py
import torch
from pathlib import Path

def load_model():
    model_path = Path(__file__).resolve().parent.parent / "models/best.pt"
    model = torch.hub.load("ultralytics/yolov5", "custom", path=str(model_path), force_reload=True)
    return model

def predict_image(image_path: str) -> str:
    model = load_model()
    results = model(image_path)
    item_seq = results.pandas().xyxy[0].iloc[0]["name"]
    return item_seq
