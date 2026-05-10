"""MDList API – CRUD lists, manage items, follow/unfollow, public search."""
import math, uuid
from datetime import datetime
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import desc, asc, func, or_
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select

from app.core.database import get_db
from app.api.dependencies import get_current_user
from app.models.models import MangaList, ListManga, ListFollower, Manga, Cover, User
from app.schemas.list import (
    ListCreate, ListUpdate, ListBrief, ListDetailResponse,
    ListMangaItem, PublicListItem,
)
from app.schemas.common import PaginatedResponse
from app.services.minio_service import minio_service

router = APIRouter()

MANGADEX_COVERS_CDN = "https://uploads.mangadex.org/covers"


async def _get_manga_cover(manga_id: uuid.UUID, db: AsyncSession) -> str | None:
    """Get cover URL for a manga (MinIO → MangaDex fallback)."""
    cover_r = await db.execute(
        select(Cover).where(Cover.manga_id == manga_id).order_by(Cover.createdAt.desc()).limit(1)
    )
    cover = cover_r.scalars().first()
    if not cover:
        return None
    if cover.url and cover.url.startswith("covers/"):
        try:
            return await minio_service.get_presigned_url(cover.url)
        except Exception:
            pass
    if cover.fileName:
        return f"{MANGADEX_COVERS_CDN}/{manga_id}/{cover.fileName}"
    return cover.url


async def _get_list_cover(list_id: uuid.UUID, db: AsyncSession) -> str | None:
    """Get cover from first manga in a list."""
    item_r = await db.execute(
        select(ListManga.MangaId).where(ListManga.ListId == list_id).order_by(ListManga.Position.asc()).limit(1)
    )
    manga_id = item_r.scalar()
    if manga_id:
        return await _get_manga_cover(manga_id, db)
    return None


