# (2), (3) 제품 허가 정보 : YOLO_cls->item_aeq 기반
#FastAPI\app\services\permit_service.py
import os
import requests
import xml.etree.ElementTree as ET
from fastapi import HTTPException
from app.schemas.response_models import PermitDetail
from dotenv import load_dotenv

load_dotenv(dotenv_path=".env", override=True)
SERVICE_KEY = os.getenv("SERVICE_KEY")

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
        return items[0] if items else {}
    except Exception as e:
        return {}



#item_seq 기반으로 제품 허가 상세 및 목록 정보를 함께 조회
def get_permit_combined(item_seq: str) -> dict:

    try:
        permit_detail = get_permit_detail(item_seq)
        if hasattr(permit_detail, "dict"):
            permit_detail = permit_detail.dict()

        item_name = permit_detail.get("itemName", "").strip()

        if not item_name:
            return {
                "permit_detail": {},
                "permit_list": {}
            }

        permit_list = get_permit_list(item_name)

        return {
            "permit_detail": permit_detail,
            "permit_list": permit_list
        }

    except Exception as e:
        raise HTTPException(status_code=500, detail=f"❌ 의약품 통합 조회 실패: {str(e)}")
    

###############이미지 검색 요약조회##############
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
            "item_seq": permit_list.get("ITEM_SEQ"),
            "item_name": permit_list.get("ITEM_NAME"),
            "entp_name": permit_list.get("ENTP_NAME"),
            "image_url": permit_list.get("BIG_PRDT_IMG_URL"),
        }

    except Exception as e:
        return {}
    


def normalize_permit_detail(raw: dict) -> dict:
    def parse_xml_list(xml_text):
        if not xml_text:
            return []
        root = ET.fromstring(xml_text)
        return [p.text.strip() for p in root.findall(".//PARAGRAPH") if p.text and p.text.strip()]

    def parse_material_info(material_text):
        if not material_text:
            return []
        return [s.strip() for s in material_text.split("|") if s.strip()]

    return {
        "itemName": raw.get("ITEM_NAME"),
        "engName": raw.get("ITEM_ENG_NAME"),
        "manufacturer": raw.get("ENTP_NAME"),
        "permitDate": f"{raw.get('ITEM_PERMIT_DATE')[:4]}-{raw.get('ITEM_PERMIT_DATE')[4:6]}-{raw.get('ITEM_PERMIT_DATE')[6:]}" if raw.get("ITEM_PERMIT_DATE") else None,
        "consignManufacturer": raw.get("CNSGN_MANUF"),
        "drugType": raw.get("ETC_OTC_CODE"),
        "chart": raw.get("CHART"),
        "packUnit": raw.get("PACK_UNIT"),
        "validTerm": raw.get("VALID_TERM"),
        "storageMethod": raw.get("STORAGE_METHOD"),
        "mainIngredient": raw.get("MAIN_ITEM_INGR").split("]")[-1] if raw.get("MAIN_ITEM_INGR") else None,
        "mainIngredientEng": raw.get("MAIN_INGR_ENG"),
        "materialInfo": parse_material_info(raw.get("MATERIAL_NAME")),
        "excipients": [i.split("]")[-1] for i in raw.get("INGR_NAME", "").split("|")],
        "efficacy": parse_xml_list(raw.get("EE_DOC_DATA")),
        "dosage": parse_xml_list(raw.get("UD_DOC_DATA")),
        "precautions": {
            "contraindications": parse_xml_list(raw.get("NB_DOC_DATA"))[:5],  # 1번 항목
            "warnings": parse_xml_list(raw.get("NB_DOC_DATA"))[5:]           # 2~ 이후 항목
        }
    }