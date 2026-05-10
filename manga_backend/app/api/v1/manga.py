"""Manga catalog API – browse, search, detail, random."""
import math
from fastapi import APIRouter, Depends, Query
from sqlalchemy import func, or_, desc
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from sqlalchemy.orm import selectinload
from typing import Optional
import uuid

from app.core.database import get_db
from app.api.dependencies import get_current_user_optional
from app.models.models import (
    Manga, MangaStatistics, MangaAltTitle, MangaTag, Tag,
    Creator, CreatorRelationship, MangaRelated, Cover, User,
)
from app.schemas.manga import (
    MangaListItem, MangaDetailResponse, StatisticsOut,
    TagBrief, AltTitle, Description, LinkOut, CreatorOut, RelatedMangaOut,
)
from app.schemas.common import PaginatedResponse
from app.services.minio_service import minio_service

router = APIRouter()


# ── helpers ──────────────────────────────────────────────
MANGADEX_COVERS_CDN = "https://uploads.mangadex.org/covers"


async def _cover_url(manga_id: uuid.UUID, db: AsyncSession) -> str | None:
    """Get primary cover URL from Covers table → MinIO presigned URL → MangaDex CDN."""
    result = await db.execute(
        select(Cover)
        .where(Cover.manga_id == manga_id)
        .order_by(Cover.createdAt.desc())
        .limit(1)
    )
    cover = result.scalars().first()
    if not cover:
        return None

    url = cover.url
    if not url:
        # No URL stored but fileName exists → use MangaDex CDN
        if cover.fileName:
            return f"{MANGADEX_COVERS_CDN}/{manga_id}/{cover.fileName}"
        return None

    if url.startswith("covers/"):
        presigned = await minio_service.get_presigned_url(url)
        if presigned:
            return presigned
        # MinIO failed → fallback to MangaDex CDN
        if cover.fileName:
            return f"{MANGADEX_COVERS_CDN}/{manga_id}/{cover.fileName}"
        return None

    return url


async def _build_list_item(manga: Manga, db: AsyncSession) -> dict:
    stat_r = await db.execute(
        select(MangaStatistics).where(MangaStatistics.MangaId == manga.MangaId).limit(1)
    )
    stat = stat_r.scalars().first()
    cover = await _cover_url(manga.MangaId, db)
    return MangaListItem(
        MangaId=manga.MangaId,
        TitleEn=manga.TitleEn,
        Status=manga.Status,
        Year=manga.Year,
        ContentRating=manga.ContentRating,
        PublicationDemographic=manga.PublicationDemographic,
        cover_url=cover,
        stats=StatisticsOut(
            Follows=stat.Follows if stat else 0,
            AverageRating=stat.AverageRating if stat else 0,
            BayesianRating=stat.BayesianRating if stat else 0,
        ) if stat else None,
    ).model_dump()


# ── LIST MANGAS ──────────────────────────────────────────
@router.get("/")
async def list_mangas(
    page: int = Query(1, ge=1),
    limit: int = Query(20, ge=1, le=100),
    sort: str = Query("follows_desc"),
    status: Optional[str] = None,
    content_rating: Optional[str] = None,
    demographic: Optional[str] = None,
    year: Optional[int] = None,
    db: AsyncSession = Depends(get_db),
):
    query = select(Manga).outerjoin(MangaStatistics)

    if status:
        query = query.where(Manga.Status == status)
    if content_rating:
        query = query.where(Manga.ContentRating == content_rating)
    if demographic:
        query = query.where(Manga.PublicationDemographic == demographic)
    if year:
        query = query.where(Manga.Year == year)

    # Sorting
    if sort == "follows_desc":
        query = query.order_by(desc(MangaStatistics.Follows))
    elif sort == "rating_desc":
        query = query.order_by(desc(MangaStatistics.AverageRating))
    elif sort == "title_asc":
        query = query.order_by(Manga.TitleEn.asc())
    elif sort == "year_desc":
        query = query.order_by(desc(Manga.Year))
    elif sort == "recent":
        query = query.order_by(desc(Manga.UpdatedAt))
    else:
        query = query.order_by(desc(MangaStatistics.Follows))

    # Count
    count_q = select(func.count()).select_from(query.subquery())
    total = (await db.execute(count_q)).scalar() or 0

    # Paginate
    result = await db.execute(query.offset((page - 1) * limit).limit(limit))
    mangas = result.scalars().unique().all()

    items = []
    for m in mangas:
        items.append(await _build_list_item(m, db))

    return PaginatedResponse(
        items=items, page=page, per_page=limit, total=total,
        total_pages=math.ceil(total / limit) if limit else 0,
    )


