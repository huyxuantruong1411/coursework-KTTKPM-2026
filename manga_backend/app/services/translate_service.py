"""Translate manga page images – OCR + Google Translate + image overlay.

Pipeline (per request):
  1. Download image từ image_url (qua httpx, bypass hotlink)
  2. OCR bằng pytesseract (phát hiện vùng text)
  3. Dịch text qua deep-translator (Google backend, miễn phí, không cần API key)
  4. Vẽ text dịch đè lên ảnh gốc (Pillow)
  5. Upload kết quả lên MinIO
  6. Trả về presigned URL (TTL 1 giờ)

Cài dependencies trước khi dùng:
  pip install pytesseract Pillow deep-translator
  # Và cài Tesseract binary: https://github.com/UB-Mannheim/tesseract/wiki
  # Thêm vào PATH hoặc set pytesseract.pytesseract.tesseract_cmd = r"C:\\...\\tesseract.exe"
"""

from __future__ import annotations

import asyncio
import hashlib
import io
import uuid
from typing import TYPE_CHECKING, Optional

import httpx
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel

# ── PIL imports chỉ cho type checker (Pylance / mypy).
# Không chạy lúc runtime → server khởi động bình thường dù chưa cài Pillow.
if TYPE_CHECKING:
    from PIL import ImageDraw, ImageFont

router = APIRouter()

# ─── In-memory cache: sha256(url|target_lang) → presigned URL ────────────────
_cache: dict[str, str] = {}

# ─── Language code normalisation ─────────────────────────────────────────────
_LANG_MAP: dict[str, str] = {
    "zh-CN": "zh-CN",
    "zh-TW": "zh-TW",
    "auto":  "auto",
    "vi":    "vi",
    "en":    "en",
    "ko":    "ko",
    "ja":    "ja",
    "fr":    "fr",
    "de":    "de",
    "es":    "es",
    "pt":    "pt",
    "th":    "th",
    "id":    "id",
}


def _norm_lang(lang: str) -> str:
    return _LANG_MAP.get(lang, lang)


# ─── Pydantic schemas ─────────────────────────────────────────────────────────

class TranslatePageRequest(BaseModel):
    image_url: str
    target_lang: str = "vi"
    source_lang: str = "auto"


class TranslatePageResponse(BaseModel):
    translated_url: str
    source_lang: str
    target_lang: str
    cached: bool = False


# ─── Image download ───────────────────────────────────────────────────────────

async def _download_image(url: str) -> bytes:
    """Download ảnh từ URL (bypass MangaDex hotlink)."""
    headers = {
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64)",
        "Referer":    "https://mangadex.org/",
        "Accept":     "image/webp,image/avif,image/*,*/*;q=0.8",
    }
    async with httpx.AsyncClient(timeout=30, follow_redirects=True) as client:
        r = await client.get(url, headers=headers)
    if r.status_code != 200:
        raise HTTPException(
            status_code=502,
            detail=f"Không thể tải ảnh từ nguồn: HTTP {r.status_code}",
        )
    return r.content


# ─── OCR + translate + overlay (chạy trong thread pool) ──────────────────────

