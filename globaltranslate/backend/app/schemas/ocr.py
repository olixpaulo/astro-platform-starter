from pydantic import BaseModel


class OCRBlock(BaseModel):
    text: str
    translated_text: str | None = None
    # Bounding box normalizado (0..1) para sobreposição da tradução na imagem
    x: float = 0
    y: float = 0
    width: float = 0
    height: float = 0


class OCRResponse(BaseModel):
    detected_lang: str | None
    full_text: str
    translated_text: str | None
    blocks: list[OCRBlock] = []
