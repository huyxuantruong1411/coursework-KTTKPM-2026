"""Comment API – CRUD, like/dislike toggle, report."""
import uuid
from datetime import datetime
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import desc, func
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
import math

from app.core.database import get_db
from app.api.dependencies import get_current_user
from app.models.models import Comment, CommentReaction, Manga, Report, User
from app.schemas.comment import CommentCreate, CommentUpdate, CommentResponse, ReportCreate
from app.schemas.common import PaginatedResponse

router = APIRouter()


def _serialize(c: Comment, user: User | None = None) -> dict:
    return CommentResponse(
        CommentId=c.CommentId,
        UserId=c.UserId,
        MangaId=c.MangaId,
        Username=user.Username if user else None,
        Avatar=user.Avatar if user else None,
        Content=c.Content,
        IsSpoiler=c.IsSpoiler,
        LikeCount=c.LikeCount,
        DislikeCount=c.DislikeCount,
        IsDeleted=c.IsDeleted,
        CreatedAt=c.CreatedAt,
        UpdatedAt=c.UpdatedAt,
    ).model_dump()


# ── LIST COMMENTS FOR MANGA ─────────────────────────────
@router.get("/manga/{manga_id}/comments")
async def list_comments(
    manga_id: uuid.UUID,
    page: int = Query(1, ge=1),
    limit: int = Query(20, le=100),
    db: AsyncSession = Depends(get_db),
):
    base = select(Comment).where(Comment.MangaId == manga_id, Comment.IsDeleted != True)
    count_q = select(func.count()).select_from(base.subquery())
    total = (await db.execute(count_q)).scalar() or 0

    result = await db.execute(
        base.order_by(desc(Comment.CreatedAt)).offset((page - 1) * limit).limit(limit)
    )
    comments = result.scalars().all()

    items = []
    for c in comments:
        user_r = await db.execute(select(User).where(User.UserId == c.UserId))
        user = user_r.scalars().first()
        items.append(_serialize(c, user))

    return PaginatedResponse(
        items=items, page=page, per_page=limit, total=total,
        total_pages=math.ceil(total / limit) if limit else 0,
    )


# ── CREATE COMMENT ───────────────────────────────────────
@router.post("/manga/{manga_id}/comments", status_code=201)
async def create_comment(
    manga_id: uuid.UUID,
    body: CommentCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    if not body.Content or len(body.Content.strip()) < 5:
        raise HTTPException(status_code=400, detail="Comment too short (min 5 chars)")

    manga_r = await db.execute(select(Manga).where(Manga.MangaId == manga_id))
    if not manga_r.scalars().first():
        raise HTTPException(status_code=404, detail="Manga not found")

    new = Comment(
        UserId=current_user.UserId,
        MangaId=manga_id,
        ChapterId=body.ChapterId,
        Content=body.Content.strip(),
        IsSpoiler=body.IsSpoiler,
        CreatedAt=datetime.utcnow(),
        UpdatedAt=datetime.utcnow(),
    )
    db.add(new)
    await db.commit()
    await db.refresh(new)
    return {"success": True, "comment": _serialize(new, current_user)}


# ── EDIT COMMENT ─────────────────────────────────────────
@router.put("/{comment_id}")
async def edit_comment(
    comment_id: uuid.UUID,
    body: CommentUpdate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    result = await db.execute(select(Comment).where(Comment.CommentId == comment_id))
    c = result.scalars().first()
    if not c or c.IsDeleted:
        raise HTTPException(status_code=404, detail="Comment not found")
    if c.UserId != current_user.UserId:
        raise HTTPException(status_code=403, detail="Not the comment owner")
    if len(body.Content.strip()) < 5:
        raise HTTPException(status_code=400, detail="Comment too short")

    c.Content = body.Content.strip()
    c.UpdatedAt = datetime.utcnow()
    await db.commit()
    return {"success": True, "content": c.Content, "updated_at": c.UpdatedAt.isoformat()}


# ── DELETE COMMENT ───────────────────────────────────────
@router.delete("/{comment_id}")
async def delete_comment(
    comment_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    result = await db.execute(select(Comment).where(Comment.CommentId == comment_id))
    c = result.scalars().first()
    if not c:
        raise HTTPException(status_code=404, detail="Comment not found")
    if c.UserId != current_user.UserId:
        raise HTTPException(status_code=403, detail="Not the comment owner")

    c.IsDeleted = True
    c.UpdatedAt = datetime.utcnow()
    await db.commit()
    return {"success": True}


# ── LIKE / DISLIKE TOGGLE ────────────────────────────────
async def _toggle_reaction(comment_id: uuid.UUID, reaction_type: str, db: AsyncSession, user: User):
    result = await db.execute(select(Comment).where(Comment.CommentId == comment_id))
    c = result.scalars().first()
    if not c or c.IsDeleted:
        raise HTTPException(status_code=404, detail="Comment not found")

    opposite = "dislike" if reaction_type == "like" else "like"

    existing = await db.execute(
        select(CommentReaction).where(
            CommentReaction.CommentId == comment_id,
            CommentReaction.UserId == user.UserId,
            CommentReaction.Type == reaction_type,
        )
    )
    existing_r = existing.scalars().first()

    existing_opp = await db.execute(
        select(CommentReaction).where(
            CommentReaction.CommentId == comment_id,
            CommentReaction.UserId == user.UserId,
            CommentReaction.Type == opposite,
        )
    )
    existing_opp_r = existing_opp.scalars().first()

    if existing_r:
        await db.delete(existing_r)
        if reaction_type == "like":
            c.LikeCount = max(0, (c.LikeCount or 0) - 1)
        else:
            c.DislikeCount = max(0, (c.DislikeCount or 0) - 1)
    else:
        new_r = CommentReaction(CommentId=comment_id, UserId=user.UserId, Type=reaction_type)
        db.add(new_r)
        if reaction_type == "like":
            c.LikeCount = (c.LikeCount or 0) + 1
        else:
            c.DislikeCount = (c.DislikeCount or 0) + 1
        if existing_opp_r:
            await db.delete(existing_opp_r)
            if opposite == "like":
                c.LikeCount = max(0, (c.LikeCount or 0) - 1)
            else:
                c.DislikeCount = max(0, (c.DislikeCount or 0) - 1)

    await db.commit()
    return {"success": True, "like_count": c.LikeCount, "dislike_count": c.DislikeCount}


@router.post("/{comment_id}/like")
async def like_comment(comment_id: uuid.UUID, db: AsyncSession = Depends(get_db), user: User = Depends(get_current_user)):
    return await _toggle_reaction(comment_id, "like", db, user)


@router.post("/{comment_id}/dislike")
async def dislike_comment(comment_id: uuid.UUID, db: AsyncSession = Depends(get_db), user: User = Depends(get_current_user)):
    return await _toggle_reaction(comment_id, "dislike", db, user)


# ── REPORT ───────────────────────────────────────────────
@router.post("/{comment_id}/report", status_code=201)
async def report_comment(
    comment_id: uuid.UUID,
    body: ReportCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    result = await db.execute(select(Comment).where(Comment.CommentId == comment_id))
    if not result.scalars().first():
        raise HTTPException(status_code=404, detail="Comment not found")
    if not body.Reason.strip():
        raise HTTPException(status_code=400, detail="Reason is required")

    report = Report(
        UserId=current_user.UserId,
        CommentId=comment_id,
        Reason=body.Reason.strip(),
        Status="pending",
        CreatedAt=datetime.utcnow(),
    )
    db.add(report)
    await db.commit()
    return {"success": True, "message": "Report submitted"}