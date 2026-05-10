import asyncio
from app.core.database import AsyncSessionLocal
from sqlalchemy import text

async def main():
    async with AsyncSessionLocal() as db:
        manga_id = 'aa6c76f7-5f5f-46b6-a800-911145f81b9b'
        res1 = await db.execute(text(f"SELECT * FROM CreatorRelationship WHERE RelatedId = '{manga_id}'"))
        with open("debug.txt", "w", encoding="utf-8") as f:
            f.write("CreatorRelations: " + repr(res1.all()) + "\n")
        res2 = await db.execute(text(f"SELECT * FROM MangaRelated WHERE MangaId = '{manga_id}'"))
        with open("debug.txt", "a", encoding="utf-8") as f:
            f.write("Related: " + repr(res2.all()) + "\n")

asyncio.run(main())
