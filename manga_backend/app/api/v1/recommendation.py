"""Recommendation API – collaborative filtering + MangaDex recommendations."""
import uuid
from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.api.dependencies import get_current_user
from app.models.models import User
from app.services.collab_filter import collab_filter

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
):
    """Get similar manga from MangaDex recommendation API (proxy).
    Returns basic IDs. The frontend will bulk-enrich missing metadata
    directly from the browser to avoid backend IP rate limits.
    """
    try:
        async with httpx.AsyncClient(timeout=15) as client:
            r = await client.get(
                f"https://api.mangadex.org/manga/{manga_id}/recommendation",
                params={"limit": limit}
            )
            if r.status_code != 200:
                return {"recommendations": [], "source": "mangadex"}
            
            data = r.json()
            rec_items = data.get("data", [])
            items = []
            
            for rec in rec_items:
                score = rec.get("attributes", {}).get("score", 0)
                relationships = rec.get("relationships", [])
                for rel in relationships:
                    if rel.get("type") == "manga" and str(rel.get("id")) != str(manga_id):
                        rel_id = str(rel["id"])
                        items.append({
                            "manga_id": rel_id,
                            "score": round(score, 3),
                            "title": None,
                            "cover_url": None,
                            "status": None,
                        })
                        break
            
            return {"recommendations": items[:limit], "source": "mangadex"}
    except Exception as e:
        return {"recommendations": [], "source": "mangadex", "error": str(e)}
