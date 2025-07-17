# 📁 pilly-pilly/FastAPI   
├── .env                      # 환경변수 설정 파일 (API 키 등 보안 정보)   
├── .gitignore                  
├── README.md                   
├── requirements.txt          # Python 의존성 패키지 목록   
├── run.py                    # FastAPI 실행 진입점 (uvicorn)   
   
├── 📁app                       # 애플리케이션 핵심 모듈 디렉토리   
│   ├── main.py               # FastAPI 인스턴스, 라우터 등록   
   
│   ├── 📁core                  # 공통 설정 및 의존성 주입   
│   │   ├── config.py         # 환경변수 로딩 및 기본 설정   
│   │   └── dependencies.py   # 공통 의존성 주입 정의   

│   ├── 📁api                   # FastAPI 라우터 정의   
│   │   ├── __init__.py   
│   │   └── 📁v2                # v2 API 라우터 디렉토리   
│   │       ├── identify_feature_based.py   # 특징 기반 식별 추론 라우터   
│   │       ├── image_based.py              # 이미지 기반 식별 추론 라우터   
│   │       ├── log_router.py               # 로그 저장 라우터   
│   │       ├── gemini_chatbot.py           # gemini 챗봇 라우터   
│   │       └── favorite_log_router.py      # 즐겨찾기 로그 저장 라우터  
   
│   ├── 📁services              # 외부 공공 API 연동 서비스 모듈   
│   │   ├── permit_service.py             # 의약품 제품 허가정보 연동   
│   │   ├── e_drug_service.py            # e약은요 상세정보 연동   
│   │   ├── dur_service.py               # DUR 금기 정보 연동   
│   │   ├── identify_feature_service.py  # 낱알식별 기능 서비스 로직   
│   │   └── gemini_client.py             # gemini api 연동 및 질의응답 로직   
    
│   ├── 📁inference             # AI 모델 추론 모듈   
│   │   ├── yolo_cls.py                   # YOLO 분류 모델 예측 로직   
│   │   └── class_id_to_item_seq.json    # class_id와 item_seq 매핑 정보   
   
│   ├── 📁models                # 학습된 모델 파일   
│   │   └── best_cls.pt            # YOLO 분류 모델 가중치      
   
│   ├── 📁db                    # MongoDB 연동 및 데이터 모델 정의   
│   │   ├── mongodb.py                  # MongoDB 연결 클라이언트   
│   │   └── models.py                   # 공통 Pydantic 모델 정의     
   
│   ├── 📁schemas               # Pydantic 기반 요청/응답 모델 정의   
│   │   ├── __init__.py   
│   │   └── response_models.py         # 응답 구조 모델 정의   
   
│   └── 📁utils                 # 헬퍼 및 유틸 함수 모음   
│       ├── formatter.py                # 날짜, 문자열 포맷 유틸   
│       └── logger.py                   # 로그 설정 유틸   
