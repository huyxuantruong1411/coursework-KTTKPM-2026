import asyncio
from app.core.database import AsyncSessionLocal
from sqlalchemy import text

async def main():
    async with AsyncSessionLocal() as db:
        res1 = await db.execute(text('SELECT TOP 5 CreatorId, Type, Name FROM Creator'))
        with open("creator.txt", "w", encoding="utf-8") as f:
            f.write("Creator: " + repr(res1.all()) + "\n")
        res2 = await db.execute(text('SELECT TOP 5 CreatorId, RelatedType FROM CreatorRelationship'))
        with open("creator.txt", "a", encoding="utf-8") as f:
            f.write("CreatorRelationship: " + repr(res2.all()) + "\n")

asyncio.run(main())
