from fastapi import APIRouter, BackgroundTasks, File, Form, HTTPException, Request, UploadFile, status
from fastapi.responses import PlainTextResponse
from sqlalchemy import select

from app.api.deps import CurrentUser, DbSession, RateLimitedUser, user_is_premium
from app.core.config import get_settings
from app.db.models import Document, DocumentStatus
from app.db.session import async_session_factory
from app.schemas.auth import MessageResponse
from app.schemas.document import DocumentOut, DocumentResult
from app.services import document_service
from app.services.usage_service import log_action

router = APIRouter(prefix="/documents", tags=["documents"])


async def _process_document(document_id: str, file_bytes: bytes, content_type: str) -> None:
    """Processamento assíncrono: extração + tradução em blocos."""
    async with async_session_factory() as db:
        document = await db.get(Document, document_id)
        if document is None:
            return
        try:
            text = document_service.extract_text(file_bytes, content_type)
            if not text.strip():
                raise ValueError("Não foi encontrado texto no documento")
            document.translated_text = await document_service.translate_document_text(
                text, document.source_lang, document.target_lang
            )
            document.status = DocumentStatus.completed
        except Exception as exc:  # noqa: BLE001 — o erro é persistido para o utilizador
            document.status = DocumentStatus.failed
            document.error = str(exc)[:2000]
        await db.commit()


@router.post("", response_model=DocumentOut, status_code=status.HTTP_202_ACCEPTED)
async def upload_document(
    request: Request,
    background: BackgroundTasks,
    user: RateLimitedUser,
    db: DbSession,
    file: UploadFile = File(...),
    source_lang: str = Form("auto"),
    target_lang: str = Form(...),
):
    if file.content_type not in document_service.SUPPORTED_TYPES:
        raise HTTPException(
            status_code=status.HTTP_415_UNSUPPORTED_MEDIA_TYPE,
            detail="Formato não suportado. Use PDF, DOCX, TXT ou PPTX.",
        )
    data = await file.read()

    settings = get_settings()
    premium = await user_is_premium(db, user)
    max_mb = settings.max_document_size_premium_mb if premium else settings.max_document_size_free_mb
    if len(data) > max_mb * 1024 * 1024:
        raise HTTPException(
            status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
            detail=f"Documento excede o limite de {max_mb}MB do seu plano",
        )

    document = Document(
        user_id=user.id,
        filename=file.filename or "documento",
        content_type=file.content_type,
        size_bytes=len(data),
        source_lang=source_lang,
        target_lang=target_lang,
    )
    db.add(document)
    await db.commit()
    await db.refresh(document)

    background.add_task(_process_document, document.id, data, file.content_type)
    await log_action(db, "translation.document", user.id, detail=document.filename, request=request)
    return document


@router.get("", response_model=list[DocumentOut])
async def list_documents(user: CurrentUser, db: DbSession):
    result = await db.execute(
        select(Document).where(Document.user_id == user.id).order_by(Document.created_at.desc())
    )
    return result.scalars().all()


@router.get("/{document_id}", response_model=DocumentResult)
async def get_document(document_id: str, user: CurrentUser, db: DbSession):
    document = await db.get(Document, document_id)
    if document is None or document.user_id != user.id:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Documento não encontrado")
    return document


@router.get("/{document_id}/download", response_class=PlainTextResponse)
async def download_translation(document_id: str, user: CurrentUser, db: DbSession):
    document = await db.get(Document, document_id)
    if document is None or document.user_id != user.id:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Documento não encontrado")
    if document.status != DocumentStatus.completed or not document.translated_text:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Tradução ainda não disponível")
    return PlainTextResponse(
        document.translated_text,
        headers={"Content-Disposition": f'attachment; filename="{document.filename}.translated.txt"'},
    )


@router.delete("/{document_id}", response_model=MessageResponse)
async def delete_document(document_id: str, user: CurrentUser, db: DbSession):
    document = await db.get(Document, document_id)
    if document is None or document.user_id != user.id:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Documento não encontrado")
    await db.delete(document)
    await db.commit()
    return MessageResponse(message="Documento eliminado")
