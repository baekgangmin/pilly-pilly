# (2), (3) 식약처 허가 정보 : YOLO_cls->item_aeq 기반
#FastAPI\app\services\permit_service.py
import os
import requests
import xml.etree.ElementTree as ET
from fastapi import HTTPException, Request
from app.db.mongodb import permit_info_all_collection, permit_detail_collection, searchlog_collection
from app.db.models import SearchLog
from app.utils.logger import logger
from html import unescape
from bs4 import BeautifulSoup
import re

"""
#   (1) get_permit_detail(): 식약처 허가 상세정보   #
#   (2) get_permit_list(): 식약처 허가 목록   #

""" 

# ✅ permit_detail 조회
async def get_permit_detail(item_seq: str) -> dict:
    try:
        result = await permit_detail_collection.find_one({"itemSeq": item_seq})
        if not result:
            return {}
        result.pop("_id", None)
        return result
    except Exception as e:
        logger.error(f"❌ permit_detail 조회 실패: {e}")
        raise HTTPException(status_code=500, detail="permit_detail DB 조회 중 오류")


# ✅ permit_list 조회
async def get_permit_list(item_seq: str) -> dict:
    try:
        result = await permit_info_all_collection.find_one({"ITEM_SEQ": item_seq})
        if not result:
            return {}

        return {
            "itemSeq": result.get("ITEM_SEQ", ""),
            "itemName": result.get("ITEM_NAME", ""),
            "entpName": result.get("ENTP_NAME", ""),
            "imageUrl": result.get("BIG_PRDT_IMG_URL", ""),
            "specltyPblc": result.get("SPCLTY_PBLC", ""),
            "prductType": result.get("PRDUCT_TYPE", ""),
            "cancleDate": result.get("CANCEL_DATE", ""),
            "cancleName": result.get("CANCEL_NAME", ""),
        }
    except Exception as e:
        logger.error(f"❌ permit_list 조회 실패: {e}")
        raise HTTPException(status_code=500, detail="permit_list DB 조회 중 오류")


# ✅ permit 통합 조회
async def get_permit_combined(item_seq: str) -> dict:
    try:
        permit_detail = await get_permit_detail(item_seq)
        if not permit_detail:
            return {
                "permitDetail": {},
                "permitList": {}
            }

        permit_list = await get_permit_list(item_seq)

        return {
            "permitDetail": permit_detail,
            "permitList": permit_list
        }

    except Exception as e:
        logger.error(f"❌ 의약품 통합 조회 실패: {str(e)}")
        raise HTTPException(status_code=500, detail="❌ 의약품 통합 조회 실패")
    
'''
#   (4) MongoDB 이미지 검색 요약조회   #  
'''    
async def get_permit_summary(item_seq: str) -> dict:
    try:
        item = await permit_info_all_collection.find_one({"ITEM_SEQ": item_seq})

        if not item:
            logger.warning(f"🔍 item_seq {item_seq}에 해당하는 항목 없음")
            return {}
        
        item.pop("_id", None)

        return {
            "itemSeq": item.get("ITEM_SEQ", ""),
            "itemName": item.get("ITEM_NAME", ""),
            "entpName": item.get("ENTP_NAME", ""),
            "imageUrl": item.get("BIG_PRDT_IMG_URL", ""),
        }

    except Exception as e:
        logger.error(f"❌ get_permit_summary 실패: {str(e)}")
        raise HTTPException(status_code=500, detail="permit DB 조회 중 오류 발생")

''' 
#   (5) 통합 검색
'''   
async def search_permit_by_keywords(
    request: Request,
    keyword: str,
    user_id: str
):
    try:
        # CamelCase 또는 PascalCase를 공백으로 분리 (ex: AluminiumHydroxide → Aluminium Hydroxide)
        spaced_keyword = re.sub(r'([a-z])([A-Z])', r'\1 \2', keyword)

        # 키워드 전처리 (쉼표, 공백 기준 분리, 2자 이상만 허용)
        keyword_list = [k.strip() for k in re.split(r"[,\s]+", spaced_keyword) if len(k.strip()) >= 2]

        if not keyword_list:
            raise HTTPException(status_code=400, detail="검색어는 2자 이상이어야 합니다.")

        # OR 조건만 사용
        query_filter = {
            "$or": []
        }
        for kw in keyword_list:
            query_filter["$or"].extend([
                {"ITEM_NAME": {"$regex": f".*{re.escape(kw)}.*", "$options": "i"}},
                {"ITEM_ENG_NAME": {"$regex": f".*{re.escape(kw)}.*", "$options": "i"}},
                {"ITEM_INGR_NAME": {"$regex": f".*{re.escape(kw)}.*", "$options": "i"}},
                {"ITEM_ENG_INGR_NAME": {"$regex": f".*{re.escape(kw)}.*", "$options": "i"}}
            ])

        # 🔍 DB 검색
        results_cursor = permit_info_all_collection.find(query_filter)
        results = []
        async for doc in results_cursor:
            doc.pop("_id", None)
            results.append({
                "itemSeq": doc.get("ITEM_SEQ", ""),
                "itemName": doc.get("ITEM_NAME", ""),
                "entpName": doc.get("ENTP_NAME", ""),
                "imageUrl": doc.get("BIG_PRDT_IMG_URL", "")
            })

        logger.debug(f"[키워드 통합검색] | user={request.client.host} | keyword='{keyword}' | count={len(results)}")

        # ✅ 검색 로그 저장
        
        log = SearchLog(
            user_id=user_id,
            query={"source": "keyword","keyword": keyword},
            results={"items": results}
        )
        await searchlog_collection.insert_one(log.model_dump())

        return {"items": results}

    except Exception as e:
        logger.error(f"❌ 통합검색 실패: {str(e)}")
        raise HTTPException(status_code=500, detail="통합검색 오류 발생")
    
