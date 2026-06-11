from fastapi import APIRouter, File, Form, HTTPException, Request, UploadFile, status

from app.api.deps import DbSession, RateLimitedUser, user_is_premium
from app.db.models import Translation, TranslationSource
from app.schemas.ocr import OCRResponse
from app.services import ocr_service
from app.services.usage_service import check_daily_quota, log_action

router = APIRouter(prefix="/ocr", tags=["ocr"])

ALLOWED_IMAGE_TYPES = {"image/jpeg", "image/png", "image/webp", "image/heic"}
MAX_IMAGE_BYTES = 10 * 1024 * 1024


@router.post("/translate", response_model=OCRResponse)
async def ocr_translate(
    request: Request,
    user: RateLimitedUser,
    db: DbSession,
    image: UploadFile = File(...),
    target_lang: str = Form(...),
):
    """Tradução por câmara: OCR + tradução com bounding boxes para sobreposição."""
    if image.content_type not in ALLOWED_IMAGE_TYPES:
        raise HTTPException(
            status_code=status.HTTP_415_UNSUPPORTED_MEDIA_TYPE,
            detail=f"Formato não suportado. Use: {', '.join(sorted(ALLOWED_IMAGE_TYPES))}",
        )
    data = await image.read()
    if len(data) > MAX_IMAGE_BYTES:
        raise HTTPException(status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE, detail="Imagem demasiado grande (máx. 10MB)")

    premium = await user_is_premium(db, user)
    await check_daily_quota(user.id, premium)

    result = await ocr_service.ocr_and_translate(data, image.content_type, target_lang)

    if result["full_text"].strip():
        db.add(
            Translation(
                user_id=user.id,
                source_lang="auto",
                target_lang=target_lang,
                detected_lang=result.get("detected_lang"),
                source_text=result["full_text"],
                translated_text=result.get("translated_text") or "",
                source=TranslationSource.camera,
                char_count=len(result["full_text"]),
            )
        )
        await db.commit()

    await log_action(db, "translation.ocr", user.id, detail=f"auto->{target_lang}", request=request)
    return OCRResponse(**result)
