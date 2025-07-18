#MongoDB에 식별검색 전체 캐시 저장

import requests
import time
import pymongo
from tqdm import tqdm
from app.core.config import settings
import os
#✅ 07-17 10000개 103페이지까지 저장
#✅ 07-18 25796개 261페이지까지 저장
#✅ 정재-검증 26081개

# MongoDB 연결 설정
mongo_client = pymongo.MongoClient(settings.mongodb_uri)
db = mongo_client[settings.mongodb_db_name]
collection = db[settings.mongodb_identify_name]

# 중복 방지를 위해 색인 생성
collection.create_index("ITEM_SEQ", unique=True)

# API 기본 설정
SERVICE_KEY = os.getenv("SERVICE_KEY")
BASE_URL = "https://apis.data.go.kr/1471000/MdcinGrnIdntfcInfoService02/getMdcinGrnIdntfcInfoList02"
NUM_OF_ROWS = 100
LIMIT_PER_RUN = 26098  # 1회당 최대 저장 개수

# 마지막 저장된 페이지 로딩 (없으면 1로 시작)
page_file_path = r"C:\Users\302-26\pilly-pilly\FastAPI\db_last_page.txt"
if os.path.exists(page_file_path):
    with open(page_file_path, "r") as f:
        start_page = int(f.read().strip())
else:
    start_page = 1

# 전체 페이지 계산
params = {
    "serviceKey": SERVICE_KEY,
    "type": "json",
    "pageNo": 1,
    "numOfRows": 1,
}
response = requests.get(BASE_URL, params=params)
total_count = response.json().get("body", {}).get("totalCount", 0)
total_pages = (total_count // NUM_OF_ROWS) + 1

# 캐싱 시작
inserted = 0
current_page = start_page

for page in tqdm(range(start_page, total_pages + 1), desc="약물 데이터 캐시 중"):
    if inserted >= LIMIT_PER_RUN:
        break

    params.update({
        "pageNo": page,
        "numOfRows": NUM_OF_ROWS,
    })

    try:
        response = requests.get(BASE_URL, params=params, timeout=10)
        response.raise_for_status()
        items = response.json().get("body", {}).get("items", [])

        for item in items:
            try:
                collection.insert_one(item)
                inserted += 1
                if inserted >= LIMIT_PER_RUN:
                    break
            except pymongo.errors.DuplicateKeyError:
                continue  # 이미 저장된 item은 skip

    except Exception as e:
        print(f"❌ {page}페이지 오류: {str(e)}")

    current_page += 1
    time.sleep(0.2)  # 트래픽 과다 방지

# 다음 실행을 위한 페이지 저장
with open(page_file_path, "w") as f:
    f.write(str(current_page))

mongo_client.close()
print(f"✅ 이번에 저장된 약물 수: {inserted}개 | 다음 시작 페이지: {current_page}")
