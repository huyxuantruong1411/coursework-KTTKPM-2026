import asyncio
from sqlalchemy import text
from app.core.database import engine

async def run_sql_file(file_path):
    print(f"Running {file_path}...")
    with open(file_path, 'r', encoding='utf-8') as f:
        # sqlcmd scripts might have GO, we need to split by GO and execute parts
        content = f.read()
        
    batches = [b.strip() for b in content.split('\nGO') if b.strip()]
    if not batches:
        # Fallback if no GO statements
        batches = [content]

    async with engine.begin() as conn:
        for batch in batches:
            if not batch: continue
            try:
                await conn.execute(text(batch))
            except Exception as e:
                print(f"Error executing batch in {file_path}:\n{batch[:100]}...\n{e}")
                
    print(f"Finished {file_path}")

async def main():
    await run_sql_file("scripts/001_user_profile.sql")
    await run_sql_file("scripts/002_chat_system.sql")
    print("All migrations completed.")

if __name__ == "__main__":
    asyncio.run(main())
