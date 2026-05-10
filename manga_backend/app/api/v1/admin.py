"""Admin API – dashboard stats, manage users, manage comments/reports."""
import math, uuid
from datetime import datetime, timedelta
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import desc, func, distinct, cast, Date
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select

from app.core.database import get_db
from app.api.dependencies import require_admin
from app.models.models import (
    User, Comment, Report, Manga, ReadingHistory, MangaTag, Tag,
)

router = APIRouter()


@router.get("/dashboard")
async def admin_dashboard(
    start_date: str | None = None, end_date: str | None = None,
    db: AsyncSession = Depends(get_db), admin: User = Depends(require_admin),
):
    today = datetime.utcnow().date()
    window_start = today - timedelta(days=29)

    try:
        sd = datetime.strptime(start_date, "%Y-%m-%d").date() if start_date else window_start
    except Exception:
        sd = window_start
    try:
        ed = datetime.strptime(end_date, "%Y-%m-%d").date() if end_date else today
    except Exception:
        ed = today

    # New users (last 30 days)
    users_r = await db.execute(
        select(cast(User.CreatedAt, Date).label("d"), func.count())
        .where(User.CreatedAt >= datetime.combine(window_start, datetime.min.time()))
        .group_by(cast(User.CreatedAt, Date))
    )
    new_users = {str(d): c for d, c in users_r.all() if d}

    # Reading activity (last 30 days)
    reads_r = await db.execute(
        select(cast(ReadingHistory.ReadAt, Date).label("d"), func.count())
        .where(ReadingHistory.ReadAt >= datetime.combine(window_start, datetime.min.time()))
        .group_by(cast(ReadingHistory.ReadAt, Date))
    )
    reading_activity = {str(d): c for d, c in reads_r.all() if d}

    # Top manga by readers
    sd_dt = datetime.combine(sd, datetime.min.time())
    ed_dt = datetime.combine(ed, datetime.max.time())
    top_r = await db.execute(
        select(ReadingHistory.MangaId, func.count(distinct(ReadingHistory.UserId)).label("cnt"))
        .where(ReadingHistory.ReadAt.between(sd_dt, ed_dt))
        .group_by(ReadingHistory.MangaId)
        .order_by(desc("cnt"))
        .limit(20)
    )
    top_manga = []
    for mid, cnt in top_r.all():
        title_r = await db.execute(select(Manga.TitleEn).where(Manga.MangaId == mid))
        top_manga.append({"manga_id": str(mid), "title": title_r.scalar(), "readers": cnt})

    # Totals
    total_users = (await db.execute(select(func.count()).select_from(User))).scalar()
    total_manga = (await db.execute(select(func.count()).select_from(Manga))).scalar()
    pending_reports = (await db.execute(
        select(func.count()).select_from(Report).where(Report.Status == "pending")
    )).scalar()

    return {
        "new_users_by_date": new_users,
        "reading_activity_by_date": reading_activity,
        "top_manga": top_manga,
        "totals": {"users": total_users, "manga": total_manga, "pending_reports": pending_reports},
        "date_range": {"start": str(sd), "end": str(ed)},
    }


# ── MANAGE USERS ─────────────────────────────────────────
@router.get("/users")
async def list_users(
    page: int = Query(1, ge=1), limit: int = Query(20, le=100), q: str = "",
    db: AsyncSession = Depends(get_db), admin: User = Depends(require_admin),
):
    base = select(User)
    if q.strip():
        like = f"%{q.strip()}%"
        from sqlalchemy import or_
        base = base.where(or_(User.Username.ilike(like), User.Email.ilike(like)))
    total = (await db.execute(select(func.count()).select_from(base.subquery()))).scalar() or 0
    result = await db.execute(base.order_by(desc(User.CreatedAt)).offset((page - 1) * limit).limit(limit))
    users = result.scalars().all()

    from app.schemas.auth import UserResponse
    items = [UserResponse.model_validate(u).model_dump() for u in users]
    return {"items": items, "page": page, "per_page": limit, "total": total,
            "total_pages": math.ceil(total / limit) if limit else 0}


@router.post("/users/{user_id}/ban")
async def ban_user(user_id: uuid.UUID, db: AsyncSession = Depends(get_db), admin: User = Depends(require_admin)):
    result = await db.execute(select(User).where(User.UserId == user_id))
    user = result.scalars().first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    if user.UserId == admin.UserId:
        raise HTTPException(status_code=403, detail="Cannot ban yourself")
    user.IsLocked = True
    await db.commit()
    return {"success": True, "message": f"User {user.Username} banned"}


@router.post("/users/{user_id}/unban")
async def unban_user(user_id: uuid.UUID, db: AsyncSession = Depends(get_db), admin: User = Depends(require_admin)):
    result = await db.execute(select(User).where(User.UserId == user_id))
    user = result.scalars().first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    user.IsLocked = False
    await db.commit()
    return {"success": True, "message": f"User {user.Username} unbanned"}


# ── MANAGE COMMENTS ──────────────────────────────────────
@router.get("/comments")
async def list_reported_comments(
    page: int = Query(1, ge=1), limit: int = Query(20, le=100),
    status: str | None = None,
    db: AsyncSession = Depends(get_db), admin: User = Depends(require_admin),
):
    base = (
        select(Comment, User.Username, Manga.TitleEn, func.count(Report.ReportId).label("report_count"))
        .join(Report, Report.CommentId == Comment.CommentId)
        .join(User, Comment.UserId == User.UserId)
        .join(Manga, Comment.MangaId == Manga.MangaId)
    )
    if status:
        base = base.where(Report.Status == status)
    base = base.group_by(
        Comment.CommentId,
        Comment.UserId,
        Comment.MangaId,
        Comment.ChapterId,
        Comment.Content,
        Comment.CreatedAt,
        Comment.UpdatedAt,
        Comment.IsDeleted,
        Comment.IsSpoiler,
        Comment.LikeCount,
        Comment.DislikeCount,
        User.Username,
        Manga.TitleEn,
    ).order_by(desc(Comment.CreatedAt))

    total = (await db.execute(select(func.count()).select_from(base.subquery()))).scalar() or 0
    result = await db.execute(base.offset((page - 1) * limit).limit(limit))
    rows = result.all()

    items = []
    for comment, username, manga_title, report_count in rows:
        items.append({
            "comment_id": str(comment.CommentId),
            "content": comment.Content,
            "username": username,
            "manga_title": manga_title,
            "report_count": report_count,
            "created_at": comment.CreatedAt.isoformat() if comment.CreatedAt else None,
        })
    return {"items": items, "page": page, "per_page": limit, "total": total,
            "total_pages": math.ceil(total / limit) if limit else 0}


@router.post("/comments/{comment_id}/delete")
async def admin_delete_comment(
    comment_id: uuid.UUID,
    db: AsyncSession = Depends(get_db), admin: User = Depends(require_admin),
):
    result = await db.execute(select(Comment).where(Comment.CommentId == comment_id))
    c = result.scalars().first()
    if not c:
        raise HTTPException(status_code=404)
    c.IsDeleted = True
    c.UpdatedAt = datetime.utcnow()
    await db.execute(
        Report.__table__.update().where(Report.CommentId == comment_id).values(Status="resolved")
    )
    await db.commit()
    return {"success": True}


@router.post("/comments/{comment_id}/ignore")
async def admin_ignore_reports(
    comment_id: uuid.UUID,
    db: AsyncSession = Depends(get_db), admin: User = Depends(require_admin),
):
    await db.execute(
        Report.__table__.update().where(Report.CommentId == comment_id).values(Status="ignored")
    )
    await db.commit()
    return {"success": True}
