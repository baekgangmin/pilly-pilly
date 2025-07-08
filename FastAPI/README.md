# 📁 FastAPI
pilly-pilly\FastAPI
├── .env                           # API 키 및 비밀 설정
├── .gitignore                     # 불필요 파일 제외 설정
├── README.md
├── requirements.txt
├── run.py                         # 앱 실행 진입점 (uvicorn)
├── 📁app
│   ├── main.py                    # FastAPI 인스턴스 및 라우터 등록
│   ├── core                       # 핵심 설정 및 유틸
│   │   ├── config.py              # 환경변수 불러오기 및 설정
│   │   ├── logger.py              # 로그 설정
│   │   └── dependencies.py        # DB 또는 공통 의존성 관리
│   ├── api                        # 라우터 모듈별 분리
│   │   ├── __init__.py
│   │   ├── v1
│   │   │   ├── __init__.py
│   │   │   ├── image_based.py     # 1-1, 1-2: YOLO → item_seq 기반
│   │   │   └── feature_based.py   # 2-1, 2-2: 특징기반 식별 검색
│   ├── services                   # API 호출 및 가공 서비스 로직
│   │   ├── __init__.py
│   │   ├── permit_service.py      # (2), (3) 제품 허가 정보
│   │   ├── e_drug_service.py    # (4) e약은요
│   │   ├── dur_service.py         # (5) DUR 품목정보
│   │   └── identify_feature_service.py    # (1) 낱알 식별 정보
│   ├── inference                  # YOLO 추론 로직
│   │   ├── yolo_cls.py            # YOLO classify 모델 로드 및 예측
│   │   └── preprocessor.py        # 이미지 전처리 함수 (필요 시)
│   ├── models                     # 모델 파일 저장 경로
│   │   └── best.pt                # YOLO classify 모델 가중치 파일
│   ├── db                         # MongoDB 연동 및 기록
│   │   ├── __init__.py
│   │   ├── mongodb.py             # 연결 설정 및 클라이언트 관리
│   │   └── models.py              # 저장할 로그 데이터 모델
│   ├── schemas                    # 요청/응답 모델 Pydantic 정의
│   │   ├── __init__.py
│   │   ├── request_models.py      # POST/GET 요청용 모델
│   │   └── response_models.py     # 응답 JSON 모델 정의
│   └── utils
│       ├── merge.py               # 다중 API 응답 병합 로직
│       └── formatter.py           # 날짜/문자열 포맷 변환 등 헬퍼 함수

# 📁 flutter
\pilly-pilly\flutter\yolo_demo\lib\screens
└── ... (별도 관리)

http://127.0.0.1:8000/docs