"""Tag API."""
from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from collections import defaultdict

from app.core.database import get_db
from app.models.models import Tag
from app.schemas.tag import TagResponse, TagGroup

router = APIRouter()


@router.get("/")
async def list_tags(db: AsyncSession = Depends(get_db)):
    """List all tags grouped by GroupName."""
    result = await db.execute(select(Tag).order_by(Tag.GroupName, Tag.NameEn))
    tags = result.scalars().all()

    groups: dict[str, list] = defaultdict(list)
    for t in tags:
        groups[t.GroupName or "other"].append(
            TagResponse(TagId=t.TagId, GroupName=t.GroupName, NameEn=t.NameEn).model_dump()
        )

    return [TagGroup(group_name=k, tags=v).model_dump() for k, v in groups.items()]
