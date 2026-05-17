from fastapi import APIRouter
from pydantic import BaseModel, HttpUrl

from app.services.translate_service import translate_page

router = APIRouter()


class TranslatePageRequest(BaseModel):
    image_url: HttpUrl
    source_lang: str = "ja"
    target_lang: str = "en"


@router.post("/page")
async def translate_page_endpoint(payload: TranslatePageRequest):
    """
    Translate a manga page image safely.
    """

    try:
        image_url = str(payload.image_url)

        # ─────────────────────────────────────
        # Skip placeholder/fallback images
        # ─────────────────────────────────────
        if "placehold.co" in image_url:
            return {
                "success": False,
                "translated_image_url": image_url,
                "message": "Fallback placeholder images cannot be translated.",
                "fallback": True,
            }

        translated_url = await translate_page(
            image_url=image_url,
            source_lang=payload.source_lang,
            target_lang=payload.target_lang,
        )

        return {
            "success": True,
            "translated_image_url": translated_url,
        }

    except ValueError as exc:
        import logging

        logging.exception("[translate] Validation error: %s", exc)

        return {
            "success": False,
            "translated_image_url": str(payload.image_url),
            "message": str(exc),
        }

    except Exception as exc:
        import logging

        logging.exception("[translate] Unexpected error: %s", exc)

        return {
            "success": False,
            "translated_image_url": str(payload.image_url),
            "message": "Translation failed unexpectedly.",
        }