# ── GET MY LISTS ─────────────────────────────────────────
@router.get("/")
async def get_lists(
    manga_id: uuid.UUID | None = None,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    my = await db.execute(
        select(MangaList).where(MangaList.UserId == current_user.UserId).order_by(desc(MangaList.UpdatedAt))
    )
    my_lists = my.scalars().all()

    followed = await db.execute(
        select(MangaList)
        .join(ListFollower, ListFollower.ListId == MangaList.ListId)
        .where(ListFollower.UserId == current_user.UserId)
        .order_by(desc(MangaList.UpdatedAt))
    )
    followed_lists = followed.scalars().all()

    async def brief(l: MangaList) -> dict:
        list_cover = await _get_list_cover(l.ListId, db)
        d = ListBrief(
            ListId=l.ListId, Name=l.Name, Slug=l.Slug,
            Description=l.Description, Visibility=l.Visibility,
            ItemCount=l.ItemCount or 0, FollowerCount=l.FollowerCount or 0,
            UpdatedAt=l.UpdatedAt, cover_url=list_cover,
        )
        if manga_id:
            r = await db.execute(
                select(ListManga).where(ListManga.ListId == l.ListId, ListManga.MangaId == manga_id)
            )
            d.contains = r.scalars().first() is not None
        return d.model_dump()

    return {
        "my_lists": [await brief(l) for l in my_lists],
        "followed_lists": [await brief(l) for l in followed_lists],
    }


# ── CREATE LIST ──────────────────────────────────────────
@router.post("/", status_code=201)
async def create_list(
    body: ListCreate, db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    if not body.Name:
        raise HTTPException(status_code=400, detail="Name is required")
    slug = f"{body.Name.strip().lower().replace(' ', '-')}-{str(uuid.uuid4())[:8]}"
    new_list = MangaList(
        UserId=current_user.UserId, Name=body.Name, Description=body.Description,
        Visibility=body.Visibility, Slug=slug,
        CreatedAt=datetime.utcnow(), UpdatedAt=datetime.utcnow(),
    )
    db.add(new_list)
    await db.commit()
    await db.refresh(new_list)
    return {"id": str(new_list.ListId), "slug": new_list.Slug}


# ── PUBLIC LISTS ─────────────────────────────────────────
@router.get("/public")
async def search_public_lists(
    page: int = Query(1, ge=1), limit: int = Query(12, ge=1, le=100),
    sort: str = "updated_desc", q: str = "",
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    base = select(MangaList).where(
        MangaList.Visibility == "public",
        MangaList.UserId != current_user.UserId,
    )
    if q.strip():
        like = f"%{q.strip()}%"
        base = base.where(or_(MangaList.Name.ilike(like), MangaList.Description.ilike(like)))

    if "_" in sort:
        field, direction = sort.rsplit("_", 1)
    else:
        field, direction = sort, "desc"
    order_fn = desc if direction == "desc" else asc
    sort_map = {
        "followers": MangaList.FollowerCount, "items": MangaList.ItemCount,
        "name": MangaList.Name, "updated": MangaList.UpdatedAt,
    }
    base = base.order_by(order_fn(sort_map.get(field, MangaList.UpdatedAt)))

    total = (await db.execute(select(func.count()).select_from(base.subquery()))).scalar() or 0
    result = await db.execute(base.offset((page - 1) * limit).limit(limit))
    lists = result.scalars().all()

    followed_r = await db.execute(
        select(ListFollower.ListId).where(ListFollower.UserId == current_user.UserId)
    )
    followed_ids = {r for (r,) in followed_r.all()}

    items = []
    for l in lists:
        user_r = await db.execute(select(User.Username).where(User.UserId == l.UserId))
        items.append(PublicListItem(
            ListId=l.ListId, Name=l.Name, Description=l.Description, Slug=l.Slug,
            Visibility=l.Visibility, ItemCount=l.ItemCount or 0,
            FollowerCount=l.FollowerCount or 0, UpdatedAt=l.UpdatedAt,
            owner_username=user_r.scalar(), owner_id=l.UserId,
            is_following=l.ListId in followed_ids,
        ).model_dump())

    return PaginatedResponse(
        items=items, page=page, per_page=limit, total=total,
        total_pages=math.ceil(total / limit) if limit else 0,
    )


# ── GET LIST DETAIL ──────────────────────────────────────
@router.get("/{list_id}")
async def get_list(list_id: uuid.UUID, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(MangaList).where(MangaList.ListId == list_id))
    l = result.scalars().first()
    if not l:
        raise HTTPException(status_code=404, detail="List not found")

    item_r = await db.execute(
        select(ListManga, Manga)
        .join(Manga, ListManga.MangaId == Manga.MangaId)
        .where(ListManga.ListId == list_id)
        .order_by(ListManga.Position.asc())
    )
    items = []
    first_cover = None
    for lm, m in item_r.all():
        cover = await _get_manga_cover(m.MangaId, db)
        if not first_cover:
            first_cover = cover
        items.append(ListMangaItem(
            manga_id=m.MangaId, title=m.TitleEn, position=lm.Position,
            cover_url=cover, status=m.Status, year=m.Year,
            content_rating=m.ContentRating,
        ).model_dump())

    user_r = await db.execute(select(User.Username).where(User.UserId == l.UserId))

    return ListDetailResponse(
        ListId=l.ListId, Name=l.Name, Description=l.Description, Slug=l.Slug,
        Visibility=l.Visibility, owner_id=l.UserId,
        owner_username=user_r.scalar(),
        ItemCount=l.ItemCount or 0, FollowerCount=l.FollowerCount or 0,
        items=items, cover_url=first_cover,
    )


# ── UPDATE / DELETE LIST ─────────────────────────────────
@router.put("/{list_id}")
async def update_list(
    list_id: uuid.UUID, body: ListUpdate,
    db: AsyncSession = Depends(get_db), current_user: User = Depends(get_current_user),
):
    result = await db.execute(select(MangaList).where(MangaList.ListId == list_id))
    l = result.scalars().first()
    if not l:
        raise HTTPException(status_code=404)
    if l.UserId != current_user.UserId:
        raise HTTPException(status_code=403)
    if body.Name is not None:
        l.Name = body.Name
    if body.Description is not None:
        l.Description = body.Description
    if body.Visibility is not None:
        l.Visibility = body.Visibility
    l.UpdatedAt = datetime.utcnow()
    await db.commit()
    return {"success": True}


@router.delete("/{list_id}", status_code=204)
async def delete_list(
    list_id: uuid.UUID,
    db: AsyncSession = Depends(get_db), current_user: User = Depends(get_current_user),
):
    result = await db.execute(select(MangaList).where(MangaList.ListId == list_id))
    l = result.scalars().first()
    if not l:
        raise HTTPException(status_code=404)
    if l.UserId != current_user.UserId:
        raise HTTPException(status_code=403)
    await db.delete(l)
    await db.commit()


# ── ADD / REMOVE MANGA ───────────────────────────────────
@router.post("/{list_id}/items", status_code=201)
async def add_item(
    list_id: uuid.UUID, manga_id: uuid.UUID = Query(...),
    db: AsyncSession = Depends(get_db), current_user: User = Depends(get_current_user),
):
    result = await db.execute(select(MangaList).where(MangaList.ListId == list_id))
    l = result.scalars().first()
    if not l or l.UserId != current_user.UserId:
        raise HTTPException(status_code=403)

    existing = await db.execute(
        select(ListManga).where(ListManga.ListId == list_id, ListManga.MangaId == manga_id)
    )
    if existing.scalars().first():
        return {"message": "already exists", "item_count": l.ItemCount or 0}

    max_pos = (await db.execute(
        select(func.max(ListManga.Position)).where(ListManga.ListId == list_id)
    )).scalar() or 0

    db.add(ListManga(ListId=list_id, MangaId=manga_id, AddedAt=datetime.utcnow(), Position=max_pos + 1))
    l.ItemCount = (l.ItemCount or 0) + 1
    l.UpdatedAt = datetime.utcnow()
    await db.commit()
    return {"success": True, "item_count": l.ItemCount}


@router.delete("/{list_id}/items/{manga_id}")
async def remove_item(
    list_id: uuid.UUID, manga_id: uuid.UUID,
    db: AsyncSession = Depends(get_db), current_user: User = Depends(get_current_user),
):
    result = await db.execute(select(MangaList).where(MangaList.ListId == list_id))
    l = result.scalars().first()
    if not l or l.UserId != current_user.UserId:
        raise HTTPException(status_code=403)

    item = await db.execute(
        select(ListManga).where(ListManga.ListId == list_id, ListManga.MangaId == manga_id)
    )
    lm = item.scalars().first()
    if not lm:
        raise HTTPException(status_code=404)
    await db.delete(lm)
    l.ItemCount = max(0, (l.ItemCount or 0) - 1)
    l.UpdatedAt = datetime.utcnow()
    await db.commit()
    return {"success": True, "item_count": l.ItemCount}


# ── FOLLOW / UNFOLLOW ────────────────────────────────────
@router.post("/{list_id}/follow")
async def follow_list(
    list_id: uuid.UUID,
    db: AsyncSession = Depends(get_db), current_user: User = Depends(get_current_user),
):
    result = await db.execute(select(MangaList).where(MangaList.ListId == list_id))
    l = result.scalars().first()
    if not l:
        raise HTTPException(status_code=404)

    existing = await db.execute(
        select(ListFollower).where(ListFollower.ListId == list_id, ListFollower.UserId == current_user.UserId)
    )
    if existing.scalars().first():
        return {"message": "already following"}

    db.add(ListFollower(ListId=list_id, UserId=current_user.UserId))
    l.FollowerCount = (l.FollowerCount or 0) + 1
    await db.commit()
    return {"success": True, "follower_count": l.FollowerCount}


@router.delete("/{list_id}/follow")
async def unfollow_list(
    list_id: uuid.UUID,
    db: AsyncSession = Depends(get_db), current_user: User = Depends(get_current_user),
):
    result = await db.execute(select(MangaList).where(MangaList.ListId == list_id))
    l = result.scalars().first()
    if not l:
        raise HTTPException(status_code=404)

    f = await db.execute(
        select(ListFollower).where(ListFollower.ListId == list_id, ListFollower.UserId == current_user.UserId)
    )
    follower = f.scalars().first()
    if not follower:
        return {"message": "not following"}
    await db.delete(follower)
    l.FollowerCount = max(0, (l.FollowerCount or 0) - 1)
    await db.commit()
    return {"success": True, "follower_count": l.FollowerCount}
