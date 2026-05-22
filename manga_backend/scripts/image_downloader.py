"""
Image Downloader Worker
-----------------------
Standalone script that downloads cover images (and optionally chapter pages)
from MangaDex API and uploads them to MinIO.

Usage:
    python -m scripts.image_downloader --cover <manga_id>                 # Tải cover cho 1 manga
    python -m scripts.image_downloader --chapter <chapter_id>             # Tải toàn bộ trang của 1 chapter
    python -m scripts.image_downloader --chapter <id> --page-index 5      # Chỉ tải trang số 5 của 1 chapter
    python -m scripts.image_downloader --manga-chapters <manga_id>        # Tải toàn bộ chapter của 1 manga
    python -m scripts.image_downloader --all-covers                       # Batch tải cover cho tất cả manga trong DB
"""
import asyncio
import argparse
import sys
import os
import httpx
import uuid

# Ensure project root is on path
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app.core.config import settings
from app.core.database import AsyncSessionLocal
from app.services.minio_service import minio_service
from app.models.models import Manga, Cover, Chapter

from sqlalchemy.future import select
from sqlalchemy import func

MANGADEX_API = "https://api.mangadex.org"
MANGADEX_UPLOADS = "https://uploads.mangadex.org"

# Headers bắt buộc để bypass MangaDex Firewall
HEADERS = {
    "User-Agent": "MangaLibrary-Downloader/1.1 (Contact: admin@truongxuanhuy.id.vn)"
}

async def download_cover_for_manga(manga_id: str, db_session, client: httpx.AsyncClient):
    """Download primary cover from MangaDex → MinIO, update Covers table."""
    manga_id_lower = manga_id.lower()
    print(f"  [cover] Processing manga {manga_id_lower}...")

    # --- Retry logic ---
    for attempt in range(3):
        try:
            resp = await client.get(
                f"{MANGADEX_API}/cover",
                params={"manga[]": manga_id_lower, "limit": 1},
            )
            break
        except (httpx.ConnectError, httpx.TimeoutException) as e:
            if attempt == 2:
                print(f"    ✗ ConnectError sau 3 lần thử: {repr(e)}")
                return
            await asyncio.sleep(2 ** attempt)  # 1s, 2s backoff

    if resp.status_code != 200:
        print(f"    ✗ MangaDex API error: {resp.status_code}")
        return

    data = resp.json()
    covers = data.get("data", [])
    if not covers:
        print(f"    ✗ No cover found on MangaDex")
        return

    cover_item = covers[0]
    cover_id = cover_item["id"]
    attrs = cover_item.get("attributes", {})
    file_name = attrs.get("fileName")
    if not file_name:
        return

    # Check if already in DB with MinIO URL
    existing = await db_session.execute(
        select(Cover).where(Cover.cover_id == uuid.UUID(cover_id))
    )
    existing_cover = existing.scalars().first()
    if existing_cover and existing_cover.url and existing_cover.url.startswith("covers/"):
        print(f"    ✓ Already in MinIO: {existing_cover.url}")
        return

    # Download image (Áp dụng luôn retry cho tải ảnh nếu cần)
    for attempt in range(3):
        try:
            image_url = f"{MANGADEX_UPLOADS}/covers/{manga_id_lower}/{file_name}"
            img_resp = await client.get(image_url)
            break
        except (httpx.ConnectError, httpx.TimeoutException) as e:
            if attempt == 2:
                print(f"    ✗ Lỗi tải ảnh sau 3 lần thử: {repr(e)}")
                return
            await asyncio.sleep(2 ** attempt)

    if img_resp.status_code != 200:
        print(f"    ✗ Failed to download image: {img_resp.status_code}")
        return

    # Upload to MinIO
    ext = file_name.rsplit(".", 1)[-1] if "." in file_name else "jpg"
    minio_key = f"covers/{manga_id_lower}/{file_name}"
    content_type = f"image/{ext}" if ext in ("jpg", "jpeg", "png", "webp", "gif") else "image/jpeg"
    await minio_service.upload_bytes(img_resp.content, minio_key, content_type)

    # Upsert into Covers table
    if existing_cover:
        existing_cover.url = minio_key
        existing_cover.fileName = file_name
    else:
        new_cover = Cover(
            cover_id=uuid.UUID(cover_id),
            manga_id=uuid.UUID(manga_id),
            type=cover_item.get("type"),
            description=attrs.get("description"),
            volume=attrs.get("volume"),
            fileName=file_name,
            locale=attrs.get("locale"),
            version=attrs.get("version"),
            url=minio_key,
        )
        db_session.add(new_cover)

    await db_session.commit()
    print(f"    ✓ Uploaded to MinIO: {minio_key}")


