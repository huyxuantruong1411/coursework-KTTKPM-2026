import asyncio
import json
from fastapi import FastAPI
import redis

app = FastAPI()
# Kết nối qua mạng nội bộ Docker tới 'proto-redis'
redis_client = redis.Redis(host='proto-redis', port=6379, db=0, decode_responses=True)

MOCK_DB = {"chapter_data": "Đây là nội dung chương truyện. " * 100}

async def slow_db_query():
    await asyncio.sleep(0.5)
    return MOCK_DB

@app.get("/manga/1/no-cache")
async def get_no_cache():
    data = await slow_db_query()
    return data

@app.get("/manga/1/with-cache")
async def get_with_cache():
    cached_data = redis_client.get("manga_1")
    if cached_data:
        return json.loads(cached_data)
    
    data = await slow_db_query()
    redis_client.set("manga_1", json.dumps(data), ex=60)
    return data