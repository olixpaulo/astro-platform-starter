from fastapi import APIRouter, HTTPException, Query, Request, status
from sqlalchemy import func, or_, select

from app.api.deps import CurrentUser, DbSession, RateLimitedUser, user_is_premium
from app.db.models import Favorite, Language, Translation, TranslationSource
from app.schemas.auth import MessageResponse
from app.schemas.translation import (
    DetectRequest,
    DetectResponse,
    HistoryPage,
    LanguageOut,
    SuggestRequest,
    SuggestResponse,
    TranslateRequest,
    TranslateResponse,
    TranslationHistoryItem,
)
from app.services import translation_service
from app.services.usage_service import check_daily_quota, log_action

router = APIRouter(prefix="/translations", tags=["translations"])


@router.get("/languages", response_model=list[LanguageOut])
async def list_languages(db: DbSession):
    result = await db.execute(select(Language).where(Language.is_active).order_by(Language.name))
    return result.scalars().all()


@router.post("", response_model=TranslateResponse)
async def translate(payload: TranslateRequest, user: RateLimitedUser, db: DbSession, request: Request):
    premium = await user_is_premium(db, user)
    await check_daily_quota(user.id, premium)

    result = await translation_service.translate_text(
        payload.text, payload.source_lang, payload.target_lang, payload.context
    )

    translation_id = None
    if payload.save_history:
        record = Translation(
            user_id=user.id,
            source_lang=payload.source_lang,
            target_lang=payload.target_lang,
            detected_lang=result.get("detected_lang"),
            source_text=payload.text,
            translated_text=result["translated_text"],
            source=TranslationSource.text,
            char_count=len(payload.text),
        )
        db.add(record)
        await db.commit()
        translation_id = record.id

    await log_action(db, "translation.text", user.id, detail=f"{payload.source_lang}->{payload.target_lang}", request=request)
    return TranslateResponse(
        id=translation_id,
        source_lang=payload.source_lang,
        detected_lang=result.get("detected_lang"),
        target_lang=payload.target_lang,
        source_text=payload.text,
        translated_text=result["translated_text"],
        alternatives=result.get("alternatives", []),
        cached=result.get("cached", False),
    )


@router.post("/detect", response_model=DetectResponse)
async def detect(payload: DetectRequest, user: RateLimitedUser):
    result = await translation_service.detect_language(payload.text)
    return DetectResponse(**result)


@router.post("/suggest", response_model=SuggestResponse)
async def suggest(payload: SuggestRequest, user: RateLimitedUser):
    suggestions = await translation_service.smart_suggestions(payload.text, payload.target_lang)
    return SuggestResponse(suggestions=suggestions)


@router.get("/history", response_model=HistoryPage)
async def history(
    user: CurrentUser,
    db: DbSession,
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    search: str | None = None,
    favorites_only: bool = False,
):
    query = select(Translation).where(Translation.user_id == user.id)
    count_query = select(func.count(Translation.id)).where(Translation.user_id == user.id)

    if search:
        pattern = f"%{search}%"
        condition = or_(Translation.source_text.ilike(pattern), Translation.translated_text.ilike(pattern))
        query = query.where(condition)
        count_query = count_query.where(condition)

    fav_result = await db.execute(select(Favorite.translation_id).where(Favorite.user_id == user.id))
    favorite_ids = {row[0] for row in fav_result}

    if favorites_only:
        if not favorite_ids:
            return HistoryPage(items=[], total=0, page=page, page_size=page_size)
        query = query.where(Translation.id.in_(favorite_ids))
        count_query = count_query.where(Translation.id.in_(favorite_ids))

    total = (await db.execute(count_query)).scalar_one()
    result = await db.execute(
        query.order_by(Translation.created_at.desc()).offset((page - 1) * page_size).limit(page_size)
    )
    items = [
        TranslationHistoryItem.model_validate(t).model_copy(update={"is_favorite": t.id in favorite_ids})
        for t in result.scalars()
    ]
    return HistoryPage(items=items, total=total, page=page, page_size=page_size)


@router.post("/{translation_id}/favorite", response_model=MessageResponse)
async def add_favorite(translation_id: str, user: CurrentUser, db: DbSession):
    translation = await db.get(Translation, translation_id)
    if translation is None or translation.user_id != user.id:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Tradução não encontrada")
    existing = await db.execute(
        select(Favorite).where(Favorite.user_id == user.id, Favorite.translation_id == translation_id)
    )
    if existing.scalar_one_or_none() is None:
        db.add(Favorite(user_id=user.id, translation_id=translation_id))
        await db.commit()
    return MessageResponse(message="Adicionado aos favoritos")


@router.delete("/{translation_id}/favorite", response_model=MessageResponse)
async def remove_favorite(translation_id: str, user: CurrentUser, db: DbSession):
    result = await db.execute(
        select(Favorite).where(Favorite.user_id == user.id, Favorite.translation_id == translation_id)
    )
    favorite = result.scalar_one_or_none()
    if favorite:
        await db.delete(favorite)
        await db.commit()
    return MessageResponse(message="Removido dos favoritos")


@router.delete("/{translation_id}", response_model=MessageResponse)
async def delete_translation(translation_id: str, user: CurrentUser, db: DbSession):
    translation = await db.get(Translation, translation_id)
    if translation is None or translation.user_id != user.id:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Tradução não encontrada")
    await db.delete(translation)
    await db.commit()
    return MessageResponse(message="Tradução eliminada")