def _process_image(
    image_bytes: bytes,
    target_lang: str,
    source_lang: str,
) -> bytes:
    """OCR → dịch → vẽ đè → trả về bytes ảnh mới (JPEG).

    Hàm này chạy đồng bộ (blocking), gọi qua run_in_executor để không block
    event loop của FastAPI.
    """
    # ── Import kiểm tra runtime ──────────────────────────────────────────────
    try:
        import pytesseract
        from PIL import Image, ImageDraw, ImageFont
    except ImportError:
        raise HTTPException(
            status_code=501,
            detail=(
                "Thiếu thư viện: chạy  `pip install pytesseract Pillow`  "
                "và cài Tesseract binary từ https://github.com/UB-Mannheim/tesseract/wiki"
            ),
        )
    try:
        from deep_translator import GoogleTranslator
    except ImportError:
        raise HTTPException(
            status_code=501,
            detail="Thiếu thư viện: chạy  `pip install deep-translator`",
        )

    # ── Mở ảnh ──────────────────────────────────────────────────────────────
    img = Image.open(io.BytesIO(image_bytes)).convert("RGB")

    # ── OCR ─────────────────────────────────────────────────────────────────
    # PSM 11: Sparse text – phù hợp với manga (text nằm rải rác trong bubble)
    try:
        ocr_data = pytesseract.image_to_data(
            img,
            output_type=pytesseract.Output.DICT,
            config="--psm 11 --oem 3",
        )
    except pytesseract.TesseractNotFoundError:
        raise HTTPException(
            status_code=501,
            detail=(
                "Tesseract chưa được cài hoặc không tìm thấy trong PATH. "
                "Tải về tại: https://github.com/UB-Mannheim/tesseract/wiki"
            ),
        )
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"OCR thất bại: {exc}")

    # ── Gom text theo block ──────────────────────────────────────────────────
    blocks: dict[int, list[dict]] = {}
    n = len(ocr_data["text"])
    for i in range(n):
        word = (ocr_data["text"][i] or "").strip()
        if not word:
            continue
        conf = int(ocr_data["conf"][i] or 0)
        if conf < 45:
            continue
        block_num = ocr_data["block_num"][i]
        blocks.setdefault(block_num, []).append({
            "text": word,
            "x":    ocr_data["left"][i],
            "y":    ocr_data["top"][i],
            "w":    ocr_data["width"][i],
            "h":    ocr_data["height"][i],
        })

    if not blocks:
        return image_bytes

    # ── Dịch và vẽ đè ───────────────────────────────────────────────────────
    translator = GoogleTranslator(source="auto", target=_norm_lang(target_lang))
    draw = ImageDraw.Draw(img)

    for words in blocks.values():
        if not words:
            continue

        combined = " ".join(w["text"] for w in words).strip()
        if not combined or len(combined) < 2:
            continue

        x1 = min(w["x"] for w in words)
        y1 = min(w["y"] for w in words)
        x2 = max(w["x"] + w["w"] for w in words)
        y2 = max(w["y"] + w["h"] for w in words)
        bw  = max(x2 - x1, 1)
        bh  = max(y2 - y1, 1)

        try:
            translated: Optional[str] = translator.translate(combined)
        except Exception:
            translated = combined

        if not translated:
            continue

        padding = 2
        draw.rectangle(
            [x1 - padding, y1 - padding, x2 + padding, y2 + padding],
            fill=(255, 255, 255),
        )

        font_size = max(8, min(bh - 2, 18))
        font: ImageFont.ImageFont
        try:
            font = ImageFont.truetype("arial.ttf", font_size)
        except OSError:
            try:
                font = ImageFont.truetype(
                    r"C:\Windows\Fonts\arial.ttf", font_size
                )
            except OSError:
                font = ImageFont.load_default()

        _draw_wrapped_text(draw, translated, x1 + 1, y1 + 1, bw, font)

    out = io.BytesIO()
    img.save(out, format="JPEG", quality=88)
    return out.getvalue()


def _draw_wrapped_text(
    draw: ImageDraw.ImageDraw,
    text: str,
    x: int,
    y: int,
    max_width: int,
    font: ImageFont.ImageFont,
) -> None:
    """Vẽ text với tự động xuống dòng khi vượt max_width."""
    words = text.split()
    lines: list[str] = []
    current = ""
    for word in words:
        test = (current + " " + word).strip()
        try:
            bbox = font.getbbox(test)
            w = bbox[2] - bbox[0]
        except AttributeError:
            w = font.getlength(test)  # type: ignore[attr-defined]
        if w <= max_width:
            current = test
        else:
            if current:
                lines.append(current)
            current = word
    if current:
        lines.append(current)

    try:
        line_h = font.getbbox("A")[3] + 2
    except AttributeError:
        line_h = 12

    for i, line in enumerate(lines):
        draw.text((x, y + i * line_h), line, fill=(0, 0, 0), font=font)


# ─── FastAPI endpoint ─────────────────────────────────────────────────────────

@router.post("/page", response_model=TranslatePageResponse)
async def translate_page(body: TranslatePageRequest):
    """Dịch text trong một trang manga.

    - **image_url**: URL ảnh manga (từ MangaDex CDN hoặc MinIO)
    - **target_lang**: ngôn ngữ đích (mặc định `vi`)
    - **source_lang**: ngôn ngữ gốc (mặc định `auto` – tự phát hiện)

    Trả về **translated_url** – presigned URL của ảnh đã dịch (TTL 1h).
    Kết quả được cache trong bộ nhớ để tránh xử lý lại cùng một trang.
    """
    cache_key = hashlib.sha256(
        f"{body.image_url}|{body.target_lang}".encode()
    ).hexdigest()

    if cache_key in _cache:
        return TranslatePageResponse(
            translated_url=_cache[cache_key],
            source_lang=body.source_lang,
            target_lang=body.target_lang,
            cached=True,
        )

    image_bytes = await _download_image(body.image_url)

    loop = asyncio.get_event_loop()
    try:
        translated_bytes: bytes = await loop.run_in_executor(
            None,
            _process_image,
            image_bytes,
            body.target_lang,
            body.source_lang,
        )
    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Xử lý ảnh thất bại: {exc}")

    from app.services.minio_service import minio_service

    object_name = f"translated/{cache_key[:12]}-{uuid.uuid4().hex[:8]}.jpg"
    try:
        await minio_service.upload_bytes(translated_bytes, object_name, "image/jpeg")
        presigned_url = await minio_service.get_presigned_url(object_name, expires=3600)
    except Exception as exc:
        raise HTTPException(
            status_code=500,
            detail=f"Upload MinIO thất bại: {exc}",
        )

    _cache[cache_key] = presigned_url

    return TranslatePageResponse(
        translated_url=presigned_url,
        source_lang=body.source_lang,
        target_lang=body.target_lang,
        cached=False,
    )