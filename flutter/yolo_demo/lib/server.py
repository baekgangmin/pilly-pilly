from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
import google.generativeai as genai
import os
import json
import requests

app = FastAPI()

# 모든 도메인(*)에서 들어오는 요청 허용
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# Flutter에서 약 이름으로 상세 정보를 요청할 때 사용
SERVICE_KEY = "PYgq7s18hS5yFhC%2F5Azhj6zMKVBknzBEZKJdcyOX%2FLA7d18yE%2B5LhuLLdE7ZDtWRgIjdwNQJBnyheI4HSem%2Fqg%3D%3D"

@app.get("/api/v2/drug/search")
def search_pill(item_seq: str):
    url = (
        "https://apis.data.go.kr/1471000/MdcinGrnIdntfcInfoService02/getMdcinGrnIdntfcInfoList02"
        f"?serviceKey={SERVICE_KEY}&item_seq={item_seq}&type=json"
    )

    try:
        response = requests.get(url)
        if response.status_code == 200:
            data = response.json()
            items = data.get("body", {}).get("items", [])

            if items:
                item = items[0]
                return {
                    "item": {
                        "item_seq": item.get("ITEM_SEQ", item_seq),
                        "item_name": item.get("ITEM_NAME", "이름 없음"),
                        "item_image": item.get("ITEM_IMAGE", "https://via.placeholder.com/120")
                    }
                }

            return {"error": "검색된 알약 정보 없음"}
        else:
            return {"error": f"API 호출 실패: {response.status_code}"}
    except Exception as e:
        return {"error": f"오류 발생: {str(e)}"}

# gemini
# 서비스 계정 키 경로 설정
os.environ["GOOGLE_APPLICATION_CREDENTIALS"] = "gemini-key.json"  # json 파일명에 맞게 수정

# 모델 초기화 (최초 1회)
genai.configure()

model = genai.GenerativeModel("gemini-pro")

@app.post("/api/v2/chat/recommend")
async def recommend_pills(request: Request):
    data = await request.json()
    prompt = data.get("prompt", "")

    # 프롬프트 예시 구성
    gemini_prompt = f"""
    '{prompt}'에 대해 정확한 이름을 가진 알약을 3개 추천
    답장은 반드시 알약 이름만 띄어쓰기 없이 출력(ex. “알약이름”, “알약이름”, “알약이름”)
    """

    try:
        response = model.generate_content(gemini_prompt)
        # Gemini 응답에서 텍스트만 추출
        result_text = response.text.strip()

        # 정규식으로 약 이름 추출 (쉼표 기준)
        drug_list = [name.strip() for name in re.split(r',|,', result_text) if name.strip()]
        return drug_list

    except Exception as e:
        return {"error": str(e)}