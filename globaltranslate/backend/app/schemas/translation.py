from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field


class TranslateRequest(BaseModel):
    text: str = Field(min_length=1, max_length=10_000)
    source_lang: str = Field(default="auto", max_length=10)
    target_lang: str = Field(max_length=10)
    context: str | None = Field(default=None, max_length=500, description="Contexto opcional para tradução contextual")
    save_history: bool = True


class TranslateResponse(BaseModel):
    id: str | None = None
    source_lang: str
    detected_lang: str | None
    target_lang: str
    source_text: str
    translated_text: str
    alternatives: list[str] = []
    cached: bool = False


class DetectRequest(BaseModel):
    text: str = Field(min_length=1, max_length=5_000)


class DetectResponse(BaseModel):
    language: str
    confidence: float


class SuggestRequest(BaseModel):
    text: str = Field(min_length=1, max_length=2_000)
    target_lang: str


class SuggestResponse(BaseModel):
    suggestions: list[str]


class LanguageOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    code: str
    name: str
    native_name: str
    supports_tts: bool
    supports_ocr: bool
    supports_offline: bool


class TranslationHistoryItem(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    source_lang: str
    target_lang: str
    detected_lang: str | None
    source_text: str
    translated_text: str
    source: str
    created_at: datetime
    is_favorite: bool = False


class HistoryPage(BaseModel):
    items: list[TranslationHistoryItem]
    total: int
    page: int
    page_size: int
