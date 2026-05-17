"""Shared WebSocket room manager for chat realtime events."""
import json

from fastapi import WebSocket


class RoomConnectionManager:
    """Manage WebSocket connections organized by room and user."""

    def __init__(self):
        self.rooms: dict[str, dict[str, WebSocket]] = {}
        self.user_connections: dict[str, WebSocket] = {}

    async def connect(self, websocket: WebSocket, user_id: str, room_id: str):
        await websocket.accept()
        self.rooms.setdefault(room_id, {})[user_id] = websocket
        self.user_connections[user_id] = websocket

    def disconnect(self, user_id: str, room_id: str):
        room = self.rooms.get(room_id)
        if room and user_id in room:
            del room[user_id]
            if not room:
                del self.rooms[room_id]
        if self.user_connections.get(user_id):
            del self.user_connections[user_id]

    async def send_to_room(
        self,
        room_id: str,
        message: dict,
        exclude_user: str | None = None,
    ):
        room = self.rooms.get(room_id)
        if not room:
            return

        text = json.dumps(message)
        dead: list[str] = []
        for uid, ws in list(room.items()):
            if uid == exclude_user:
                continue
            try:
                await ws.send_text(text)
            except Exception:
                dead.append(uid)

        for uid in dead:
            self.disconnect(uid, room_id)

    async def send_to_user(self, user_id: str, message: dict):
        ws = self.user_connections.get(user_id)
        if not ws:
            return
        try:
            await ws.send_text(json.dumps(message))
        except Exception:
            pass

    def is_online(self, user_id: str) -> bool:
        return user_id in self.user_connections


ws_manager = RoomConnectionManager()
