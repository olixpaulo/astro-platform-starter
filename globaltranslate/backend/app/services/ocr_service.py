"""OCR de imagens via modelo de visão da OpenAI, com bounding boxes para sobreposição."""
import base64
import json

from app.core.config import get_settings
from app.services.translation_service import get_openai, translate_text


async def extract_text_from_image(image_bytes: bytes, content_type: str) -> dict:
    """Extrai blocos de texto da imagem com posições normalizadas (0..1)."""
    settings = get_settings()
    b64 = base64.b64encode(image_bytes).decode()
    response = await get_openai().chat.completions.create(
        model=settings.openai_vision_model,
        messages=[
            {
                "role": "system",
                "content": (
                    "You are an OCR engine. Extract ALL visible text from the image. "
                    "Respond ONLY with JSON: "
                    '{"detected_lang": "ISO 639-1 or null", "blocks": ['
                    '{"text": str, "x": float, "y": float, "width": float, "height": float}'
                    "]} where x,y,width,height are normalized 0..1 bounding boxes "
                    "(top-left origin). Group text into coherent lines/paragraphs."
                ),
            },
            {
                "role": "user",
                "content": [
                    {"type": "image_url", "image_url": {"url": f"data:{content_type};base64,{b64}"}},
                ],
            },
        ],
        temperature=0,
        response_format={"type": "json_object"},
    )
    data = json.loads(response.choices[0].message.content or "{}")
    blocks = [b for b in data.get("blocks", []) if isinstance(b, dict) and b.get("text")]
    return {"detected_lang": data.get("detected_lang"), "blocks": blocks}


async def ocr_and_translate(image_bytes: bytes, content_type: str, target_lang: str) -> dict:
    ocr = await extract_text_from_image(image_bytes, content_type)
    blocks = ocr["blocks"]
    full_text = "\n".join(b["text"] for b in blocks)

    translated_full = None
    if full_text.strip():
        # Traduz os blocos em lote (separador estável) para manter o mapeamento posição→tradução
        separator = "\n<<<BLOCK>>>\n"
        result = await translate_text(separator.join(b["text"] for b in blocks), "auto", target_lang)
        translated_parts = result["translated_text"].split("<<<BLOCK>>>")
        for block, translated in zip(blocks, translated_parts):
            block["translated_text"] = translated.strip()
        translated_full = "\n".join(b.get("translated_text", "") for b in blocks)
        if not ocr["detected_lang"]:
            ocr["detected_lang"] = result.get("detected_lang")

    return {
        "detected_lang": ocr["detected_lang"],
        "full_text": full_text,
        "translated_text": translated_full,
        "blocks": blocks,
    }
