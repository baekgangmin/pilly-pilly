# PillyPilly Frontend

Flutter 기반 **약품 식별 및 정보 제공 앱**의 프론트엔드입니다.  
YOLO 기반 이미지 인식과 특징 검색 기능을 활용하여 사용자에게 빠르고 정확한 약 정보와 추가 서비스(챗봇, 즐겨찾기 등)를 제공합니다.

---

## 📱 주요 기능

### 1. 실시간 YOLO 알약 인식
- 카메라 화면에서 YOLO-Detection 모델을 통해 알약 객체 탐지
- 탐지된 이미지 영역 캡처 및 후처리
- YOLO-cls / Google OCR / Color 세 가지 모델로 추론 후 최종 결과 반환
- Top-K 후보 약품 리스트 표시

### 2. 특징 기반 검색
- **색상, 모양, 글자(앞/뒤)** 조건으로 검색
- FastAPI 서버와 연동해 특징 매칭 결과 제공

### 3. 약품 상세 정보
- 약 이름, 제조사, 효능, DUR 정보 등 표시
- 즐겨찾기 기능 및 최근 검색 히스토리 지원

### 4. 챗봇 연동
- 약 관련 상세 질의 응답 (생성형 AI RAG 기반)
- 결과 페이지에서 "질문하기" 버튼을 통해 사용 가능

---

## 🏗 앱 구조

flutter/
├── lib/
│   ├── main.dart                # 앱 진입점
|   ├── db_helper.dart           # SQLite 저장 로직
│   ├── screens/                 # 주요 화면 (검색, 결과, 챗봇 등)
│   ├── presentation/            # 카메라 가이드 및 추론 화면
│   ├── web/                     # Web 관리자 페이지 화면
│   ├── api_services/            # API 연동 로직
│   └── models/                  # 데이터 모델 정의
└── assets/                       # 이미지, 모델, 로컬 데이터

---

## 🚀 실행 방법

### 1. 의존성 설치
```bash
flutter pub get

2. iOS 실행

flutter run -d ios

3. Android 실행

flutter run -d android

4. web (관리자 페이지) 실행

flutter run -d chrome --web-port=[port number]
(port number는 서버에서 허용해주는 것에 따라 다름)


⸻

🔑 환경 변수 설정
	•	lib/.env 파일 생성 후 API 키/엔드포인트 작성
(FastAPI 서버 URL 및 Model file Name)

API_BASE_URL=https://000.com
MODEL_FILE_NAME=000.tflite
TTS_BASE_URL=https://000.com


⸻

📌 TODO (향후 개선)
	•	모델 추론 속도 최적화 (TFLite INT8 변환 등)
	•	챗봇 UX 개선 (대화 기록 저장, 음성 입력 지원)
	•	오프라인 모드 지원

⸻

🛠 기술 스택
	•	Frontend: Flutter (Dart)
	•	AI 모델: YOLOv8 (TFLite) (iOS: CoreML 예정)
	•	State Management: 기본 Stateful + Provider 일부
	•	API 연동: FastAPI, 공공데이터 API

⸻
