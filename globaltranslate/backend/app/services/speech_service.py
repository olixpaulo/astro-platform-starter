"""Speech-to-Text (Whisper) e Text-to-Speech (OpenAI TTS)."""
import io

from app.core.config import get_settings
from app.services.translation_service import get_openai

# Mapeamento de género para vozes OpenAI
STANDARD_VOICES = {"female": "nova", "male": "onyx"}
PREMIUM_VOICES = {"female": "shimmer", "male": "echo"}


async def speech_to_text(audio_bytes: bytes, filename: str, language: str | None = None) -> dict:
    """Transcreve áudio. `language` (ISO 639-1) opcional melhora a precisão."""
    settings = get_settings()
    file = (filename, io.BytesIO(audio_bytes))
    kwargs: dict = {"model": settings.openai_stt_model, "file": file}
    if language and language != "auto":
        kwargs["language"] = language
    transcription = await get_openai().audio.transcriptions.create(**kwargs)
    return {"text": transcription.text, "language": language}


async def text_to_speech(
    text: str,
    voice_gender: str = "female",
    speed: float = 1.0,
    premium: bool = False,
) -> bytes:
    """Sintetiza voz e devolve áudio MP3."""
    settings = get_settings()
    voices = PREMIUM_VOICES if premium else STANDARD_VOICES
    voice = voices.get(voice_gender, voices["female"])
    model = "tts-1-hd" if premium else settings.openai_tts_model
    response = await get_openai().audio.speech.create(
        model=model,
        voice=voice,
        input=text,
        speed=speed,
        response_format="mp3",
    )
    return response.content
