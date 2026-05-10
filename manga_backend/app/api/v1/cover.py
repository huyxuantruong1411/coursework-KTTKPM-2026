"""Cover API – get cover URLs for manga (MinIO with MangaDex fallback)."""
import uuid
from fastapi import APIRouter, Depends
from sqlalchemy import desc
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select

from app.core.database import get_db
from app.models.models import Cover
from app.services.minio_service import minio_service

router = APIRouter()

MANGADEX_COVERS_CDN = "https://uploads.mangadex.org/covers"


async def _resolve_cover_url(cover: Cover) -> str | None:
    """Resolve cover URL: try MinIO presigned URL first, then MangaDex CDN."""
    url = cover.url
    if not url:
        # Fallback: construct MangaDex cover URL from manga_id + fileName
        if cover.fileName:
            return f"{MANGADEX_COVERS_CDN}/{cover.manga_id}/{cover.fileName}"
        return None
    if url.startswith("covers/"):
        presigned = await minio_service.get_presigned_url(url)
        if presigned:
            return presigned
        # MinIO failed, try MangaDex fallback
        if cover.fileName:
            return f"{MANGADEX_COVERS_CDN}/{cover.manga_id}/{cover.fileName}"
    return url


@router.get("/manga/{manga_id}")
async def get_primary_cover(manga_id: uuid.UUID, db: AsyncSession = Depends(get_db)):
    """Get primary (latest) cover URL for a manga."""
    result = await db.execute(
        select(Cover)
        .where(Cover.manga_id == manga_id)
        .order_by(desc(Cover.createdAt))
        .limit(1)
    )
    cover = result.scalars().first()
    if not cover:
        return {"cover_url": None}

    url = await _resolve_cover_url(cover)

    return {
        "cover_id": str(cover.cover_id),
        "manga_id": str(cover.manga_id),
        "volume": cover.volume,
        "locale": cover.locale,
        "cover_url": url,
    }


@router.get("/manga/{manga_id}/all")
async def get_all_covers(manga_id: uuid.UUID, db: AsyncSession = Depends(get_db)):
    """Get all covers for a manga (art gallery data)."""
    result = await db.execute(
        select(Cover).where(Cover.manga_id == manga_id).order_by(Cover.volume)
    )
    covers = result.scalars().all()

    items = []
    for c in covers:
        url = await _resolve_cover_url(c)
        items.append({
            "cover_id": str(c.cover_id),
            "volume": c.volume,
            "locale": c.locale,
            "fileName": c.fileName,
            "cover_url": url,
        })
    return items
