"""Reading history API – standard list, grouped by date, and continue reading."""
import math, uuid
from datetime import datetime, timedelta
from fastapi import APIRouter, Depends, Query
from sqlalchemy import desc, func, text
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select

from app.core.database import get_db
from app.api.dependencies import get_current_user
from app.models.models import ReadingHistory, Chapter, Manga, Cover, User
from app.schemas.history import HistoryCreate, HistoryResponse, HistoryGroup
from app.schemas.common import PaginatedResponse
from app.services.minio_service import minio_service

router = APIRouter()

MANGADEX_COVERS_CDN = "https://uploads.mangadex.org/covers"


async def _enrich_history(h: ReadingHistory, db: AsyncSession) -> dict:
    """Build a HistoryResponse dict enriched with manga title, chapter number, and cover URL."""
    manga_r = await db.execute(select(Manga.TitleEn).where(Manga.MangaId == h.MangaId))
    chap_r = await db.execute(select(Chapter.ChapterNumber).where(Chapter.ChapterId == h.ChapterId))

    # Get cover
    cover_url = None
    cover_r = await db.execute(
        select(Cover).where(Cover.manga_id == h.MangaId).order_by(Cover.createdAt.desc()).limit(1)
    )
    cover = cover_r.scalars().first()
    if cover:
        if cover.url and cover.url.startswith("covers/"):
            try:
                cover_url = await minio_service.get_presigned_url(cover.url)
            except Exception:
                pass
        if not cover_url and cover.fileName:
            cover_url = f"{MANGADEX_COVERS_CDN}/{h.MangaId}/{cover.fileName}"
        elif cover.url and not cover.url.startswith("covers/"):
            cover_url = cover.url

    return HistoryResponse(
        HistoryId=h.HistoryId, MangaId=h.MangaId, ChapterId=h.ChapterId,
        LastPageRead=h.LastPageRead, ReadAt=h.ReadAt,
        manga_title=manga_r.scalar(), chapter_number=chap_r.scalar(),
        cover_url=cover_url,
    ).model_dump()


@router.post("/", status_code=201)
async def record_history(
    body: HistoryCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    entry = ReadingHistory(
        UserId=current_user.UserId,
        MangaId=body.MangaId,
        ChapterId=body.ChapterId,
        LastPageRead=body.LastPageRead,
        ReadAt=datetime.utcnow(),
    )
    db.add(entry)
    await db.commit()
    return {"success": True}


@router.get("/")
async def get_history(
    page: int = Query(1, ge=1),
    limit: int = Query(20, le=100),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    base = select(ReadingHistory).where(ReadingHistory.UserId == current_user.UserId)
    total = (await db.execute(select(func.count()).select_from(base.subquery()))).scalar() or 0

    result = await db.execute(
        base.order_by(desc(ReadingHistory.ReadAt)).offset((page - 1) * limit).limit(limit)
    )
    entries = result.scalars().all()
    items = [await _enrich_history(h, db) for h in entries]

    return PaginatedResponse(
        items=items, page=page, per_page=limit, total=total,
        total_pages=math.ceil(total / limit) if limit else 0,
    )


@router.get("/grouped")
async def get_grouped_history(
    limit: int = Query(100, le=500),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Get reading history grouped by date buckets: Today, Yesterday, This Week, Earlier."""
    result = await db.execute(
        select(ReadingHistory)
        .where(ReadingHistory.UserId == current_user.UserId)
        .order_by(desc(ReadingHistory.ReadAt))
        .limit(limit)
    )
    entries = result.scalars().all()

    now = datetime.utcnow()
    today_start = now.replace(hour=0, minute=0, second=0, microsecond=0)
    yesterday_start = today_start - timedelta(days=1)
    week_start = today_start - timedelta(days=today_start.weekday())

    groups: dict[str, list] = {
        "Today": [],
        "Yesterday": [],
        "This Week": [],
        "Earlier": [],
    }

    for h in entries:
        enriched = await _enrich_history(h, db)
        read_at = h.ReadAt
        if not read_at:
            groups["Earlier"].append(enriched)
        elif read_at >= today_start:
            groups["Today"].append(enriched)
        elif read_at >= yesterday_start:
            groups["Yesterday"].append(enriched)
        elif read_at >= week_start:
            groups["This Week"].append(enriched)
        else:
            groups["Earlier"].append(enriched)

    # Return only non-empty groups
    return {
        "groups": [
            HistoryGroup(label=label, items=items).model_dump()
            for label, items in groups.items()
            if items
        ]
    }


@router.get("/manga/{manga_id}/continue")
async def continue_reading(
    manga_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Get most recent history entry for a manga → continue reading."""
    result = await db.execute(
        select(ReadingHistory)
        .where(ReadingHistory.UserId == current_user.UserId, ReadingHistory.MangaId == manga_id)
        .order_by(desc(ReadingHistory.ReadAt))
        .limit(1)
    )
    h = result.scalars().first()
    if h:
        return {"chapter_id": str(h.ChapterId), "last_page": h.LastPageRead}

    # Fallback: first available chapter (natural sort)
    first = await db.execute(
        select(Chapter)
        .where(Chapter.MangaId == manga_id, Chapter.IsUnavailable != True)
        .order_by(text("TRY_CAST(ChapterNumber AS FLOAT) ASC, ChapterNumber ASC"))
        .limit(1)
    )
    chap = first.scalars().first()
    if chap:
        return {"chapter_id": str(chap.ChapterId), "last_page": None}
    return {"chapter_id": None, "last_page": None}
