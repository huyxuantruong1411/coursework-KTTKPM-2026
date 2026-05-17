"""User analytics API – reading stats, genre distribution, activity data."""
import uuid
from datetime import datetime, timedelta
from fastapi import APIRouter, Depends
from sqlalchemy import func, desc, cast, Date
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select

from app.core.database import get_db
from app.api.dependencies import get_current_user
from app.models.models import (
    ReadingHistory, Chapter, Manga, Rating, MangaTag, Tag, User,
)

router = APIRouter()


@router.get("/user-stats")
async def get_user_stats(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Comprehensive reading statistics for the current user."""
    user_id = current_user.UserId

    # ── Total manga read (unique) ──
    total_manga = (await db.execute(
        select(func.count(func.distinct(ReadingHistory.MangaId)))
        .where(ReadingHistory.UserId == user_id)
    )).scalar() or 0

    # ── Total chapters read (unique) ──
    total_chapters = (await db.execute(
        select(func.count(func.distinct(ReadingHistory.ChapterId)))
        .where(ReadingHistory.UserId == user_id)
    )).scalar() or 0

    # ── Total history entries (reading sessions) ──
    total_sessions = (await db.execute(
        select(func.count()).select_from(
            select(ReadingHistory).where(ReadingHistory.UserId == user_id).subquery()
        )
    )).scalar() or 0

    # ── Total pages read (estimated) ──
    total_pages = (await db.execute(
        select(func.sum(ReadingHistory.LastPageRead))
        .where(ReadingHistory.UserId == user_id)
    )).scalar() or 0

    # ── Total ratings given ──
    total_ratings = (await db.execute(
        select(func.count()).select_from(
            select(Rating).where(Rating.UserId == user_id).subquery()
        )
    )).scalar() or 0

    # ── Average rating given ──
    avg_rating = (await db.execute(
        select(func.avg(Rating.Score)).where(Rating.UserId == user_id)
    )).scalar()
    avg_rating = round(float(avg_rating), 2) if avg_rating else None

    # ── Reading activity by day (last 30 days) ──
    now = datetime.utcnow()
    thirty_days_ago = now - timedelta(days=30)
    
    # In SQLAlchemy 2.0 with MSSQL, ordering by a labeled expression requires referring to the label.
    # We cast ReadAt to Date to strip the time portion.
    activity_r = await db.execute(
        select(
            cast(ReadingHistory.ReadAt, Date).label("day"),
            func.count().label("count"),
        )
        .where(ReadingHistory.UserId == user_id, ReadingHistory.ReadAt >= thirty_days_ago)
        .group_by(cast(ReadingHistory.ReadAt, Date))
        .order_by(desc(cast(ReadingHistory.ReadAt, Date)))
    )
    daily_activity = [{"date": str(row.day), "count": row.count} for row in activity_r.all()]
    daily_activity.reverse() # Show oldest first for chart

    # ── Genre/Theme distribution (top 10) ──
    # Join: ReadingHistory → Manga → MangaTag → Tag
    genre_r = await db.execute(
        select(Tag.NameEn, func.count().label("cnt"))
        .select_from(ReadingHistory)
        .join(Manga, ReadingHistory.MangaId == Manga.MangaId)
        .join(MangaTag, Manga.MangaId == MangaTag.MangaId)
        .join(Tag, MangaTag.TagId == Tag.TagId)
        .where(ReadingHistory.UserId == user_id, Tag.GroupName == "genre")
        .group_by(Tag.NameEn)
        .order_by(desc("cnt"))
        .limit(10)
    )
    genre_distribution = [{"name": row.NameEn, "count": row.cnt} for row in genre_r.all()]

    # ── Theme distribution (top 10) ──
    theme_r = await db.execute(
        select(Tag.NameEn, func.count().label("cnt"))
        .select_from(ReadingHistory)
        .join(Manga, ReadingHistory.MangaId == Manga.MangaId)
        .join(MangaTag, Manga.MangaId == MangaTag.MangaId)
        .join(Tag, MangaTag.TagId == Tag.TagId)
        .where(ReadingHistory.UserId == user_id, Tag.GroupName == "theme")
        .group_by(Tag.NameEn)
        .order_by(desc("cnt"))
        .limit(10)
    )
    theme_distribution = [{"name": row.NameEn, "count": row.cnt} for row in theme_r.all()]

    # ── Recent manga (last 5 unique) ──
    recent_r = await db.execute(
        select(ReadingHistory.MangaId, func.max(ReadingHistory.ReadAt).label("last_read"))
        .where(ReadingHistory.UserId == user_id)
        .group_by(ReadingHistory.MangaId)
        .order_by(desc("last_read"))
        .limit(5)
    )
    recent_manga_ids = [row.MangaId for row in recent_r.all()]
    recent_manga = []
    for mid in recent_manga_ids:
        m = await db.execute(select(Manga.TitleEn).where(Manga.MangaId == mid))
        recent_manga.append({"manga_id": str(mid), "title": m.scalar()})

    return {
        "total_manga": total_manga,
        "total_chapters": total_chapters,
        "total_sessions": total_sessions,
        "total_pages": total_pages,
        "total_ratings": total_ratings,
        "avg_rating": avg_rating,
        "daily_activity": daily_activity,
        "genre_distribution": genre_distribution,
        "theme_distribution": theme_distribution,
        "recent_manga": recent_manga,
    }