async def download_chapter_pages(chapter_id: str, client: httpx.AsyncClient, page_index: int = None):
    """Download chapter pages from MangaDex at-home API → MinIO."""
    print(f"  [pages] Processing chapter {chapter_id}...")

    # Fetch at-home API to get page URLs
    try:
        resp = await client.get(f"{MANGADEX_API}/at-home/server/{chapter_id}")
        if resp.status_code != 200:
            print(f"    ✗ at-home API error: {resp.status_code}")
            return
    except Exception as e:
        print(f"    ✗ ConnectError: {repr(e)}")
        return

    data = resp.json()
    base_url = data.get("baseUrl", "")
    chapter_data = data.get("chapter", {})
    chapter_hash = chapter_data.get("hash", "")
    pages = chapter_data.get("data", [])

    if not pages:
        print(f"    ✗ No pages found")
        return

    # Handle exact page index download if specified
    if page_index is not None:
        if page_index < 1 or page_index > len(pages):
            print(f"    ✗ Page index {page_index} out of range (Chapter has {len(pages)} pages).")
            return
        pages_to_download = [(page_index - 1, pages[page_index - 1])]
    else:
        pages_to_download = enumerate(pages)

    for i, page_filename in pages_to_download:
        page_url = f"{base_url}/data/{chapter_hash}/{page_filename}"
        img_resp = None
        
        for attempt in range(3):
            try:
                img_resp = await client.get(page_url)
                if img_resp.status_code == 200:
                    break
                else:
                    print(f"    ✗ Lỗi tải page {i+1} (Thử lần {attempt+1}): HTTP {img_resp.status_code}")
            except Exception as e:
                print(f"    ✗ Lỗi mạng tải page {i+1} (Thử lần {attempt+1}): {repr(e)}")
            
            if attempt < 2:
                await asyncio.sleep(2 ** attempt)

        if not img_resp or img_resp.status_code != 200:
            print(f"    ✗ Bỏ qua page {i+1} do không thể tải ảnh.")
            continue

        ext = page_filename.rsplit(".", 1)[-1] if "." in page_filename else "jpg"
        minio_key = f"chapters/{chapter_id}/{i+1:04d}.{ext}"
        content_type = f"image/{ext}" if ext in ("jpg", "jpeg", "png", "webp") else "image/jpeg"
        await minio_service.upload_bytes(img_resp.content, minio_key, content_type)
        print(f"    ✓ Page {i+1}/{len(pages)} → {minio_key}")

    print(f"    ✓ Processed {1 if page_index else len(pages)} pages for chapter {chapter_id}")


async def download_all_chapters_for_manga(manga_id: str, client: httpx.AsyncClient):
    """Lấy danh sách các chapter của 1 manga và tải tất cả trang truyện về."""
    print(f"  [manga] Fetching all chapters for manga {manga_id}...")
    try:
        resp = await client.get(
            f"{MANGADEX_API}/manga/{manga_id}/feed",
            params={"limit": 500, "order[chapter]": "asc"}
        )
        if resp.status_code != 200:
            print(f"    ✗ Failed to fetch chapter list: HTTP {resp.status_code}")
            return
            
        data = resp.json()
        chapters = data.get("data", [])
        print(f"  Found {len(chapters)} chapters. Starting batch download...")
        
        for idx, ch in enumerate(chapters):
            ch_id = ch["id"]
            ch_num = ch.get("attributes", {}).get("chapter", "Unknown")
            print(f"\n  ➤ Downloading Chapter {ch_num} (ID: {ch_id}) [{idx+1}/{len(chapters)}]")
            await download_chapter_pages(ch_id, client)
            await asyncio.sleep(0.5) # Rate limiting
            
    except Exception as e:
        print(f"    ✗ Error fetching manga feed: {repr(e)}")


async def batch_all_covers(client: httpx.AsyncClient):
    """Download covers for ALL manga in DB that don't have a MinIO cover yet."""
    async with AsyncSessionLocal() as db:
        result = await db.execute(select(Manga.MangaId))
        manga_ids = [str(r) for (r,) in result.all()]
        print(f"Found {len(manga_ids)} manga in DB")

        for i, mid in enumerate(manga_ids):
            try:
                await download_cover_for_manga(mid, db, client)
            except Exception as e:
                # In rõ repr(e) để xem lỗi timeout hay socket
                print(f"    ✗ Error: {repr(e)}")
            
            # Tôn trọng API rate limit của MangaDex
            await asyncio.sleep(0.25)

            if (i + 1) % 10 == 0:
                print(f"  Progress: {i+1}/{len(manga_ids)}")


async def main():
    parser = argparse.ArgumentParser(description="MangaDex Image Downloader → MinIO")
    parser.add_argument("--cover", type=str, metavar="MANGA_ID", help="Download cover for a specific manga ID")
    parser.add_argument("--chapter", type=str, metavar="CHAPTER_ID", help="Download pages for a specific chapter ID")
    parser.add_argument("--page-index", type=int, metavar="PAGE_NUM", help="Specific page number (1-based) to download (use with --chapter)")
    parser.add_argument("--manga-chapters", type=str, metavar="MANGA_ID", help="Download all chapter pages for a specific manga ID")
    parser.add_argument("--all-covers", action="store_true", help="Batch download covers for all manga in local DB")
    args = parser.parse_args()

    await minio_service.ensure_bucket()

    # Mở 1 session client chung cho mọi tác vụ để tái sử dụng connection pool
    async with httpx.AsyncClient(timeout=30, headers=HEADERS, trust_env=True) as client:
        if args.cover:
            async with AsyncSessionLocal() as db:
                await download_cover_for_manga(args.cover, db, client)
        elif args.chapter:
            await download_chapter_pages(args.chapter, client, page_index=args.page_index)
        elif args.manga_chapters:
            await download_all_chapters_for_manga(args.manga_chapters, client)
        elif args.all_covers:
            await batch_all_covers(client)
        else:
            parser.print_help()


if __name__ == "__main__":
    asyncio.run(main())