# ── SEARCH ───────────────────────────────────────────────
@router.get("/search")
async def search_mangas(
    q: str = Query("", description="Search text"),  # Fixed: Biến tham số q thành không bắt buộc
    limit: int = Query(10, le=50),
    db: AsyncSession = Depends(get_db),
):
    # Fixed: Trả về list rỗng nếu frontend gọi nhầm hoặc không truyền q
    if not q or not q.strip():
        return []

    subq = (
        select(Manga.MangaId)
        .outerjoin(MangaAltTitle, Manga.MangaId == MangaAltTitle.MangaId)
        .where(or_(Manga.TitleEn.ilike(f"%{q}%"), MangaAltTitle.AltTitle.ilike(f"%{q}%")))
        .group_by(Manga.MangaId)
        .subquery()
    )
    query = (
        select(Manga)
        .join(subq, Manga.MangaId == subq.c.MangaId)
        .outerjoin(MangaStatistics)
        .order_by(desc(MangaStatistics.Follows))
        .limit(limit)
    )
    result = await db.execute(query)
    mangas = result.scalars().unique().all()

    items = []
    for m in mangas:
        items.append(await _build_list_item(m, db))
    return items


# ── ADVANCED SEARCH ──────────────────────────────────────
@router.get("/advanced-search")
async def advanced_search(
    q: Optional[str] = None,
    page: int = Query(1, ge=1),
    limit: int = Query(20, le=100),
    sort: str = "follows_desc",
    include_tags: Optional[str] = None,
    exclude_tags: Optional[str] = None,
    content_rating: Optional[str] = None,
    demographic: Optional[str] = None,
    status: Optional[str] = None,
    year_from: Optional[int] = None,
    year_to: Optional[int] = None,
    original_lang: Optional[str] = None,
    db: AsyncSession = Depends(get_db),
):
    query = select(Manga).outerjoin(MangaStatistics)

    if q:
        subq = (
            select(Manga.MangaId)
            .outerjoin(MangaAltTitle)
            .where(or_(Manga.TitleEn.ilike(f"%{q}%"), MangaAltTitle.AltTitle.ilike(f"%{q}%")))
            .group_by(Manga.MangaId)
            .subquery()
        )
        query = query.join(subq, Manga.MangaId == subq.c.MangaId)

    if include_tags:
        tag_ids = [t.strip() for t in include_tags.split(",") if t.strip()]
        if tag_ids:
            query = query.join(MangaTag).where(MangaTag.TagId.in_(tag_ids))

    if exclude_tags:
        ex_ids = [t.strip() for t in exclude_tags.split(",") if t.strip()]
        if ex_ids:
            excluded = select(MangaTag.MangaId).where(MangaTag.TagId.in_(ex_ids)).distinct().subquery()
            query = query.where(~Manga.MangaId.in_(select(excluded.c.MangaId)))

    if content_rating:
        query = query.where(Manga.ContentRating.in_(content_rating.split(",")))
    if demographic:
        query = query.where(Manga.PublicationDemographic.in_(demographic.split(",")))
    if status:
        query = query.where(Manga.Status.in_(status.split(",")))
    if original_lang:
        query = query.where(Manga.OriginalLanguage.in_(original_lang.split(",")))
    if year_from:
        query = query.where(Manga.Year >= year_from)
    if year_to:
        query = query.where(Manga.Year <= year_to)

    # Sort
    order_map = {
        "follows_desc": desc(MangaStatistics.Follows),
        "rating_desc": desc(MangaStatistics.AverageRating),
        "title_asc": Manga.TitleEn.asc(),
        "title_desc": Manga.TitleEn.desc(),
        "year_asc": Manga.Year.asc(),
        "year_desc": desc(Manga.Year),
        "recent": desc(Manga.UpdatedAt),
    }
    query = query.order_by(order_map.get(sort, desc(MangaStatistics.Follows)))

    count_q = select(func.count()).select_from(query.subquery())
    total = (await db.execute(count_q)).scalar() or 0
    result = await db.execute(query.offset((page - 1) * limit).limit(limit))
    mangas = result.scalars().unique().all()

    items = []
    for m in mangas:
        items.append(await _build_list_item(m, db))

    return PaginatedResponse(
        items=items, page=page, per_page=limit, total=total,
        total_pages=math.ceil(total / limit) if limit else 0,
    )


# ── RANDOM ───────────────────────────────────────────────
@router.get("/random")
async def random_manga(db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(Manga).order_by(func.newid()).limit(1))
    manga = result.scalars().first()
    if not manga:
        return {"message": "No manga found"}
    return await _build_list_item(manga, db)


# ── RECENTLY ADDED ───────────────────────────────────────
@router.get("/recently-added")
async def recently_added(
    page: int = Query(1, ge=1), limit: int = Query(20, le=100),
    db: AsyncSession = Depends(get_db),
):
    query = select(Manga).order_by(desc(Manga.CreatedAt))
    count_q = select(func.count()).select_from(query.subquery())
    total = (await db.execute(count_q)).scalar() or 0
    result = await db.execute(query.offset((page - 1) * limit).limit(limit))
    items = [await _build_list_item(m, db) for m in result.scalars().unique().all()]
    return PaginatedResponse(items=items, page=page, per_page=limit, total=total,
                             total_pages=math.ceil(total / limit) if limit else 0)


