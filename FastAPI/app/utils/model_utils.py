#FastAPI\app\utils\model_utils.py
from PIL import Image
import numpy as np
from sklearn.cluster import KMeans

from collections import Counter

def get_dominant_color(image: Image.Image, crop_ratio: float = 0.4, k: int = 3):
    img_np = np.array(image.convert("RGB"))
    h, w, _ = img_np.shape

    # 중앙 부분 크롭
    ch = int(h * crop_ratio)
    cw = int(w * crop_ratio)
    start_y = (h - ch) // 2
    start_x = (w - cw) // 2
    cropped = img_np[start_y:start_y + ch, start_x:start_x + cw].reshape(-1, 3)

    # KMeans 적용
    kmeans = KMeans(n_clusters=k, n_init=10, random_state=42)
    kmeans.fit(cropped)

    # 가장 빈도 높은 클러스터 번호를 찾기
    dominant_cluster = Counter(kmeans.labels_).most_common(1)[0][0]

    # dominant color 추출
    dominant_color = kmeans.cluster_centers_[dominant_cluster]
    return tuple(map(int, dominant_color))

def calculate_color_similarity(color1: tuple, color2: tuple) -> float:
    """
    두 RGB 색상 간의 평균 제곱 오차(MSE) → 낮을수록 유사
    정규화(0~1) 하려면 아래 주석 해제
    """
    mse = np.mean([(a - b) ** 2 for a, b in zip(color1, color2)])
    # return mse / 65025  # 0~1 범위로 정규화할 경우
    return mse
