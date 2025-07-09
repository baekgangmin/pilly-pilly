from flask import Flask, request, jsonify
from flask_cors import CORS
from pymongo import MongoClient
from datetime import datetime
import os
from dotenv import load_dotenv
import requests

# .env 파일 로드
load_dotenv()
MONGO_URI = os.getenv("MONGO_URI")
DB_NAME = os.getenv("DB_NAME")
SERVICE_KEY = os.getenv("SERVICE_KEY")

app = Flask(__name__)
CORS(app)

client = MongoClient(MONGO_URI)
db = client[DB_NAME]
users_col = db["users"]
logs_col = db["search_logs"]

# DUR 데이터 수집 함수
def fetch_dur_data(sequence):
    base_url = "http://apis.data.go.kr/1471000/DURPrdlstInfoService03/"
    endpoints = {
        "병용금기": "getUsjntTabooInfoList03",
        "특정연령대금기": "getSpcifyAgrdeTabooInfoList03",
        "임부금기": "getPwnmTabooInfoList03",
        "용량주의": "getCpctyAtentInfoList03",
        "투여기간주의": "getMdctnPdAtentInfoList03",
        "노인주의": "getOdsnAtentInfoList03",
        "효능군중복": "getEfcyDplctInfoList03",
        "서방정분할주의": "getSeobangjeongPartitnAtentInfoList03"
    }

    results = {key: [] for key in endpoints}
    pill_name = "이름 없음"

    for category, endpoint in endpoints.items():
        url = base_url + endpoint
        params = {
            "serviceKey": SERVICE_KEY,
            "itemSeq": sequence,
            "type": "json"
        }
        try:
            response = requests.get(url, params=params)
            response.raise_for_status()
            data = response.json()
        except Exception as e:
            results[category].append({
                "item_name": "",
                "prohibition": f"{category} 정보 불러오기 실패"
            })
            continue

        items = data.get("body", {}).get("items", [])
        if not items:
            results[category].append({
                "item_name": "",
                "prohibition": "없음"
            })
            continue

        for idx, item in enumerate(items):
            type_name = (item.get("TYPE_NAME") or "").strip()
            prohbt_content = (item.get("PROHBT_CONTENT") or "").strip() or "없음"
            item_name = item.get("MIXTURE_ITEM_NAME") or item.get("ITEM_NAME") or ""
        
            if idx == 0 and pill_name == "이름 없음":
                pill_name = item.get("ITEM_NAME", "이름 없음") or "이름 없음"
        
            results[category].append({
                "item_name": item_name,
                "prohibition": prohbt_content
            })


    return {"pill_name": pill_name, "dur_info": results}

@app.route("/api/log_search", methods=["POST"])
def log_search():
    data = request.json
    user_id = data.get("user_id")
    pill_sequence = str(data.get("pill_sequence"))

    if not user_id or not pill_sequence:
        return jsonify({"error": "Missing user_id or pill_sequence"}), 400

    if not users_col.find_one({"user_id": user_id}):
        users_col.insert_one({"user_id": user_id, "created_at": datetime.utcnow()})

    fetch_result = fetch_dur_data(pill_sequence)

    if "error" in fetch_result:
        return jsonify({"error": fetch_result["error"]}), 500

    pill_name = fetch_result.get("pill_name", "이름 없음") or "이름 없음"
    result = fetch_result.get("dur_info", {})

    logs_col.insert_one({
        "user_id": user_id,
        "pill_sequence": pill_sequence,
        "pill_name": pill_name,
        "search_result": result,
        "search_time": datetime.utcnow()
    })

    return jsonify({
        "message": "검색 완료",
        "pill_name": pill_name,
        "result": result
    }), 200

@app.route("/api/get_search_logs", methods=["GET"])
def get_search_logs():
    user_id = request.args.get("user_id")
    if not user_id:
        return jsonify({"error": "user_id required"}), 400

    logs = logs_col.find({"user_id": user_id}).sort("search_time", -1).limit(5)
    result = [
        {
            "pill_sequence": log["pill_sequence"],
            "pill_name": log.get("pill_name", "이름 없음") or "이름 없음",
            "search_time": log["search_time"].isoformat()
        }
        for log in logs
    ]
    return jsonify(result), 200

@app.route("/api/get_search_result", methods=["GET"])
def get_search_result():
    user_id = request.args.get("user_id")
    pill_sequence = request.args.get("pill_sequence")
    if not user_id or not pill_sequence:
        return jsonify({"error": "Missing parameters"}), 400

    log_cursor = logs_col.find({
        "user_id": user_id,
        "pill_sequence": pill_sequence
    }).sort("search_time", -1).limit(1)

    log_list = list(log_cursor)
    if not log_list:
        return jsonify({"error": "No data"}), 404

    log = log_list[0]
    return jsonify({
        "pill_sequence": pill_sequence,
        "pill_name": log.get("pill_name", "이름 없음") or "이름 없음",
        "search_result": log.get("search_result", {})
    }), 200

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=True)
