from fastapi import APIRouter, File, Form, HTTPException, Request, Response, UploadFile, status

from app.api.deps import DbSession, RateLimitedUser, user_is_premium
from app.db.models import Translation, TranslationSource
from app.schemas.voice import STTResponse, TTSRequest, VoiceTranslateResponse
from app.services import speech_service, translation_service
from app.services.usage_service import check_daily_quota, log_action

router = APIRouter(prefix="/voice", tags=["voice"])

MAX_AUDIO_BYTES = 25 * 1024 * 1024  # limite do Whisper


async def _read_audio(audio: UploadFile) -> bytes:
    data = await audio.read()
    if len(data) > MAX_AUDIO_BYTES:
        raise HTTPException(status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE, detail="Áudio demasiado grande (máx. 25MB)")
    if not data:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Ficheiro de áudio vazio")
    return data


@router.post("/tts")
async def text_to_speech(payload: TTSRequest, user: RateLimitedUser, db: DbSession):
    premium = await user_is_premium(db, user)
    if payload.premium_voice and not premium:
        raise HTTPException(status_code=status.HTTP_402_PAYMENT_REQUIRED, detail="Vozes premium requerem plano Premium")
    audio = await speech_service.text_to_speech(
        payload.text, payload.voice_gender, payload.speed, premium=payload.premium_voice
    )
    return Response(content=audio, media_type="audio/mpeg")


@router.post("/stt", response_model=STTResponse)
async def speech_to_text(
    user: RateLimitedUser,
    db: DbSession,
    audio: UploadFile = File(...),
    language: str = Form("auto"),
):
    data = await _read_audio(audio)
    result = await speech_service.speech_to_text(data, audio.filename or "audio.m4a", language)
    return STTResponse(**result)


@router.post("/translate", response_model=VoiceTranslateResponse)
async def voice_translate(
    request: Request,
    user: RateLimitedUser,
    db: DbSession,
    audio: UploadFile = File(...),
    source_lang: str = Form("auto"),
    target_lang: str = Form(...),
):
    """Voz → texto → tradução, num único pedido (usado também pelo modo conversação)."""
    premium = await user_is_premium(db, user)
    await check_daily_quota(user.id, premium)

    data = await _read_audio(audio)
    stt = await speech_service.speech_to_text(data, audio.filename or "audio.m4a", source_lang)
    if not stt["text"].strip():
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail="Não foi possível reconhecer fala no áudio")

    result = await translation_service.translate_text(stt["text"], source_lang, target_lang)

    db.add(
        Translation(
            user_id=user.id,
            source_lang=source_lang,
            target_lang=target_lang,
            detected_lang=result.get("detected_lang"),
            source_text=stt["text"],
            translated_text=result["translated_text"],
            source=TranslationSource.voice,
            char_count=len(stt["text"]),
        )
    )
    await db.commit()
    await log_action(db, "translation.voice", user.id, detail=f"{source_lang}->{target_lang}", request=request)

    return VoiceTranslateResponse(
        recognized_text=stt["text"],
        detected_lang=result.get("detected_lang"),
        translated_text=result["translated_text"],
        target_lang=target_lang,
    )