"""
##---------------------------정제-----------------------------------
#    permit_detail 정제응답    #
"""
def parse_html_table(tbody_html):
    result = []
    try:
        soup = BeautifulSoup(tbody_html, "html.parser")
        rows = soup.find_all("tr")
        for row in rows:
            cells = row.find_all(["td", "th"])
            row_data = [cell.get_text(strip=True) for cell in cells]
            if row_data:
                result.append(row_data)
    except Exception:
        pass
    return result

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

def extract_all_tables(paragraphs):
    tables = []

    for p in paragraphs:
        if "<tbody" in p.lower() or "<table" in p.lower():
            rows = parse_html_table(p)
            if not rows:
                continue

            # 헤더 추출: 첫 행이 2개 이상 셀을 가지면 header로 간주
            if len(rows[0]) >= 2:
                headers = rows[0]
                data_rows = rows[1:]
            else:
                headers = []
                data_rows = rows

            tables.append({
                "headers": headers,
                "rows": data_rows
            })

    return tables


def inject_tables_into_paragraphs(paragraphs, tables):
    """
    <tbody> 또는 <table> 포함된 항목을 {"table": ...}로 대체
    """
    new_paragraphs = []
    table_idx = 0

    for p in paragraphs:
        if ("<tbody" in p.lower() or "<table" in p.lower()) and table_idx < len(tables):
            new_paragraphs.append({"table": tables[table_idx]})
            table_idx += 1
        else:
            new_paragraphs.append(p)
    return new_paragraphs


def normalize_permit_detail(raw: dict) -> dict:
    raw_precautions = parse_xml_list(raw.get("NB_DOC_DATA") or "")
    contraindications = raw_precautions[:5]
    warnings = raw_precautions[5:]

    tables = extract_all_tables(raw_precautions)
    injected_warnings = inject_tables_into_paragraphs(warnings, tables)

    raw_dosage = parse_xml_list(raw.get("UD_DOC_DATA") or "")
    cleaned_dosage = [clean_html(d) for d in raw_dosage if d and d.strip()]

    return {
        "itemSeq": (raw.get("ITEM_SEQ") or "").strip(),
        "itemName": (raw.get("ITEM_NAME") or "").strip(),
        "engName": (raw.get("ITEM_ENG_NAME") or "").strip(),
        "manufacturer": (raw.get("ENTP_NAME") or "").strip(),
        "permitDate": (
            f"{raw.get('ITEM_PERMIT_DATE')[:4]}-{raw.get('ITEM_PERMIT_DATE')[4:6]}-{raw.get('ITEM_PERMIT_DATE')[6:]}"
            if raw.get("ITEM_PERMIT_DATE") and len(raw.get("ITEM_PERMIT_DATE")) == 8 else None
        ),
        "consignManufacturer": raw.get("CNSGN_MANUF") or "-",
        "chart": raw.get("CHART") or "-",
        "packUnit": (raw.get("PACK_UNIT") or "").strip(),
        "validTerm": (raw.get("VALID_TERM") or "").strip(),
        "storageMethod": (raw.get("STORAGE_METHOD") or "").strip(),
        "mainIngredient": ", ".join([
            part.split("]")[-1].strip()
            for part in (raw.get("MAIN_ITEM_INGR") or "").split("|")
            if part and "]" in part
        ]) if raw.get("MAIN_ITEM_INGR") else None,
        "mainIngredientEng": (raw.get("MAIN_INGR_ENG") or "").strip(),
        "materialInfo": parse_material_info(raw.get("MATERIAL_NAME") or ""),
        "excipients": [
            i.split("]")[-1].strip()
            for i in (raw.get("INGR_NAME") or "").split("|")
            if i and "]" in i
        ] if raw.get("INGR_NAME") else [],
        "efficacy": parse_xml_list(raw.get("EE_DOC_DATA") or ""),
        "dosage": cleaned_dosage,
        "precautions": {
            "contraindications": contraindications,
            "warnings": injected_warnings
        }
    }