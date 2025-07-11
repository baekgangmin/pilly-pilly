# (2), (3) 식약처 허가 정보 : YOLO_cls->item_aeq 기반
#FastAPI\app\services\permit_service.py
import os
import requests
import xml.etree.ElementTree as ET
from fastapi import HTTPException
from app.schemas.response_models import PermitDetail
from html import unescape
from bs4 import BeautifulSoup
from dotenv import load_dotenv

load_dotenv(dotenv_path=".env", override=True)
SERVICE_KEY = os.getenv("SERVICE_KEY")

"""
#   (1) get_permit_detail(): 식약처 허가 상세정보   #
#   (2) get_permit_list(): 식약처 허가 목록   #

""" 
def get_permit_detail(item_seq: str) -> dict:
    base_url = "https://apis.data.go.kr/1471000/DrugPrdtPrmsnInfoService06/getDrugPrdtPrmsnDtlInq05"
    params = {
        "serviceKey": SERVICE_KEY,
        "type": "json",
        "item_seq": item_seq,
        "pageNo": 1,
        "numOfRows": 1,
    }

    try:
        response = requests.get(base_url, params=params, timeout=10)
        response.raise_for_status()
        data = response.json()
        items = data.get("body", {}).get("items", [])
        raw = items[0] if items else {}
        normalized = normalize_permit_detail(raw)
        return normalized
    
    except Exception as e:
        # 오류가 발생해도 빈 딕셔너리 반환 (서버 장애 방지 목적)
        return {}


def get_permit_list(item_name: str) -> dict:
    base_url = "https://apis.data.go.kr/1471000/DrugPrdtPrmsnInfoService06/getDrugPrdtPrmsnInq06"
    params = {
        "serviceKey": SERVICE_KEY,
        "type": "json",
        "item_name": item_name.strip(),
        "pageNo": 1,
        "numOfRows": 1,
    }

    try:
        response = requests.get(base_url, params=params, timeout=10)
        response.raise_for_status()
        data = response.json()
        items = data.get("body", {}).get("items", [])
        if not items:
            return {}

        raw = items[0]
        return {
            "itemSeq": raw.get("ITEM_SEQ"),
            "itemName": raw.get("ITEM_NAME"),
            "entpName": raw.get("ENTP_NAME"),
            "imageUrl": raw.get("BIG_PRDT_IMG_URL"),
            "specltyPblc": raw.get("SPCLTY_PBLC"),
            "prductType": raw.get("PRDUCT_TYPE")
        }
    except Exception as e:
        return {}



"""
#   (1)+(2) item_seq 기반으로 제품 허가 상세 및 목록 정보를 함께 조회   #

""" 
def get_permit_combined(item_seq: str) -> dict:

    try:
        permit_detail = get_permit_detail(item_seq)
        if hasattr(permit_detail, "dict"):
            permit_detail = permit_detail.dict()

        item_name = permit_detail.get("itemName", "").strip()

        if not item_name:
            return {
                "permitDetail": {},
                "permitList": {}
            }

        permit_list = get_permit_list(item_name)

        return {
            "permitDetail": permit_detail,
            "permitList": permit_list
        }

    except Exception as e:
        raise HTTPException(status_code=500, detail=f"❌ 의약품 통합 조회 실패: {str(e)}")
    


"""
#   (4) 이미지 검색 요약조회   #

"""   
def get_permit_summary(item_seq: str) -> dict:
    try:
        # 1️⃣ 상세 정보 먼저 조회
        permit_detail = get_permit_detail(item_seq)
        if hasattr(permit_detail, "dict"):
            permit_detail = permit_detail.dict()

        item_name = permit_detail.get("itemName", "").strip()

        if not item_name:
            return {}

        # 2️⃣ 이름으로 전체 리스트 재조회 (가장 유사한 제품)
        permit_list = get_permit_list(item_name)

        return {
            "itemSeq": permit_list.get("itemSeq"),
            "itemName": permit_list.get("itemName"),
            "entpName": permit_list.get("entpName"),
            "imageUrl": permit_list.get("imageUrl"),
        }

    except Exception as e:
        return {}

"""
##---------------------------정제-----------------------------------

#    permit_detail 정제응답    #

"""

def normalize_permit_detail(raw: dict) -> dict:
    def parse_xml_list(xml_text):
        if not xml_text:
            return []
        try:
            root = ET.fromstring(unescape(xml_text))
            result = []
            for article in root.findall(".//ARTICLE"):
                title = article.get("title", "").strip()
                if title:
                    result.append(title)
                for p in article.findall(".//PARAGRAPH"):
                    if p.text and p.text.strip():
                        result.append(unescape(p.text.strip()))
            return result
        except ET.ParseError:
            return []

    def parse_material_info(material_text):
        if not material_text:
            return []
        return [s.strip() for s in material_text.split("|") if s.strip()]
    
    def clean_html(text):
        if "<" in text and ">" in text:
            return BeautifulSoup(text, "html.parser").get_text(strip=True)
        return text

    raw_dosage = parse_xml_list(raw.get("UD_DOC_DATA"))
    cleaned_dosage = [clean_html(d) for d in raw_dosage if d.strip()]

    return {
        "itemName": raw.get("ITEM_NAME", "").strip(),
        "engName": raw.get("ITEM_ENG_NAME", "").strip(),
        "manufacturer": raw.get("ENTP_NAME", "").strip(),
        "permitDate": (
            f"{raw.get('ITEM_PERMIT_DATE')[:4]}-{raw.get('ITEM_PERMIT_DATE')[4:6]}-{raw.get('ITEM_PERMIT_DATE')[6:]}"
            if raw.get("ITEM_PERMIT_DATE") else None
        ),
        "consignManufacturer": raw.get("CNSGN_MANUF") or "-",
        "chart": raw.get("CHART") or "-",
        "packUnit": raw.get("PACK_UNIT", "").strip(),
        "validTerm": raw.get("VALID_TERM", "").strip(),
        "storageMethod": raw.get("STORAGE_METHOD", "").strip(),
        "mainIngredient": ", ".join([part.split("]")[-1].strip() for part in raw.get("MAIN_ITEM_INGR", "").split("|") if part.strip()]) if raw.get("MAIN_ITEM_INGR") else None,
        "mainIngredientEng": raw.get("MAIN_INGR_ENG", "").strip(),
        "materialInfo": parse_material_info(raw.get("MATERIAL_NAME")),
        "excipients": [i.split("]")[-1].strip() for i in raw.get("INGR_NAME", "").split("|") if i.strip()],
        "efficacy": parse_xml_list(raw.get("EE_DOC_DATA")),
        "dosage": cleaned_dosage,
        "precautions": {
            "contraindications": parse_xml_list(raw.get("NB_DOC_DATA"))[:5],
            "warnings": parse_xml_list(raw.get("NB_DOC_DATA"))[5:]
        }
    }
