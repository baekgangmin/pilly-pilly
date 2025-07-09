from fastapi import FastAPI, UploadFile, File
from fastapi.responses import JSONResponse
from typing import List
from PIL import Image
import io
from ultralytics import YOLO

app = FastAPI()
model = YOLO('') // 모델 경로 입력

@app.post("/predict_multiple")
async def predict_multiple(files: List[UploadFile] = File(...)):
    print("받은 파일 개수:", len(files))
    all_results = []
    for file in files:
        print(f"파일 이름: {file.filename}")
        contents = await file.read()
        try:
            image = Image.open(io.BytesIO(contents)).convert("RGB")
        except Exception as e:
            print("❌ 이미지 열기 실패:", e)
            print("파일 이름:", file.filename)
            print("파일 크기:", len(contents))
            return JSONResponse(status_code=500, content={"error": f"이미지 열기 실패: {str(e)}"})

        try:
            results = model.predict(image, verbose=False)
            print(f"✅ 모델 추론 성공: {file.filename}")
        except Exception as e:
            print("❌ 모델 추론 실패:", e)
            return JSONResponse(status_code=500, content={"error": f"모델 추론 실패: {str(e)}"})

        for r in results:
            predictions = []
            if hasattr(r, "probs") and r.probs is not None:
                top5_classes = r.probs.top5
                top5_confidences = r.probs.top5conf

                for i in range(len(top5_classes)):
                    cls_idx = top5_classes[i]
                    confidence = top5_confidences[i].item() * 100
                    cls_name = r.names[cls_idx]
                    predictions.append({
                        "class": cls_name,
                        "confidence": round(confidence, 2)
                    })

                all_results.append({
                    "filename": file.filename,
                    "result": predictions
                })
            else:
                print(f"⚠️ 예측 확률 없음: {file.filename}")
                all_results.append({
                    "filename": file.filename,
                    "error": "No prediction probabilities found."
                })

    print("📦 최종 응답 준비:", all_results)
    return JSONResponse(content=all_results)