"""Tradução contextual com OpenAI + cache Redis."""
import hashlib
import json

from openai import AsyncOpenAI

from app.core.config import get_settings
from app.core.redis import get_redis

CACHE_TTL_SECONDS = 60 * 60 * 24  # 24h

_client: AsyncOpenAI | None = None


def get_openai() -> AsyncOpenAI:
    global _client
    if _client is None:
        _client = AsyncOpenAI(api_key=get_settings().openai_api_key)
    return _client


def _cache_key(text: str, source: str, target: str, context: str | None) -> str:
    digest = hashlib.sha256(f"{source}|{target}|{context or ''}|{text}".encode()).hexdigest()
    return f"translation:{digest}"


async def translate_text(
    text: str,
    source_lang: str,
    target_lang: str,
    context: str | None = None,
) -> dict:
    """Traduz texto. Devolve dict com translated_text, detected_lang, alternatives, cached."""
    redis = get_redis()
    key = _cache_key(text, source_lang, target_lang, context)
    try:
        cached = await redis.get(key)
        if cached:
            result = json.loads(cached)
            result["cached"] = True
            return result
    except Exception:
        pass

    settings = get_settings()
    system_prompt = (
        "You are a professional translation engine. Translate the user's text "
        f"{'from ' + source_lang + ' ' if source_lang != 'auto' else ''}to {target_lang}. "
        "Preserve meaning, tone, formatting and placeholders. "
        "Respond ONLY with a JSON object: "
        '{"translated_text": str, "detected_lang": str (ISO 639-1 of the source), '
        '"alternatives": [up to 2 alternative translations for short texts]}'
    )
    if context:
        system_prompt += f"\nAdditional context for disambiguation: {context}"

    response = await get_openai().chat.completions.create(
        model=settings.openai_translation_model,
        messages=[
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": text},
        ],
        temperature=0.2,
        response_format={"type": "json_object"},
    )
    data = json.loads(response.choices[0].message.content or "{}")
    result = {
        "translated_text": data.get("translated_text", ""),
        "detected_lang": data.get("detected_lang"),
        "alternatives": data.get("alternatives", [])[:2],
        "cached": False,
    }

    try:
        await redis.set(key, json.dumps(result), ex=CACHE_TTL_SECONDS)
    except Exception:
        pass
    return result


async def detect_language(text: str) -> dict:
    settings = get_settings()
    response = await get_openai().chat.completions.create(
        model=settings.openai_translation_model,
        messages=[
            {
                "role": "system",
                "content": (
                    "Detect the language of the user's text. Respond ONLY with JSON: "
                    '{"language": "ISO 639-1 code", "confidence": float 0..1}'
                ),
            },
            {"role": "user", "content": text},
        ],
        temperature=0,
        response_format={"type": "json_object"},
    )
    data = json.loads(response.choices[0].message.content or "{}")
    return {"language": data.get("language", "und"), "confidence": float(data.get("confidence", 0.0))}


async def smart_suggestions(text: str, target_lang: str) -> list[str]:
    """Sugestões inteligentes: completações/reformulações úteis enquanto o utilizador escreve."""
    settings = get_settings()
    response = await get_openai().chat.completions.create(
        model=settings.openai_translation_model,
        messages=[
            {
                "role": "system",
                "content": (
                    "The user is typing text to translate to "
                    f"{target_lang}. Suggest up to 3 natural completions or clearer rephrasings "
                    'of their partial text, in the SAME language they are writing. JSON only: {"suggestions": [str]}'
                ),
            },
            {"role": "user", "content": text},
        ],
        temperature=0.7,
        response_format={"type": "json_object"},
    )
    data = json.loads(response.choices[0].message.content or "{}")
    return [s for s in data.get("suggestions", []) if isinstance(s, str)][:3]
