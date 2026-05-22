"""MangaTranslator AI pipeline wrapper for FastAPI.

Bridges the async FastAPI world with the synchronous MangaTranslator core.

Pipeline (per request):
  1. Download image from URL → save to temp file
  2. Build MangaTranslatorConfig (YOLO detection, Gemini LLM, Skia rendering)
  3. Call translate_and_render() in a thread pool (CPU-bound / GPU)
  4. Convert returned PIL Image → JPEG bytes
  5. Upload to MinIO
  6. Return presigned URL (TTL 1 hour)

Font: Wild-Words-Font (manga/comic style, regular weight, non-bold)
"""

from __future__ import annotations

import asyncio
import hashlib
import io
import logging
import os
import sys
import tempfile
import uuid
from pathlib import Path
from typing import Optional

import httpx

logger = logging.getLogger(__name__)

# ─── Add MangaTranslator to sys.path ─────────────────────────────────────────
MANGA_TRANSLATOR_DIR = Path(__file__).resolve().parent.parent.parent / "MangaTranslator"
if str(MANGA_TRANSLATOR_DIR) not in sys.path:
    sys.path.append(str(MANGA_TRANSLATOR_DIR))

# ─── In-memory cache: sha256(url|target_lang|v2) → presigned URL ─────────────
_cache: dict[str, str] = {}

# ─── Language code → MangaTranslator language name ────────────────────────────
_LANG_CODE_TO_NAME: dict[str, str] = {
    "vi":    "Vietnamese",
    "en":    "English",
    "zh-CN": "Simplified Chinese",
    "zh-TW": "Traditional Chinese",
    "ko":    "Korean",
    "ja":    "Japanese",
    "fr":    "French",
    "de":    "German",
    "es":    "Spanish",
    "pt":    "Portuguese",
    "th":    "Thai",
    "id":    "Indonesian",
}

_SOURCE_LANG_MAP: dict[str, str] = {
    "auto": "Japanese",   # Default assumption for manga
    "ja":   "Japanese",
    "ko":   "Korean",
    "zh":   "Chinese",
    "en":   "English",
}


# ─── Image download ──────────────────────────────────────────────────────────

async def _download_image_to_temp(url: str) -> Path:
    """Download image from URL, save to a temp file, return file path."""
    headers = {
        "User-Agent":  "Mozilla/5.0 (Windows NT 10.0; Win64; x64)",
        "Referer":     "https://mangadex.org/",
        "Accept":      "image/webp,image/avif,image/*,*/*;q=0.8",
    }
    async with httpx.AsyncClient(timeout=30, follow_redirects=True) as client:
        r = await client.get(url, headers=headers)
    if r.status_code != 200:
        raise ValueError(f"Cannot download image: HTTP {r.status_code}")

    # Determine extension from content-type
    ct = r.headers.get("content-type", "image/jpeg")
    ext = ".jpg"
    if "png" in ct:
        ext = ".png"
    elif "webp" in ct:
        ext = ".webp"

    tmp = tempfile.NamedTemporaryFile(suffix=ext, delete=False, prefix="mttranslate_")
    tmp.write(r.content)
    tmp.close()
    return Path(tmp.name)


# ─── Synchronous pipeline runner (runs in thread pool) ────────────────────────

