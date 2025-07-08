# DB 또는 인증 등의 공통 의존성 관리

# 📁 app/core/dependencies.py
from fastapi import Depends, Request
from app.db.mongodb import db

def get_db():
    return db