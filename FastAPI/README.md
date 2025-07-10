# 📁 FastAPI
pilly-pilly/FastAPI
├── .env                           # API 키 및 민감 정보 환경변수
├── .gitignore                    
├── README.md                    
├── requirements.txt              
├── run.py                        # 앱 실행 진입점 (uvicorn 실행 스크립트)
│
├── 📁 app                        # 🧠 핵심 애플리케이션 로직
│   ├── main.py                   # FastAPI 인스턴스 및 라우터 등록
│
│   ├── 📁 core                   # ⚙️ 설정 및 공통 유틸
│   │   ├── config.py             # 환경변수 로딩 및 설정
│   │   ├── logger.py             # 로깅 설정
│   │   └── dependencies.py       # 공통 의존성 주입
│
│   ├── 📁 api                    # 🌐 API 라우터 모듈
│   │   ├── __init__.py
│   │   ├── image_based.py        # 이미지 기반 item_seq 예측
│   │   └── feature_based.py      # 특징 기반 낱알식별 검색
│
│   ├── 📁 services               # 🧩 외부 공공 API 서비스 연동 로직
│   │   ├── __init__.py
│   │   ├── permit_service.py     # 의약품 제품 허가 정보 (API 2,3)
│   │   ├── e_drug_service.py     # e약은요 상세 조회 (API 4)
│   │   ├── dur_service.py        # DUR 금기정보 연동 (API 5)
│   │   └── identify_feature_service.py  # 낱알식별 Step1/Step2 핵심 서비스
│
│   ├── 📁 inference              # YOLO 추론 (분류)
│   │   ├── yolo_cls.py           # YOLO 분류 모델 로드 및 예측
│   │   └── preprocessor.py       # 이미지 전처리 함수 
│
│   ├── 📁 models                 # 학습된 모델 파일
│   │   └── best.pt               # YOLO classify 모델 가중치
│
│   ├── 📁 db                     # 🗃️ MongoDB 연동 및 로그 관리
│   │   ├── __init__.py
│   │   ├── mongodb.py            # DB 연결 및 클라이언트 설정
│   │   └── models.py             # 저장할 사용자 요청/응답 모델 정의
│
│   ├── 📁 schemas                # Pydantic 기반 요청/응답 모델
│   │   ├── __init__.py
│   │   ├── request_models.py     # POST 요청 모델 정의
│   │   └── response_models.py    # 응답 JSON 모델 구조 정의
│
│   └── 📁 utils                  # 보조 함수 및 포맷터
│       ├── merge.py              # API 응답 병합 로직
│       └── formatter.py          # 날짜, 문자열 포맷 헬퍼


# 📁 flutter
\pilly-pilly\flutter\yolo_demo\lib\screens
└── ... (별도 관리)

http://127.0.0.1:8000/docs