# 베이스 모델 정의
<br>
✅ YOLOv8-detect 베이스 모델

| 항목              | 설명                   | 
| --------------- | -------------------- | 
| 1. 모델 구조 파일     | [args.yaml](./yolov8n_detect/args.yaml)      | 
| 2. 모델 가중치 파일    | [detect_best.pt](./yolov8n_detect/best.pt) | 
| 3. Inference 코드 | - yolov8n 모델을 사용하여 객체 탐지 수행<br> - 입력: 알약 이미지<br> - 출력: 탐지 결과 이미지<br> - 명령어: [CLI명령어](./yolov8n_detect/inference) | 
| 4. 사용 설명서       | 입력 형식, 실행법 등 포함 문서   |
| 5. 라벨 또는 클래스 정의 | - 탐지 대상: 알약<br>  - 클래스 정보: [pill](./yolov8n_detect/data.yaml)         | 
| 6. 예시 데이터 및 결과  | <img src="./yolov8n_detect/detect_img1.jpg" width="200">  <img src="./yolov8n_detect/detect_img2.jpg" width="200">     | 

<br>

✅ YOLOv8n-cls 베이스 모델

| 항목              | 설명               | 
| --------------- | ---------------- | 
| 1. 모델 구조 파일     | [args.yaml]()  | 
| 2. 모델 가중치 파일    | [classify_best.pt]()   | 
| 3. Inference 코드 | - yolov8n-cls 모델을 사용하여 이미지 분류 수행<br> - 입력: 알약 이미지<br> - 출력: 분류된 클래스 이름 및 확률<br> - 명령어: [CLI 명령어]()  | 
| 4. 사용 설명서       |  - 환경: Colab, !pip install ultralytics <br> - 디렉토리 구조: <br>data_split_yolov8/<br>├── train/<br>│   ├── pill_A/<br>│   ├── pill_B/<br>│   └── pill_C/<br>├── val/<br>│   ├── pill_A/<br>│   ├── pill_B/<br>│   └── pill_C/<br> - 학습: [train_code]() <br> - 예측: [predict_code]() | 
| 5. 라벨 또는 클래스 정의 | - 라벨: 알약 30종    | 
| 6. 예시 데이터 및 결과  | <img src="./yolov8n_detect/detect_img1.jpg" width="200">  <img src="./yolov8n_detect/detect_img2.jpg" width="200">     | 
