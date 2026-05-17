"""FastAPI application entry point."""
from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.api.v1 import translate

from app.services.minio_service import minio_service

from fastapi import WebSocket, WebSocketDisconnect
from typing import List

@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup: ensure MinIO bucket exists
    try:
        await minio_service.ensure_bucket()
    except Exception as e:
        print(f"[startup] MinIO bucket check skipped: {e}")
    yield
    # Shutdown: cleanup if needed


app = FastAPI(
    title="MangaLibrary Core API",
    version="1.0.0",
    description="FastAPI backend for Manga reading platform – migrated from Flask monolith",
    lifespan=lifespan,
)

# CORS – cho phép frontend kết nối trên mọi Port (Cần thiết cho Flutter Web)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"], 
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ── Import & register routers ────────────────────────────
from app.api.v1 import auth, manga, chapter, comment, rating, history, cover, tag, admin, proxy
from app.api.v1 import analytics, recommendation, creators
from app.api.v1 import list as list_router
from app.api.v1 import translate as translate_router 

app.include_router(auth.router,    prefix="/api/v1/auth",     tags=["Authentication"])
app.include_router(manga.router,   prefix="/api/v1/mangas",   tags=["Manga Catalog"])
app.include_router(chapter.router, prefix="/api/v1",          tags=["Chapters"])
app.include_router(comment.router, prefix="/api/v1/comments", tags=["Comments"])
app.include_router(rating.router,  prefix="/api/v1/ratings",  tags=["Ratings"])
app.include_router(history.router, prefix="/api/v1/history",  tags=["Reading History"])
app.include_router(list_router.router, prefix="/api/v1/lists", tags=["Lists (MDLists)"])
app.include_router(tag.router,     prefix="/api/v1/tags",     tags=["Tags"])
app.include_router(cover.router,   prefix="/api/v1/covers",   tags=["Covers"])
app.include_router(admin.router,   prefix="/api/v1/admin",    tags=["Admin"])
app.include_router(proxy.router,   prefix="/api/v1/proxy",    tags=["MangaDex Proxy"])
app.include_router(analytics.router, prefix="/api/v1/analytics", tags=["Analytics"])
app.include_router(recommendation.router, prefix="/api/v1/recommendations", tags=["Recommendations"])
app.include_router(creators.router, prefix="/api/v1/creators", tags=["Creators"])
app.include_router(translate_router.router, prefix="/api/v1", tags=["Translation"])

from app.api.v1 import chat as chat_router, friends as friends_router
app.include_router(chat_router.router, prefix="/api/v1/chat", tags=["Chat"])
app.include_router(friends_router.router, prefix="/api/v1/friends", tags=["Friends"])


# ── Room-based WebSocket Chat with JWT Auth ──────────────
import json
import uuid as _uuid
from datetime import datetime as _dt
from app.core.security import decode_access_token
from app.models.models import ChatMessage, ChatRoomMember, UserPresence
from app.services.ws_manager import ws_manager


async def _authenticate_ws(token: str) -> str | None:
    """Validate JWT token and return user_id."""
    try:
        payload = decode_access_token(token)
        return payload.get("sub")
    except Exception:
        return None


