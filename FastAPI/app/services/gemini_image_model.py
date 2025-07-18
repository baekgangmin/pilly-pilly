import google.generativeai as genai
from PIL import Image # 이미지 처리를 위해 필요합니다.
from google.api_core.exceptions import GoogleAPIError # API 오류 처리를 위해 추가
from app.core.config import settings
from typing import Dict, Any, Optional

# ──────────────────────────────────────────────
# Gemini 설정
# ──────────────────────────────────────────────

genai.configure(api_key=settings.google_api_key)
model = genai.GenerativeModel("models/gemini-2.5-flash")

# ──────────────────────────────────────────────
# 질문 처리 함수:
# prompt: 약 정보(통합)+ 사용자 입력 값
# ──────────────────────────────────────────────
def ask_gemini_with_image(user_input: str, image_obj: Optional[Image.Image] = None) -> str:
    # prompt 리스트를 사용하여 텍스트와 이미지를 함께 전달합니다.
    # 각 요소는 텍스트(string) 또는 이미지(PIL.Image.Image) 객체여야 합니다.
    contents = []

    # 약 정보 추가
    contents.append(f"""알약모양: 원형, 타원형, 장방형, 반원형, 마름모, 삼각형, 사각형, 오각형, 육각형, 팔각형, 기타

색상: 하양, 투명, 분홍, 빨강, 자주, 노랑, 주황, 연두, 초록, 청록,파랑, 남색, 보라, 갈색, 회색, 검정

마크: 있음, 없음

문자: str



알약이미지의 4가지 식별 정보를 저 예시 중에서 골라서 식별정보만 말해줘, 만약 문자열이 아닌 마크 이미지 같다면 마크: 있음, 아니면 마크: 없음, 문자 같으면 문자열을 인식해서 알려줘""")

    # 이미지가 제공되면 이미지 추가
    if image_obj:
        try:
            contents.append(image_obj)
        except FileNotFoundError:
            return f"[오류] 이미지 파일을 찾을 수 없습니다: {image_obj}"
        except Exception as e:
            return f"[오류] 이미지 로드 중 오류 발생: {str(e)}"

    # 사용자 질문 추가
    contents.append(f"질문:\n{user_input}")

    try:
        # generate_content에 리스트 형태의 contents 전달
        response = model.generate_content(contents)
        return response.text.strip()
    except GoogleAPIError as api_err:
        return f"[API 오류] Gemini API 호출 실패: {api_err.message}"
    except Exception as e:
        return f"[예외] 처리 중 오류 발생: {str(e)}"
