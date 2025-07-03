#  app/services/drug_api.py
import requests
import urllib.parse
import os
from dotenv import load_dotenv

load_dotenv()
SERVICE_KEY = os.getenv("API_KEY")

def get_pill_by_name(item_seq: str):
    base_url = "https://apis.data.go.kr/1471000/DrugPrdtPrmsnInfoService06/getDrugPrdtPrmsnDtlInq05"
    params = {
        "serviceKey": SERVICE_KEY,
        "type": "json",
        "item_seq": item_seq,
        "pageNo": 1,
        "numOfRows": 10
    }
    res = requests.get(base_url, params=params, timeout=15)
    return res.json()
    