@app.websocket("/ws/chat/{room_id}")
async def websocket_chat(websocket: WebSocket, room_id: str):
    """Room-based WebSocket endpoint with JWT authentication."""
    # Authenticate via query param
    token = websocket.query_params.get("token")
    if not token:
        await websocket.close(code=4001, reason="Missing token")
        return

    user_id = await _authenticate_ws(token)
    if not user_id:
        await websocket.close(code=4001, reason="Invalid token")
        return

    try:
        user_uuid = _uuid.UUID(user_id)
        room_uuid = _uuid.UUID(room_id)
    except ValueError:
        await websocket.close(code=4002, reason="Invalid room")
        return

    async with AsyncSessionLocal() as db:
        member_r = await db.execute(
            select(ChatRoomMember).where(
                ChatRoomMember.RoomId == room_uuid,
                ChatRoomMember.UserId == user_uuid,
            )
        )
        if not member_r.scalars().first():
            await websocket.close(code=4003, reason="Not a room member")
            return

    await ws_manager.connect(websocket, user_id, room_id)

    # Update presence
    async with AsyncSessionLocal() as db:
        presence = await db.execute(
            select(UserPresence).where(UserPresence.UserId == user_uuid)
        )
        p = presence.scalars().first()
        if p:
            p.IsOnline = True
            p.LastSeenAt = _dt.utcnow()
        else:
            db.add(UserPresence(UserId=user_uuid, IsOnline=True))
        await db.commit()

    try:
        while True:
            data = await websocket.receive_text()
            try:
                msg = json.loads(data)
            except json.JSONDecodeError:
                continue

            msg_type = msg.get("type")

            if msg_type == "message":
                content = msg.get("content", "").strip()
                if not content:
                    continue

                # Persist to DB
                async with AsyncSessionLocal() as db:
                    chat_msg = ChatMessage(
                        RoomId=room_uuid,
                        SenderId=user_uuid,
                        Content=content,
                        MessageType="text",
                    )
                    db.add(chat_msg)
                    await db.commit()
                    await db.refresh(chat_msg)

                    # Get sender info
                    sender_r = await db.execute(
                        select(User.Username, User.Avatar, User.DisplayName)
                        .where(User.UserId == user_uuid)
                    )
                    sender = sender_r.first()

                    broadcast = {
                        "type": "message",
                        "message_id": str(chat_msg.MessageId),
                        "room_id": room_id,
                        "sender_id": user_id,
                        "sender_username": sender.Username if sender else None,
                        "sender_avatar": sender.Avatar if sender else None,
                        "sender_display_name": sender.DisplayName if sender else None,
                        "content": content,
                        "message_type": chat_msg.MessageType,
                        "media_url": None,
                        "status": chat_msg.Status,
                        "created_at": chat_msg.CreatedAt.isoformat() if chat_msg.CreatedAt else None,
                    }

                await ws_manager.send_to_room(room_id, broadcast)

            elif msg_type == "typing":
                await ws_manager.send_to_room(room_id, {
                    "type": "typing",
                    "user_id": user_id,
                    "is_typing": msg.get("is_typing", False),
                }, exclude_user=user_id)

            elif msg_type == "read":
                await ws_manager.send_to_room(room_id, {
                    "type": "read",
                    "user_id": user_id,
                    "message_id": msg.get("message_id"),
                }, exclude_user=user_id)

    except WebSocketDisconnect:
        ws_manager.disconnect(user_id, room_id)
        # Update presence
        async with AsyncSessionLocal() as db:
            presence = await db.execute(
                select(UserPresence).where(UserPresence.UserId == user_uuid)
            )
            p = presence.scalars().first()
            if p:
                p.IsOnline = False
                p.LastSeenAt = _dt.utcnow()
                await db.commit()


# Keep backward compatibility: simple broadcast endpoint
class ConnectionManager:
    def __init__(self):
        self.active_connections: List[WebSocket] = []

    async def connect(self, websocket: WebSocket):
        await websocket.accept()
        self.active_connections.append(websocket)

    def disconnect(self, websocket: WebSocket):
        if websocket in self.active_connections:
            self.active_connections.remove(websocket)

    async def broadcast(self, message: str):
        for connection in self.active_connections:
            await connection.send_text(message)

manager = ConnectionManager()

@app.websocket("/ws/chat")
async def websocket_endpoint(websocket: WebSocket):
    """Legacy broadcast endpoint (backward compat)."""
    await manager.connect(websocket)
    try:
        while True:
            data = await websocket.receive_text()
            await manager.broadcast(data)
    except WebSocketDisconnect:
        manager.disconnect(websocket)

# ── Additional imports for WS auth ──
from sqlalchemy.future import select
from app.core.database import AsyncSessionLocal
from app.models.models import User

@app.get("/")
def root():
    return {
        "message": "MangaLibrary Core API",
        "docs": "/docs",
        "version": "2.0.0",
    }
