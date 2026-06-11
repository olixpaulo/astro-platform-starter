from pydantic import BaseModel, Field


class TTSRequest(BaseModel):
    text: str = Field(min_length=1, max_length=4_000)
    language: str = Field(default="en", max_length=10)
    voice_gender: str = Field(default="female", pattern="^(male|female)$")
    speed: float = Field(default=1.0, ge=0.25, le=4.0)
    premium_voice: bool = False


class STTResponse(BaseModel):
    text: str
    language: str | None


class VoiceTranslateResponse(BaseModel):
    recognized_text: str
    detected_lang: str | None
    translated_text: str
    target_lang: str
