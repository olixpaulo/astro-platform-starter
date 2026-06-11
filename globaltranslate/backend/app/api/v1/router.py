from fastapi import APIRouter

from app.api.v1 import admin, auth, documents, ocr, subscriptions, translations, users, voice

api_router = APIRouter()
api_router.include_router(auth.router)
api_router.include_router(users.router)
api_router.include_router(translations.router)
api_router.include_router(voice.router)
api_router.include_router(ocr.router)
api_router.include_router(documents.router)
api_router.include_router(subscriptions.router)
api_router.include_router(admin.router)
