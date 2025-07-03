✅ YOLOv8-detect 베이스 모델

| 항목              | 설명                   | 예시                                        |
| --------------- | -------------------- | ----------------------------------------- |
| 1. 모델 구조 파일     | 객체 탐지용 모델 구조 정의      | `detect.yaml`, `model.py`, `.json`        |
| 2. 모델 가중치 파일    | 학습된 객체 탐지 파라미터 저장 파일 | `best.pt`, `yolov8n.pt`                   |
| 3. Inference 코드 | 객체 탐지 실행 스크립트        | `detect.py`, `inference.py`               |
| 4. 사용 설명서       | 입력 형식, 실행법 등 포함 문서   | `README.md`, `사용자 가이드.docx`               |
| 5. 라벨 또는 클래스 정의 | 탐지 대상 클래스 정보         | `classes.txt`, `label_map.json`           |
| 6. 예시 데이터 및 결과  | <img src="./yolov8n_detect/detect_img1.jpg" width="200">  <img src="./yolov8n_detect/detect_img2.jpg" width="200">     | `example_input.jpg`, `output_result.json` |
<br>

✅ YOLO11m-cls 베이스 모델

| 항목              | 설명               | 예시                                        |
| --------------- | ---------------- | ----------------------------------------- |
| 1. 모델 구조 파일     | 이미지 분류 모델 구조 정의  | `cls.yaml`, `model.py`, `.json`           |
| 2. 모델 가중치 파일    | 학습된 분류 모델 파라미터   | `yolo11m-cls.pt`, `.ckpt`                 |
| 3. Inference 코드 | 분류 실행 코드         | `predict.py`, `classify.py`               |
| 4. 사용 설명서       | 분류 모델 사용법 포함 문서  | `README.md`, `분류_사용법.docx`                |
| 5. 라벨 또는 클래스 정의 | 클래스 인덱스/이름 매핑    | `classes.txt`, `label_map.json`           |
| 6. 예시 데이터 및 결과  | 이미지 입력과 분류 결과 예시 | `sample_image.jpg`, `predict_result.json` |
