# 선택형+생성형 챗봇
# FastAPI\app\services\gemini_client.py

import google.generativeai as genai
from app.core.config import settings
from google.api_core.exceptions import GoogleAPIError
from typing import Dict, Any

# ──────────────────────────────────────────────
# Gemini 설정
# ──────────────────────────────────────────────

genai.configure(api_key=settings.google_api_key)
model = genai.GenerativeModel("models/gemini-2.5-flash")

# ──────────────────────────────────────────────
# 질문 처리 함수: 
# prompt: 약 정보(통합)+ 사용자 입력 값 
# ──────────────────────────────────────────────
def ask_gemini(drug_summary: str, user_input: str) -> str:
    prompt = f"""다음은 의약품에 대한 상세 정보입니다. 이 정보를 바탕으로 아래 질문에 대해 **의료전문가가 설명하듯, 이해하기 쉬운 자연스러운 10문장이내로 요약**해 주세요.
정보 요약은 사용자에게 핵심만 전달하되, 필요 시 예시를 들어 설명해도 좋습니다. 질문이 의약품과 무관한 경우에는 정중히 안내해 주세요.

약 정보:
{drug_summary}

질문:
{user_input}
"""
    try:
        response = model.generate_content(prompt)
        return response.text.strip()
    except GoogleAPIError as api_err:
        return f"[API 오류] Gemini API 호출 실패: {api_err.message}"
    except Exception as e:
        return f"[예외] 처리 중 오류 발생: {str(e)}"

# ──────────────────────────────────────────────
# drug_info 요청 처리 함수: 
# prompt: 약 정보(통합)+ 사용자 입력 값 
# ──────────────────────────────────────────────

def parse_drug_info_json(drug_info: Dict[str, Any]) -> str:
    try:
        # STEP 1: results에서 첫 번째 itemSeq 블록 추출
        if "results" in drug_info and isinstance(drug_info["results"], dict):
            results_values = list(drug_info["results"].values())
            if not results_values:
                return "[파싱 오류] results 내부에 약 정보가 없습니다."
            drug_info = results_values[0]
        else:
            return "[파싱 오류] results 키가 없거나 형식이 잘못됨"

        # STEP 2: 주요 블록 분리
        permit_detail = drug_info.get("permit", {}).get("permitDetail", {})
        dur_info = drug_info.get("dur", {})

        # STEP 3: 기본정보 파싱
        name = permit_detail.get("itemName", "")
        eng_name = permit_detail.get("engName", "")
        manufacturer = permit_detail.get("manufacturer", "")
        validTerm = permit_detail.get("validTerm", "")
        storageMethod = permit_detail.get("storageMethod", "")
        ingredient = permit_detail.get("mainIngredient", "")
        excipients = permit_detail.get("excipients", [])
        efficacy = " / ".join(permit_detail.get("efficacy", []))
        dosage = permit_detail.get("dosage", [])
        contraindications = permit_detail.get("precautions", {}).get("contraindications", [])
        precaution_summary = contraindications[0] if contraindications else ""

        # STEP 4: DUR 정보 전체 처리
        dur_sections = []
        for dur_key, entries in dur_info.items():
            if not isinstance(entries, list) or not entries:
                continue
            section_title = entries[0].get("typeName", dur_key)
            summaries = []
            for entry in entries:
                drug_name = entry.get("mixtureItemName", "") or entry.get("itemName", "")
                reason = entry.get("prohibitContent", "") or entry.get("prohibitReason", "")
                if drug_name or reason:
                    summaries.append(f"{drug_name} - {reason}".strip(" -"))
            if summaries:
                dur_sections.append(f"{section_title}: {', '.join(summaries)}")

        # STEP 5: 최종 요약문 구성
        summary_lines = list(filter(None, [
            f"제품명: {name}",
            f"영문명: {eng_name}",
            f"제조사: {manufacturer}",
            f"유효기간: {validTerm}",
            f"보관법: {storageMethod}"
            f"주성분: {ingredient}",
            f"첨가제: {excipients}",
            f"효능: {efficacy}",
            f"복용법: {dosage}",
            f"주의사항: {precaution_summary}",
        ])) + dur_sections

        return "\n".join(summary_lines).strip()

    except Exception as e:
        return f"[파싱 오류] {str(e)}"
