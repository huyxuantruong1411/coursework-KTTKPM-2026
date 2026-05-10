import uuid
import math
from fastapi import APIRouter, Depends, Query, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from sqlalchemy import func, desc

from app.core.database import get_db
from app.models.models import Creator, CreatorRelationship, Manga
from app.api.v1.manga import _build_list_item
from app.schemas.common import PaginatedResponse

router = APIRouter()

@router.get("/{creator_id}")
async def get_creator(
    creator_id: uuid.UUID,
    page: int = Query(1, ge=1),
    limit: int = Query(20, ge=1, le=100),
    db: AsyncSession = Depends(get_db)
):
    """Get creator profile and paginated list of their manga."""
    # 1. Get creator info
    creator_r = await db.execute(select(Creator).where(Creator.CreatorId == creator_id))
    creator = creator_r.scalars().first()
    
    if not creator:
        raise HTTPException(status_code=404, detail="Creator not found")
        
    # 2. Get their manga via CreatorRelationship
    manga_query = (
        select(Manga)
        .join(CreatorRelationship, Manga.MangaId == CreatorRelationship.RelatedId)
        .where(CreatorRelationship.CreatorId == creator_id)
        .order_by(desc(Manga.Year)) # Order by newest works
    )
    
    count_q = select(func.count()).select_from(manga_query.subquery())
    total = (await db.execute(count_q)).scalar() or 0
    
    result = await db.execute(manga_query.offset((page - 1) * limit).limit(limit))
    mangas = result.scalars().unique().all()
    
    items = []
    for m in mangas:
        items.append(await _build_list_item(m, db))
        
    return {
        "creator": {
            "id": str(creator.CreatorId),
            "name": creator.Name,
            "image_url": creator.ImageUrl,
            "biography": creator.BiographyEn or creator.BiographyJa or creator.BiographyPtBr,
            "created_at": creator.CreatedAt.isoformat() if creator.CreatedAt else None,
        },
        "mangas": PaginatedResponse(
            items=items, page=page, per_page=limit, total=total,
            total_pages=math.ceil(total / limit) if limit else 0,
        )
    }