def _run_translation_pipeline(
    image_path: Path,
    target_lang: str,
    source_lang: str,
) -> bytes:
    """Run MangaTranslator pipeline synchronously.

    This function is blocking and should be called via
    ``loop.run_in_executor()``.

    Returns JPEG bytes of the translated image.
    """
    import torch
    from app.core.config import settings

    from core.config import (
        CleaningConfig,
        DetectionConfig,
        MangaTranslatorConfig,
        OutputConfig,
        RenderingConfig,
        TranslationConfig,
    )
    from core.pipeline import translate_and_render
    from core.validation import autodetect_yolo_model_path

    models_dir = MANGA_TRANSLATOR_DIR / "models"
    models_dir.mkdir(parents=True, exist_ok=True)

    fonts_dir = MANGA_TRANSLATOR_DIR / "fonts" / "MTO-Comic-Clean"

    yolo_model_path = autodetect_yolo_model_path(models_dir, "yolo_1")

    output_lang = _LANG_CODE_TO_NAME.get(target_lang, "Vietnamese")
    input_lang = _SOURCE_LANG_MAP.get(source_lang) or _LANG_CODE_TO_NAME.get(source_lang) or "Japanese"

    # Prefer GPU (CUDA) when available, fallback to CPU
    device = torch.device(
        "cuda" if torch.cuda.is_available()
        else "cpu"
    )
    logger.info(
        "[manga_translator] Device=%s  input=%s  output=%s  model_dir=%s",
        device.type, input_lang, output_lang, models_dir,
    )

    config = MangaTranslatorConfig(
        yolo_model_path=str(yolo_model_path),
        device=device,
        verbose=False,
        detection=DetectionConfig(
            confidence=0.6,
            conjoined_confidence=0.35,
            seg_model="yolo",
            conjoined_detection=True,
        ),
        cleaning=CleaningConfig(
            thresholding_value=200,
            roi_shrink_px=5,
        ),
        translation=TranslationConfig(
            provider="Google",
            google_api_key=settings.GOOGLE_API_KEY or os.environ.get("GOOGLE_API_KEY", ""),
            model_name="gemini-flash-latest",
            input_language=input_lang,
            output_language=output_lang,
            translation_mode="one-step",
            reading_direction="rtl",
            send_full_page_context=True,
        ),
        rendering=RenderingConfig(
            font_dir=str(fonts_dir),
            max_font_size=16,
            min_font_size=8,
            line_spacing_mult=1.0,
        ),
        output=OutputConfig(
            jpeg_quality=90,
            output_format="jpeg",
        ),
    )

    # ── Run the heavy pipeline ────────────────────────────────────────────
    result_image = translate_and_render(image_path, config)

    # ── PIL Image → JPEG bytes ────────────────────────────────────────────
    if result_image.mode == "RGBA":
        result_image = result_image.convert("RGB")
    buf = io.BytesIO()
    result_image.save(buf, format="JPEG", quality=90)
    return buf.getvalue()


# ─── Public async API ─────────────────────────────────────────────────────────

async def translate_manga_page(
    image_url: str,
    target_lang: str = "vi",
    source_lang: str = "auto",
) -> str:
    """Translate a manga page using the MangaTranslator AI pipeline.

    Returns a presigned MinIO URL of the translated image (TTL 1 h).
    Results are cached in-memory to avoid reprocessing.
    """
    # ── Cache lookup ──────────────────────────────────────────────────────
    cache_key = hashlib.sha256(
        f"{image_url}|{target_lang}|mangatranslator_v2".encode()
    ).hexdigest()

    if cache_key in _cache:
        logger.info("[manga_translator] Cache HIT for %s", cache_key[:12])
        return _cache[cache_key]

    logger.info(
        "[manga_translator] Processing: lang=%s→%s  url=%s",
        source_lang, target_lang, image_url[:80],
    )

    # ── 1. Download image to temp file ────────────────────────────────────
    image_path = await _download_image_to_temp(image_url)

    try:
        # ── 2. Run pipeline in thread pool ────────────────────────────────
        loop = asyncio.get_event_loop()
        translated_bytes: bytes = await loop.run_in_executor(
            None,
            _run_translation_pipeline,
            image_path,
            target_lang,
            source_lang,
        )

        # ── 3. Upload to MinIO ────────────────────────────────────────────
        from app.services.minio_service import minio_service

        object_name = f"translated/{cache_key[:12]}-{uuid.uuid4().hex[:8]}.jpg"
        await minio_service.upload_bytes(
            translated_bytes, object_name, "image/jpeg"
        )
        presigned_url = await minio_service.get_presigned_url(
            object_name, expires=3600
        )

        # ── 4. Cache and return ───────────────────────────────────────────
        _cache[cache_key] = presigned_url
        logger.info("[manga_translator] Done → %s", object_name)
        return presigned_url

    finally:
        # Cleanup temp file
        try:
            image_path.unlink(missing_ok=True)
        except Exception:
            pass
