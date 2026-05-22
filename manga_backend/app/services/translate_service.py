"""Translate manga page images — MangaTranslator AI pipeline.

Pipeline (per request):
  1. Download image from image_url
  2. MangaTranslator: YOLO bubble detection → LLM OCR+translation → Skia rendering
  3. Upload result to MinIO
  4. Return presigned URL (TTL 1 hour)

This module exposes a FastAPI router at ``POST /page`` that is mounted
by ``main.py`` at ``/api/v1/translate``.
"""

from __future__ import annotations

import hashlib
import logging

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel

router = APIRouter()
logger = logging.getLogger(__name__)

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


# ─── FastAPI endpoint ─────────────────────────────────────────────────────────

@router.post("/page", response_model=TranslatePageResponse)
async def translate_page(body: TranslatePageRequest):
    """Translate text in a manga page using MangaTranslator AI pipeline.

    - **image_url**: URL of the manga page image (MangaDex CDN or MinIO)
    - **target_lang**: target language code (default ``vi``)
    - **source_lang**: source language code (default ``auto`` – auto-detect)

    Returns **translated_url** – presigned URL of the translated image (TTL 1h).
    Results are cached in-memory to avoid reprocessing the same page.
    """
    target = _norm_lang(body.target_lang)
    source = _norm_lang(body.source_lang)

    # ── Cache check (fast path) ───────────────────────────────────────────
    cache_key = hashlib.sha256(
        f"{body.image_url}|{target}|mangatranslator_v2".encode()
    ).hexdigest()

    if cache_key in _cache:
        return TranslatePageResponse(
            translated_url=_cache[cache_key],
            source_lang=source,
            target_lang=target,
            cached=True,
        )

    # ── Call MangaTranslator AI pipeline ──────────────────────────────────
    try:
        from app.services.manga_translator_service import translate_manga_page

        presigned_url = await translate_manga_page(
            image_url=body.image_url,
            target_lang=target,
            source_lang=source,
        )
    except ValueError as exc:
        raise HTTPException(status_code=502, detail=str(exc))
    except Exception as exc:
        logger.exception("[translate] MangaTranslator pipeline failed: %s", exc)
        raise HTTPException(
            status_code=500,
            detail=f"Translation pipeline failed: {exc}",
        )

    # ── Update local cache too ────────────────────────────────────────────
    _cache[cache_key] = presigned_url

    return TranslatePageResponse(
        translated_url=presigned_url,
        source_lang=source,
        target_lang=target,
        cached=False,
    )