# ── LATEST UPDATES ───────────────────────────────────────
@router.get("/latest-updates")
async def latest_updates(
    page: int = Query(1, ge=1), limit: int = Query(20, le=100),
    in_my_lists: bool = Query(False),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user_optional),
):
    query = select(Manga)
    if in_my_lists and current_user:
        from app.models.models import MangaList, ListManga
        query = query.join(ListManga, Manga.MangaId == ListManga.MangaId)\
                     .join(MangaList, ListManga.ListId == MangaList.ListId)\
                     .where(MangaList.UserId == current_user.UserId)\
                     .distinct()

    query = query.order_by(desc(Manga.UpdatedAt))
    count_q = select(func.count()).select_from(query.subquery())
    total = (await db.execute(count_q)).scalar() or 0
    result = await db.execute(query.offset((page - 1) * limit).limit(limit))
    items = [await _build_list_item(m, db) for m in result.scalars().unique().all()]
    return PaginatedResponse(items=items, page=page, per_page=limit, total=total,
                             total_pages=math.ceil(total / limit) if limit else 0)


# ── MANGA DETAIL ─────────────────────────────────────────
@router.get("/{manga_id}")
async def manga_detail(manga_id: uuid.UUID, db: AsyncSession = Depends(get_db)):
    result = await db.execute(
        select(Manga)
        .options(
            selectinload(Manga.descriptions),
            selectinload(Manga.alt_titles),
            selectinload(Manga.links),
            selectinload(Manga.stats),
            selectinload(Manga.tags).selectinload(MangaTag.tag),
            selectinload(Manga.available_languages),
        )
        .where(Manga.MangaId == manga_id)
    )
    manga = result.scalars().first()
    if not manga:
        from fastapi import HTTPException
        raise HTTPException(status_code=404, detail="Manga not found")

    # Creators
    cr_result = await db.execute(
        select(Creator.CreatorId, Creator.Name, Creator.Type)
        .join(CreatorRelationship, Creator.CreatorId == CreatorRelationship.CreatorId)
        .where(CreatorRelationship.RelatedId == manga_id)
    )
    creators = [CreatorOut(id=c_id, name=n, role=r) for c_id, n, r in cr_result.all()]

    stat = manga.stats[0] if manga.stats else None
    cover = await _cover_url(manga_id, db)
    langs = sorted(set(l.LangCode for l in manga.available_languages if l.LangCode))

    return MangaDetailResponse(
        MangaId=manga.MangaId,
        Type=manga.Type,
        TitleEn=manga.TitleEn,
        Status=manga.Status,
        Year=manga.Year,
        ContentRating=manga.ContentRating,
        PublicationDemographic=manga.PublicationDemographic,
        OriginalLanguage=manga.OriginalLanguage,
        LastChapter=manga.LastChapter,
        LastVolume=manga.LastVolume,
        CreatedAt=manga.CreatedAt,
        UpdatedAt=manga.UpdatedAt,
        cover_url=cover,
        stats=StatisticsOut(
            Follows=stat.Follows if stat else 0,
            AverageRating=stat.AverageRating if stat else 0,
            BayesianRating=stat.BayesianRating if stat else 0,
        ) if stat else None,
        tags=[TagBrief(TagId=mt.tag.TagId, GroupName=mt.tag.GroupName, NameEn=mt.tag.NameEn) for mt in manga.tags if mt.tag],
        alt_titles=[AltTitle(LangCode=a.LangCode, AltTitle=a.AltTitle) for a in manga.alt_titles],
        descriptions=[Description(LangCode=d.LangCode, Description=d.Description) for d in manga.descriptions],
        links=[LinkOut(Provider=l.Provider, Url=l.Url) for l in manga.links],
        creators=creators,
        available_languages=langs,
    )


# ── RELATED ──────────────────────────────────────────────
@router.get("/{manga_id}/related")
async def get_related(manga_id: uuid.UUID, db: AsyncSession = Depends(get_db)):
    result = await db.execute(
        select(MangaRelated).where(MangaRelated.MangaId == manga_id)
    )
    rels = result.scalars().all()

    items = []
    for r in rels:
        # Skip non-manga relations (author, artist, cover_art)
        if r.Type not in ("manga",):
            continue
        title_r = await db.execute(select(Manga.TitleEn).where(Manga.MangaId == r.RelatedId))
        title = title_r.scalar()
        cover = await _cover_url(r.RelatedId, db)
        # Only show items that have at least a title or a cover
        if not title and not cover:
            continue
        items.append(RelatedMangaOut(
            RelatedId=r.RelatedId,
            relation_type=r.Type,
            related_label=r.Related,
            title=title if title else "Unknown Manga",
            cover_url=cover,
        ))
    return items