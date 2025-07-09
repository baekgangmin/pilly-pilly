# 이미지 전처리 함수

# app/inference/preprocessor.py
from PIL import Image

def preprocess_image(image_file) -> str:
    temp_path = "temp.jpg"
    with open(temp_path, "wb") as f:
        f.write(image_file.read())
    return temp_path
