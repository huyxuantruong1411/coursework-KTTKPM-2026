"""Recommendation API – collaborative filtering + MangaDex recommendations."""
import uuid
from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.api.dependencies import get_current_user
from app.models.models import User
from app.services.collab_filter import collab_filter

from sqlalchemy import select
from app.models.models import Manga

# Thêm import hàm _cover_url để lấy URL ảnh bìa chính xác
from app.api.v1.manga import _cover_url

import httpx

router = APIRouter()

MANGADEX_COVERS_CDN = "https://uploads.mangadex.org/covers"


@router.get("/for-me")
async def get_recommendations(
    top_n: int = 20,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Get personalized manga recommendations using collaborative filtering."""
    results = await collab_filter.recommend(
        user_id=current_user.UserId,
        db=db,
        top_n=top_n,
    )
    return {"recommendations": results, "count": len(results)}


@router.get("/manga/{manga_id}/similar")
async def get_similar_manga(
    manga_id: uuid.UUID,
    limit: int = Query(20, le=50),
    db: AsyncSession = Depends(get_db)  # Bổ sung db session
):
    """Get similar manga from MangaDex recommendation API (proxy) and filter by local DB."""
    
    HEADERS = {
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
        "Referer": "https://mangadex.org/"
    }

    try:
        async with httpx.AsyncClient(timeout=15, headers=HEADERS, follow_redirects=True) as client:
            r = await client.get(f"https://api.mangadex.org/manga/{manga_id}/recommendation")
            
            if r.status_code != 200:
                print(f"MangaDex Error {r.status_code}: {r.text}")
                return {"recommendations": [], "source": "mangadex"}
            
            data = r.json()
            rec_items = data.get("data", [])
            
            # 1. Trích xuất danh sách ID và Score từ MangaDex
            mangadex_scores = {}
            for rec in rec_items:
                score = rec.get("attributes", {}).get("score", 0)
                relationships = rec.get("relationships", [])
                for rel in relationships:
                    if rel.get("type") == "manga" and str(rel.get("id")) != str(manga_id):
                        rel_id = str(rel["id"])
                        mangadex_scores[rel_id] = round(score, 3)
                        break
            
        
            if not mangadex_scores:
                return {"recommendations": [], "source": "mangadex"}

            # 2. Truy vấn DB local để lấy thông tin các manga tồn tại
            valid_ids = [uuid.UUID(mid) for mid in mangadex_scores.keys()]
            
            stmt = select(Manga).where(Manga.MangaId.in_(valid_ids))
            result = await db.execute(stmt)
            db_mangas = result.scalars().all()

            # 3. Map dữ liệu từ DB vào response
            items = []
            for manga in db_mangas:
                mid_str = str(manga.MangaId)
                
                # SỬA LẠI: Dùng manga.TitleEn thay vì manga.Title
                # Có thể kết hợp fallback lấy TitleRomaji nếu TitleEn bị null
                manga_title = manga.TitleEn or "Unknown Title"

                # ĐÃ FIX: Gọi hàm helper để sinh cover_url chuẩn từ MinIO / MangaDex
                cover_url = await _cover_url(manga.MangaId, db)

                items.append({
                    "manga_id": mid_str,
                    "score": mangadex_scores.get(mid_str, 0),
                    "title": manga_title, 
                    "cover_url": cover_url, 
                    "status": manga.Status
                })
            
            # 4. Sắp xếp lại theo điểm số giảm dần
            items.sort(key=lambda x: x["score"], reverse=True)

            return {"recommendations": items[:limit], "source": "mangadex"}
            
    
    except Exception as e:
        # IN LỖI RA TERMINAL ĐỂ DỄ DEBUG
        import traceback
        traceback.print_exc()
        return {"recommendations": [], "source": "mangadex", "error": str(e)}