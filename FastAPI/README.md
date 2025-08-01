📁 pilly-pilly/FastAPI   
   
├── .env                      # 환경변수 설정 파일 (API 키 등 보안 정보)   
├── .gitignore   
├── README.md   
├── requirements.txt          # Python 의존성 패키지 목록   
├── run.py                    # FastAPI 실행 진입점 (uvicorn)   
   
├── 📁 app                    # FastAPI 애플리케이션 메인 디렉토리   
│   ├── main.py               # FastAPI 인스턴스 및 라우터 등록   
   
│   ├── 📁 core               # 공통 설정 및 의존성 관리   
│   │   ├── config.py         # 환경변수 로딩 및 기본 설정   
│   │   └── dependencies.py   # 의존성 주입 함수 정의   
   
│   ├── 📁 api                # API 라우터 모음   
│   │   └── 📁 v2             # v2 버전 API 라우터들   
│   │       ├── auth_router.py              # JWT 인증 라우터   
│   │       ├── favorite_log_router.py     # 즐겨찾기 등록/조회 라우터   
│   │       ├── gemini_chatbot.py          # Gemini 기반 챗봇 응답 라우터   
│   │       ├── identify_feature_based.py  # 특징 기반 알약 식별 라우터   
│   │       ├── image_based.py             # 이미지 기반 알약 식별 라우터   
│   │       ├── log_router.py              # 로그 저장용 라우터   
   
│   ├── 📁 services           # 외부 서비스 연동 모듈   
│   │   ├── permit_service.py             # 의약품 허가 정보 조회   
│   │   ├── e_drug_service.py            # e약은요 상세정보 조회   
│   │   ├── dur_service.py               # DUR(병용금기 등) 정보 조회   
│   │   ├── identify_feature_service.py  # 낱알 특징 기반 식별 로직   
│   │   └── gemini_client.py             # Gemini API 통신 모듈   
   
│   ├── 📁 inference          # AI 모델 추론 관련 모듈   
│   │   ├── yolo_cls.py                   # YOLO 분류 모델 추론   
│   │   ├── color.py                      # 이미지 색상 추출 및 유사도 계산   
│   │   ├── imput_img/                   # 입력 이미지 저장 경로   
│   │   ├── output_pre/                  # 추론 결과 이미지 저장 경로   
│   │   └── resources/                   # class/color 매핑 JSON 포함   
   
│   ├── 📁 models             # 학습된 모델 파일 보관 폴더   
│   │   ├── best_cls2.pt   
│   │   ├── best_detec.pt   
│   │   └── cls_run4.pt   
   
│   ├── 📁 db                 # DB 연동 및 모델 정의   
│   │   ├── mongodb.py                  # MongoDB 커넥션   
│   │   ├── models.py                   # Pydantic 기반 DB 모델   
│   │   ├── identify_to_db.py          # 알약 식별 결과 저장 처리   
│   │   └── permit_detail_to_db.py     # 제품 상세정보 저장 처리   
   
│   ├── 📁 schemas            # 요청/응답용 데이터 모델 정의   
│   │   └── response_models.py         # 응답 JSON 구조 정의   
   
│   └── 📁 utils              # 유틸리티 함수 모음   
│       ├── formatter.py                # 날짜, 텍스트 포맷   
│       ├── logger.py                   # 로깅 설정   
│       ├── model_utils.py              # 모델 관련 보조 함수   
│       ├── ocr_utils.py                # OCR 관련 유틸   
│       └── request_utils.py            # API 요청 보조 함수   
   
📁 logs/   
├── gemini_chat.log                   # Gemini 챗봇 사용 로그   
├── inference.log                     # 추론 시스템 실행 로그   
   
📁 output/                             # 서비스 실행 결과 저장용 폴더   
   
📁 tts_server/                         # TTS 음성 변환 서브시스템 (RealTime_zeroshot_TTS_ko)   
├── RealTime_zeroshot_TTS_ko/        # 오픈소스 기반의 TTS 모델 전체 구조 포함   
├── custom_tts.py                    # FastAPI 연동을 위한 TTS 캡슐화 클래스   
├── demo_1(scratch).ipynb            # 테스트용 스크래치 노트북   
├── output/                          # 생성된 음성 결과(wav 파일) 저장 폴더   
├── processed/                       # 사용자 음성 처리 결과 저장   
└── requirements.txt                 # TTS 관련 패키지 목록   


