from datetime import datetime

from pydantic import BaseModel, ConfigDict


class DocumentOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    filename: str
    content_type: str
    size_bytes: int
    source_lang: str
    target_lang: str
    status: str
    error: str | None
    created_at: datetime


class DocumentResult(DocumentOut):
    translated_text: str | None
