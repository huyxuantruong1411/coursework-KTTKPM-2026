"""Rating API – rate manga (upsert), get my rating."""
import uuid
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select

from app.core.database import get_db
from app.api.dependencies import get_current_user
from app.models.models import Rating, Manga, User
from app.schemas.rating import RatingCreate, RatingResponse

router = APIRouter()


@router.post("/manga/{manga_id}/rate")
async def rate_manga(
    manga_id: uuid.UUID,
    body: RatingCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    if body.Score < 1 or body.Score > 10:
        raise HTTPException(status_code=400, detail="Score must be 1-10")

    manga_r = await db.execute(select(Manga).where(Manga.MangaId == manga_id))
    if not manga_r.scalars().first():
        raise HTTPException(status_code=404, detail="Manga not found")

    result = await db.execute(
        select(Rating).where(Rating.UserId == current_user.UserId, Rating.MangaId == manga_id)
    )
    existing = result.scalars().first()

    if existing:
        existing.Score = body.Score
        await db.commit()
        await db.refresh(existing)
        return RatingResponse.model_validate(existing)
    else:
        new_rating = Rating(UserId=current_user.UserId, MangaId=manga_id, Score=body.Score)
        db.add(new_rating)
        await db.commit()
        await db.refresh(new_rating)
        return RatingResponse.model_validate(new_rating)


@router.get("/manga/{manga_id}/my-rating")
async def get_my_rating(
    manga_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    result = await db.execute(
        select(Rating).where(Rating.UserId == current_user.UserId, Rating.MangaId == manga_id)
    )
    rating = result.scalars().first()
    if not rating:
        return {"score": None}
    return RatingResponse.model_validate(rating)
