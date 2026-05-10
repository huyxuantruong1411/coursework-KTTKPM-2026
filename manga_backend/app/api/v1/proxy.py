"""MangaDex Proxy – server-side image proxy to bypass hotlink protection."""
import hashlib
import time
from fastapi import APIRouter, Query, HTTPException
from fastapi.responses import StreamingResponse
import httpx

router = APIRouter()

# Simple in-memory LRU cache for MangaDex at-home server info (1 hour TTL)
_athome_cache: dict[str, tuple[dict, float]] = {}
_CACHE_TTL = 3600  # 1 hour


async def _get_athome_server(chapter_id: str) -> dict | None:
    """Get MangaDex at-home server info for a chapter, with caching."""
    now = time.time()
    if chapter_id in _athome_cache:
        data, ts = _athome_cache[chapter_id]
        if now - ts < _CACHE_TTL:
            return data

    try:
        async with httpx.AsyncClient(timeout=15) as client:
            r = await client.get(f"https://api.mangadex.org/at-home/server/{chapter_id}")
            if r.status_code != 200:
                return None
            data = r.json()
            _athome_cache[chapter_id] = (data, now)
            return data
    except Exception:
        return None


@router.get("/chapter-pages/{chapter_id}")
async def proxy_chapter_pages(chapter_id: str, quality: str = Query("data-saver")):
    """Return page URLs for a chapter via MangaDex at-home API.
    Quality: 'data' (full) or 'data-saver' (compressed)."""
    data = await _get_athome_server(chapter_id)
    if not data:
        raise HTTPException(status_code=502, detail="Failed to reach MangaDex at-home")

    host = data.get("baseUrl", "")
    chapter_hash = data.get("chapter", {}).get("hash", "")
    quality_key = "dataSaver" if quality == "data-saver" else "data"
    path_prefix = "data-saver" if quality == "data-saver" else "data"
    pages = data.get("chapter", {}).get(quality_key, [])

    urls = [f"{host}/{path_prefix}/{chapter_hash}/{page}" for page in pages]
    return {"pages": urls, "hash": chapter_hash, "quality": quality}


@router.get("/image")
async def proxy_image(url: str = Query(..., description="MangaDex image URL to proxy")):
    """Server-side proxy that fetches a MangaDex image and streams it to the client.
    Bypasses hotlink protection by making the request from the server."""
    allowed_hosts = ["uploads.mangadex.org", "cmdxd98sb0x3yprd.mangadex.network"]

    # Security: only proxy known MangaDex hosts
    from urllib.parse import urlparse
    parsed = urlparse(url)
    hostname = parsed.hostname or ""
    if not any(hostname.endswith(h) for h in allowed_hosts):
        # Allow any mangadex.network subdomain
        if not hostname.endswith(".mangadex.network") and hostname != "uploads.mangadex.org":
            raise HTTPException(status_code=403, detail="URL host not allowed for proxying")

    try:
        async with httpx.AsyncClient(timeout=30, follow_redirects=True) as client:
            r = await client.get(
                url,
                headers={
                    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
                    "Referer": "https://mangadex.org/",
                    "Accept": "image/webp,image/avif,image/*,*/*;q=0.8",
                },
            )
            if r.status_code != 200:
                raise HTTPException(status_code=r.status_code, detail="Upstream image fetch failed")

            content_type = r.headers.get("content-type", "image/jpeg")
            return StreamingResponse(
                iter([r.content]),
                media_type=content_type,
                headers={
                    "Cache-Control": "public, max-age=86400",
                    "X-Proxy": "manga-backend",
                },
            )
    except httpx.TimeoutException:
        raise HTTPException(status_code=504, detail="Upstream timeout")
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"Proxy error: {str(e)}")
