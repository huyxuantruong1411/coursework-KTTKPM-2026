"""Chapter API – list, detail with prev/next navigation, page URLs from MinIO or MangaDex fallback."""
import uuid
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import desc, text, case, cast, Float
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select

from app.core.database import get_db
from app.models.models import Chapter, Manga
from app.schemas import chapter
from app.schemas.chapter import ChapterResponse, ChapterNav
from app.services.minio_service import minio_service

import httpx

router = APIRouter()

# ── Natural sort expression for ChapterNumber (nvarchar) ──
# SQL Server: TRY_CAST returns NULL for non-numeric strings
_natural_asc = text("TRY_CAST(ChapterNumber AS FLOAT) ASC, ChapterNumber ASC")
_natural_desc = text("TRY_CAST(ChapterNumber AS FLOAT) DESC, ChapterNumber DESC")


async def _fetch_mangadex_pages(chapter_id: str) -> list[str]:
    """Fallback: fetch chapter page URLs from MangaDex at-home API.
    Uses data-saver images to avoid hotlink protection issues."""
    try:
        async with httpx.AsyncClient(timeout=15) as client:
            r = await client.get(f"https://api.mangadex.org/at-home/server/{chapter_id}")
            if r.status_code != 200:
                return []
            data = r.json()
            host = data.get("baseUrl", "")
            chapter_hash = data.get("chapter", {}).get("hash", "")
            # Prefer dataSaver to avoid hotlink protection
            pages = data.get("chapter", {}).get("dataSaver", [])
            if not pages:
                pages = data.get("chapter", {}).get("data", [])

            urls = []
            for page in pages:
                # Use data-saver path; add random param to bypass hotlink
                if pages == data.get("chapter", {}).get("dataSaver", []):
                    url = f"{host}/data-saver/{chapter_hash}/{page}"
                else:
                    url = f"{host}/data/{chapter_hash}/{page}?nocache=1"
                urls.append(url)
            return urls
    except Exception:
        return []


@router.get("/manga/{manga_id}/chapters")
async def list_chapters(
    manga_id: uuid.UUID,
    lang: str | None = None,
    sort: str = Query("asc", pattern="^(asc|desc)$"),
    db: AsyncSession = Depends(get_db),
):
    """List chapters with natural numeric sorting (1, 2, 3, ..., 10, 11)."""
    query = select(Chapter).where(
        Chapter.MangaId == manga_id,
        Chapter.IsUnavailable != True,
    )
    if lang:
        query = query.where(Chapter.TranslatedLang == lang)

    # Natural sort: TRY_CAST to FLOAT so "1" < "2" < "10"
    if sort == "desc":
        query = query.order_by(_natural_desc)
    else:
        query = query.order_by(_natural_asc)

    result = await db.execute(query)
    chapters = result.scalars().all()
    return [ChapterResponse.model_validate(c) for c in chapters]


@router.get("/manga/{manga_id}/languages")
async def available_languages(manga_id: uuid.UUID, db: AsyncSession = Depends(get_db)):
    """Get list of translated languages available for a manga."""
    result = await db.execute(
        select(Chapter.TranslatedLang)
        .where(Chapter.MangaId == manga_id, Chapter.IsUnavailable != True)
        .distinct()
    )
    langs = sorted([r for (r,) in result.all() if r])
    return langs


@router.get("/manga/{manga_id}/chapters/{chapter_id}")
async def chapter_detail(
    manga_id: uuid.UUID,
    chapter_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
):
    """Get chapter detail with prev/next navigation and page image URLs."""
    result = await db.execute(
        select(Chapter).where(Chapter.ChapterId == chapter_id, Chapter.MangaId == manga_id)
    )
    chapter = result.scalars().first()
    if not chapter:
        raise HTTPException(status_code=404, detail="Chapter not found")

    current_num = chapter.ChapterNumber
    lang = chapter.TranslatedLang

    # ── Previous chapter (natural sort) ──
    prev_q = (
        select(Chapter)
        .where(
            Chapter.MangaId == manga_id,
            Chapter.IsUnavailable != True,
            # Compare numerically: TRY_CAST both sides
            text(f"TRY_CAST(ChapterNumber AS FLOAT) < TRY_CAST(:cn AS FLOAT)")
        )
        .order_by(_natural_desc)
        .limit(1)
    ).params(cn=current_num)
    if lang:
        prev_q = prev_q.where(Chapter.TranslatedLang == lang)
    prev_r = await db.execute(prev_q)
    prev_chapter = prev_r.scalars().first()

    # ── Next chapter (natural sort) ──
    next_q = (
        select(Chapter)
        .where(
            Chapter.MangaId == manga_id,
            Chapter.IsUnavailable != True,
            text(f"TRY_CAST(ChapterNumber AS FLOAT) > TRY_CAST(:cn AS FLOAT)")
        )
        .order_by(_natural_asc)
        .limit(1)
    ).params(cn=current_num)
    if lang:
        next_q = next_q.where(Chapter.TranslatedLang == lang)
    next_r = await db.execute(next_q)
    next_chapter = next_r.scalars().first()

    # ── Page URLs: try MinIO first, fall back to MangaDex ──
    # Priority:
    #   1. MinIO cached pages
    #   2. MangaDex at-home server
    #   3. Local fallback placeholders

    page_urls = []

    # 1. Try MinIO
    try:
        page_urls = await minio_service.list_chapter_pages(str(chapter_id))
    except Exception as exc:
        import logging
        logging.exception("[chapter] MinIO page load failed: %s", exc)

    # 2. Try MangaDex fallback
    if not page_urls:
        try:
            page_urls = await _fetch_mangadex_pages(str(chapter_id))
        except Exception as exc:
            import logging
            logging.exception("[chapter] MangaDex fallback failed: %s", exc)

    # 3. FINAL FALLBACK FOR DEMO
    # Never return empty list.
    if not page_urls:
        fallback_page = (
            "https://placehold.co/1200x1700/111111/FFFFFF"
            "?text=Manga+Pages+Unavailable"
        )

        estimated_pages = chapter.Pages if chapter.Pages and chapter.Pages > 0 else 3

        page_urls = [fallback_page for _ in range(estimated_pages)]

    return ChapterNav(
        current=ChapterResponse.model_validate(chapter),
        prev_chapter=ChapterResponse.model_validate(prev_chapter) if prev_chapter else None,
        next_chapter=ChapterResponse.model_validate(next_chapter) if next_chapter else None,
        page_urls=page_urls,
    )