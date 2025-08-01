# AI 기반 경구용 의약품 식별 및 복용 안전 정보 지원 시스템

![메인 이미지](images/pilly_main_image.png)

<h1 align="center">💊 AI 기반 이미지 인식 + 특징 검색을 통한 약물 정보 통합 서비스</h1>
<p align="center">이미지와 약명 입력으로 복약 금기 사항까지 자동 분석하는 <b>스마트 복약 도우미</b></p>

<div align='center'>
👩🏻‍⚕️ Member

|팀장|팀원|팀원|
| :-: | :-: | :-: |
| <img src="https://github.com/baekgangmin/pilly-pilly/blob/main/images/%ED%94%84%EB%A1%9C%ED%95%84.png" width="200"> |<img src="https://github.com/baekgangmin/pilly-pilly/blob/main/images/%ED%94%84%EB%A1%9C%ED%95%843.png" width="200"> |<img src="https://github.com/baekgangmin/pilly-pilly/blob/main/images/%ED%94%84%EB%A1%9C%ED%95%842.png" width="200"> |
|[박지현](https://github.com/jihyeon602)|[김도현](https://github.com/doxxeon)|[백경민](https://github.com/baekgangmin)|
</div>

---

## 🚀 주요 기능

- **YOLO 기반 알약 실시간 이미지 인식**
- **색상, 모양, 글자 기반 특징 검색**
- **즐겨찾기 및 최근 검색 기록 관리 (SQLite & MongoDB 연동)**
- **약물 정보 조회 및 DUR(의약품 안전사용 서비스) 데이터 제공**
- **챗봇 기능으로 사용자 맞춤형 질의응답**

---

## 🏗 기술 스택

- **Frontend**: Flutter (Dart)
- **Backend**: FastAPI (Python)
- **Database**: SQLite (Local), MongoDB (Server)
- **AI Model**: YOLOv8-detection, YOLOv8-cls, Google OCR, Color (Python)

---

## 🖼 스크린샷

| 메인 화면 | 특징 기반 | 이미지 기반 | 결과 화면 | 
| :-: | :-: | :-: | :-: |
| ![](images/main_screen.jpg) | ![](images/feature_search_screen.jpg) | ![](images/image_search_screen.jpg) | ![](images/result_screen.jpg) |

---

## 🎥 데모 영상

<div align="center">

[![Web 관리자 페이지](https://img.youtube.com/vi/IV8XzZG4Yd0/0.jpg)](https://youtu.be/IV8XzZG4Yd0)
[![이미지 기반 검색 & 즐겨찾기](https://img.youtube.com/vi/g40qPM8jQJE/0.jpg)](https://youtube.com/shorts/g40qPM8jQJE)
[![특징 기반 & 병용금기](https://img.youtube.com/vi/LP5ESFBI3Mo/0.jpg)](https://youtube.com/shorts/LP5ESFBI3Mo)
[![Chat Bot & TTS](https://img.youtube.com/vi/vbWT88z9sDA/0.jpg)](https://youtube.com/shorts/vbWT88z9sDA)

</div>
