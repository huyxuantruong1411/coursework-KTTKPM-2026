"""Chat API – rooms, messages, media upload."""
import math, uuid
from datetime import datetime
from urllib.parse import unquote, urlparse
from fastapi import APIRouter, Depends, HTTPException, Query, UploadFile, File
from sqlalchemy import desc, func, or_, and_, case, delete
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from pydantic import BaseModel

from app.core.database import get_db
from app.api.dependencies import get_current_user
from app.models.models import ChatRoom, ChatRoomMember, ChatMessage, User, UserPresence
from app.services.minio_service import minio_service
from app.services.ws_manager import ws_manager

router = APIRouter()


# ── Schemas ──────────────────────────────────────────────
class RoomCreate(BaseModel):
    type: str = "direct"  # 'direct' or 'group'
    name: str | None = None
    user_ids: list[str] = []  # For direct: 1 user. For group: multiple.


class MessageCreate(BaseModel):
    content: str
    reply_to_id: str | None = None


class RoomUpdate(BaseModel):
    name: str


class MemberAdd(BaseModel):
    user_id: str


def _chat_media_object_key(value: str | None) -> str | None:
    """Return a chat object key from either a stored key or an old presigned URL."""
    if not value:
        return None
    if value.startswith("chat/"):
        return value
    parsed = urlparse(value)
    if not parsed.scheme:
        return value
    path = unquote(parsed.path).lstrip("/")
    idx = path.find("chat/")
    if idx >= 0:
        return path[idx:]
    return None


async def _media_url_for_client(value: str | None) -> str | None:
    if not value:
        return None
    object_key = _chat_media_object_key(value)
    if object_key:
        try:
            return await minio_service.get_presigned_url(object_key)
        except Exception:
            return value
    return value


async def _user_payload(user_id: uuid.UUID, db: AsyncSession) -> dict | None:
    r = await db.execute(
        select(User.UserId, User.Username, User.Avatar, User.DisplayName)
        .where(User.UserId == user_id)
    )
    row = r.first()
    if not row:
        return None

    presence_r = await db.execute(
        select(UserPresence.IsOnline, UserPresence.LastSeenAt)
        .where(UserPresence.UserId == user_id)
    )
    presence = presence_r.first()
    return {
        "user_id": str(row.UserId),
        "username": row.Username,
        "avatar": row.Avatar,
        "display_name": row.DisplayName,
        "is_online": bool(presence.IsOnline) if presence else False,
        "last_seen": presence.LastSeenAt.isoformat() if presence and presence.LastSeenAt else None,
    }


async def _get_room_member_or_403(
    room_id: uuid.UUID,
    user_id: uuid.UUID,
    db: AsyncSession,
) -> tuple[ChatRoom, ChatRoomMember]:
    room_r = await db.execute(select(ChatRoom).where(ChatRoom.RoomId == room_id))
    room = room_r.scalars().first()
    if not room:
        raise HTTPException(status_code=404, detail="Room not found")

    member_r = await db.execute(
        select(ChatRoomMember).where(
            ChatRoomMember.RoomId == room_id,
            ChatRoomMember.UserId == user_id,
        )
    )
    member = member_r.scalars().first()
    if not member:
        raise HTTPException(status_code=403, detail="Not a member of this room")
    return room, member


async def _ensure_room_admin(
    room_id: uuid.UUID,
    user_id: uuid.UUID,
    db: AsyncSession,
) -> ChatRoom:
    room, member = await _get_room_member_or_403(room_id, user_id, db)
    if room.CreatedBy != user_id and member.Role != "admin":
        raise HTTPException(status_code=403, detail="Admin permission required")
    return room


async def _message_payload(
    msg: ChatMessage,
    db: AsyncSession,
    current_user_id: uuid.UUID | None = None,
) -> dict:
    sender = await _user_payload(msg.SenderId, db)
    return {
        "type": "message",
        "message_id": str(msg.MessageId),
        "room_id": str(msg.RoomId),
        "sender_id": str(msg.SenderId),
        "sender_username": sender["username"] if sender else None,
        "sender_avatar": sender["avatar"] if sender else None,
        "sender_display_name": sender["display_name"] if sender else None,
        "content": msg.Content,
        "message_type": msg.MessageType,
        "media_url": await _media_url_for_client(msg.MediaUrl),
        "reply_to_id": str(msg.ReplyToId) if msg.ReplyToId else None,
        "status": msg.Status,
        "created_at": msg.CreatedAt.isoformat() if msg.CreatedAt else None,
        "edited_at": msg.EditedAt.isoformat() if msg.EditedAt else None,
        "is_own": msg.SenderId == current_user_id if current_user_id else False,
    }


async def _broadcast_message(
    msg: ChatMessage,
    db: AsyncSession,
    exclude_user: uuid.UUID | None = None,
):
    payload = await _message_payload(msg, db)
    await ws_manager.send_to_room(
        str(msg.RoomId),
        payload,
        exclude_user=str(exclude_user) if exclude_user else None,
    )


# ── Rooms ────────────────────────────────────────────────
@router.get("/rooms")
async def get_rooms(
    page: int = Query(1, ge=1),
    limit: int = Query(50, ge=1, le=100),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Get all chat rooms the current user is a member of."""
    result = await db.execute(
        select(ChatRoom)
        .join(ChatRoomMember, ChatRoom.RoomId == ChatRoomMember.RoomId)
        .where(ChatRoomMember.UserId == current_user.UserId)
        .order_by(desc(ChatRoom.UpdatedAt))
        .offset((page - 1) * limit)
        .limit(limit)
    )
    rooms = result.scalars().all()

    items = []
    for room in rooms:
        # Get last message
        last_msg_r = await db.execute(
            select(ChatMessage)
            .where(ChatMessage.RoomId == room.RoomId, ChatMessage.IsDeleted != True)
            .order_by(desc(ChatMessage.CreatedAt))
            .limit(1)
        )
        last_msg = last_msg_r.scalars().first()

        # Get unread count
        member_r = await db.execute(
            select(ChatRoomMember)
            .where(ChatRoomMember.RoomId == room.RoomId, ChatRoomMember.UserId == current_user.UserId)
        )
        member = member_r.scalars().first()
        unread = 0
        if member and member.LastReadAt:
            unread_r = await db.execute(
                select(func.count()).select_from(
                    select(ChatMessage).where(
                        ChatMessage.RoomId == room.RoomId,
                        ChatMessage.CreatedAt > member.LastReadAt,
                        ChatMessage.SenderId != current_user.UserId,
                        ChatMessage.IsDeleted != True,
                    ).subquery()
                )
            )
            unread = unread_r.scalar() or 0

        # Get members info (for direct chats, show the other user)
        members_r = await db.execute(
            select(ChatRoomMember.UserId).where(ChatRoomMember.RoomId == room.RoomId)
        )
        members = []
        for row in members_r.all():
            info = await _user_payload(row.UserId, db)
            if info:
                members.append(info)

        # For direct chats, use the other user's name as room name
        display_name = room.Name
        avatar_url = room.AvatarUrl
        if room.Type == "direct":
            other = [m for m in members if m["user_id"] != str(current_user.UserId)]
            if other:
                display_name = other[0]["display_name"] or other[0]["username"]
                avatar_url = other[0]["avatar"]

        items.append({
            "room_id": str(room.RoomId),
            "type": room.Type,
            "name": display_name,
            "avatar_url": avatar_url,
            "members": members,
            "last_message": {
                "content": last_msg.Content if last_msg else None,
                "sender_id": str(last_msg.SenderId) if last_msg else None,
                "created_at": last_msg.CreatedAt.isoformat() if last_msg and last_msg.CreatedAt else None,
                "type": last_msg.MessageType if last_msg else None,
            } if last_msg else None,
            "unread_count": unread,
            "updated_at": room.UpdatedAt.isoformat() if room.UpdatedAt else None,
        })

    return {"rooms": items}


@router.post("/rooms", status_code=201)
async def create_room(
    body: RoomCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Create a new chat room (direct or group)."""
    room_type = body.type.strip().lower()
    if room_type not in {"direct", "group"}:
        raise HTTPException(status_code=422, detail="Room type must be direct or group")

    name = body.name.strip() if body.name else None
    if room_type == "group" and not name:
        raise HTTPException(status_code=422, detail="Group room must have a name")

    if room_type == "direct" and len(body.user_ids) != 1:
        raise HTTPException(status_code=400, detail="Direct chat requires exactly 1 other user")

    try:
        target_user_id = uuid.UUID(body.user_ids[0]) if room_type == "direct" else None
    except ValueError:
        raise HTTPException(status_code=422, detail="Invalid user_id")
    if target_user_id == current_user.UserId:
        raise HTTPException(status_code=400, detail="Cannot create a direct chat with yourself")
    if target_user_id:
        target_r = await db.execute(select(User.UserId).where(User.UserId == target_user_id))
        if not target_r.first():
            raise HTTPException(status_code=404, detail="User not found")

    # For direct chat, check if room already exists
    if room_type == "direct" and target_user_id:
        existing = await db.execute(
            select(ChatRoom.RoomId)
            .join(ChatRoomMember, ChatRoom.RoomId == ChatRoomMember.RoomId)
            .where(ChatRoom.Type == "direct")
            .group_by(ChatRoom.RoomId)
            .having(
                func.sum(
                    case(
                        (or_(
                            ChatRoomMember.UserId == current_user.UserId,
                            ChatRoomMember.UserId == target_user_id,
                        ), 1),
                        else_=0
                    )
                ) == 2
            )
        )
        existing_room = existing.scalars().first()
        if existing_room:
            return {"room_id": str(existing_room), "existing": True}

    room = ChatRoom(
        Type=room_type,
        Name=name if room_type == "group" else None,
        CreatedBy=current_user.UserId,
    )
    db.add(room)
    await db.flush()

    # Add creator as member (admin for groups)
    db.add(ChatRoomMember(
        RoomId=room.RoomId, UserId=current_user.UserId,
        Role="admin" if room_type == "group" else "member",
    ))

    # Add other members
    seen = {current_user.UserId}
    for uid_str in body.user_ids:
        try:
            uid = uuid.UUID(uid_str)
        except ValueError:
            raise HTTPException(status_code=422, detail="Invalid user_id")
        if uid not in seen:
            db.add(ChatRoomMember(RoomId=room.RoomId, UserId=uid))
            seen.add(uid)

    await db.commit()
    return {"room_id": str(room.RoomId), "existing": False}


@router.put("/rooms/{room_id}")
async def update_room(
    room_id: uuid.UUID,
    body: RoomUpdate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Rename a group chat room."""
    room, _member = await _get_room_member_or_403(room_id, current_user.UserId, db)
    if room.Type != "group":
        raise HTTPException(status_code=400, detail="Cannot rename direct chats")

    name = body.name.strip()
    if not name:
        raise HTTPException(status_code=422, detail="Name is required")

    room.Name = name
    room.UpdatedAt = datetime.utcnow()
    await db.commit()
    return {"room_id": str(room.RoomId), "name": room.Name}


@router.delete("/rooms/{room_id}", status_code=204)
async def delete_room(
    room_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Delete a room. Only the creator or an admin can delete."""
    room = await _ensure_room_admin(room_id, current_user.UserId, db)
    await db.execute(delete(ChatMessage).where(ChatMessage.RoomId == room_id))
    await db.execute(delete(ChatRoomMember).where(ChatRoomMember.RoomId == room_id))
    await db.delete(room)
    await db.commit()


@router.get("/rooms/{room_id}/members")
async def get_room_members(
    room_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Get members of a room."""
    await _get_room_member_or_403(room_id, current_user.UserId, db)
    members_r = await db.execute(
        select(ChatRoomMember.UserId).where(ChatRoomMember.RoomId == room_id)
    )
    items = []
    for row in members_r.all():
        info = await _user_payload(row.UserId, db)
        if info:
            items.append(info)
    return {"members": items}


@router.post("/rooms/{room_id}/members", status_code=201)
async def add_member(
    room_id: uuid.UUID,
    body: MemberAdd,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Add a member to a group chat room."""
    room = await _ensure_room_admin(room_id, current_user.UserId, db)
    if room.Type == "direct":
        raise HTTPException(status_code=400, detail="Cannot add members to direct chats")

    try:
        user_id = uuid.UUID(body.user_id)
    except ValueError:
        raise HTTPException(status_code=422, detail="Invalid user_id")

    user_r = await db.execute(select(User.UserId).where(User.UserId == user_id))
    if not user_r.first():
        raise HTTPException(status_code=404, detail="User not found")

    existing_r = await db.execute(
        select(ChatRoomMember).where(
            ChatRoomMember.RoomId == room_id,
            ChatRoomMember.UserId == user_id,
        )
    )
    if existing_r.scalars().first():
        return {"success": True, "already_member": True}

    db.add(ChatRoomMember(RoomId=room_id, UserId=user_id))
    room.UpdatedAt = datetime.utcnow()
    await db.commit()
    return {"success": True, "already_member": False}


@router.delete("/rooms/{room_id}/members/me", status_code=204)
async def leave_room(
    room_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Leave a chat room."""
    member_r = await db.execute(
        select(ChatRoomMember).where(
            ChatRoomMember.RoomId == room_id,
            ChatRoomMember.UserId == current_user.UserId,
        )
    )
    member = member_r.scalars().first()
    if not member:
        raise HTTPException(status_code=404, detail="Membership not found")

    await db.delete(member)
    await db.commit()


@router.delete("/rooms/{room_id}/members/{user_id}", status_code=204)
async def remove_member(
    room_id: uuid.UUID,
    user_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Remove a member from a group chat room."""
    room = await _ensure_room_admin(room_id, current_user.UserId, db)
    if room.Type == "direct":
        raise HTTPException(status_code=400, detail="Cannot remove members from direct chats")
    if user_id == current_user.UserId:
        raise HTTPException(status_code=400, detail="Use leave room instead")

    member_r = await db.execute(
        select(ChatRoomMember).where(
            ChatRoomMember.RoomId == room_id,
            ChatRoomMember.UserId == user_id,
        )
    )
    member = member_r.scalars().first()
    if not member:
        raise HTTPException(status_code=404, detail="Membership not found")

    await db.delete(member)
    room.UpdatedAt = datetime.utcnow()
    await db.commit()


# ── Messages ─────────────────────────────────────────────
@router.get("/rooms/{room_id}/messages")
async def get_messages(
    room_id: uuid.UUID,
    page: int = Query(1, ge=1),
    limit: int = Query(50, ge=1, le=200),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Get paginated message history for a room."""
    await _get_room_member_or_403(room_id, current_user.UserId, db)

    base = select(ChatMessage).where(
        ChatMessage.RoomId == room_id, ChatMessage.IsDeleted != True
    )
    total = (await db.execute(select(func.count()).select_from(base.subquery()))).scalar() or 0

    result = await db.execute(
        base.order_by(desc(ChatMessage.CreatedAt))
        .offset((page - 1) * limit).limit(limit)
    )
    messages = result.scalars().all()

    items = []
    for msg in reversed(messages):  # Reverse to get oldest first for display
        items.append(await _message_payload(msg, db, current_user.UserId))

    # Mark as read
    member_update = await db.execute(
        select(ChatRoomMember).where(
            ChatRoomMember.RoomId == room_id, ChatRoomMember.UserId == current_user.UserId
        )
    )
    mem = member_update.scalars().first()
    if mem:
        mem.LastReadAt = datetime.utcnow()
        await db.commit()

    return {
        "messages": items,
        "page": page,
        "per_page": limit,
        "total": total,
        "total_pages": math.ceil(total / limit) if limit else 0,
    }


@router.post("/rooms/{room_id}/messages", status_code=201)
async def send_message(
    room_id: uuid.UUID,
    body: MessageCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Send a text message to a room."""
    await _get_room_member_or_403(room_id, current_user.UserId, db)

    msg = ChatMessage(
        RoomId=room_id,
        SenderId=current_user.UserId,
        Content=body.content,
        MessageType="text",
        ReplyToId=uuid.UUID(body.reply_to_id) if body.reply_to_id else None,
    )
    db.add(msg)

    # Update room timestamp
    room_r = await db.execute(select(ChatRoom).where(ChatRoom.RoomId == room_id))
    room = room_r.scalars().first()
    if room:
        room.UpdatedAt = datetime.utcnow()

    await db.commit()
    await db.refresh(msg)
    payload = await _message_payload(msg, db, current_user.UserId)
    await _broadcast_message(msg, db, exclude_user=current_user.UserId)

    return payload


@router.post("/rooms/{room_id}/media", status_code=201)
async def upload_chat_media(
    room_id: uuid.UUID,
    file: UploadFile = File(...),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Upload an image to a chat room."""
    await _get_room_member_or_403(room_id, current_user.UserId, db)

    # Only allow images
    if not file.content_type or not file.content_type.startswith("image/"):
        raise HTTPException(status_code=400, detail="Only images are allowed")

    content = await file.read()
    if len(content) > 10 * 1024 * 1024:
        raise HTTPException(status_code=400, detail="File too large (max 10MB)")

    ext = file.filename.rsplit(".", 1)[-1] if file.filename and "." in file.filename else "jpg"
    object_key = f"chat/{room_id}/{uuid.uuid4()}.{ext}"

    await minio_service.upload_bytes(content, object_key, file.content_type)
    media_url = await minio_service.get_presigned_url(object_key)

    # Create message with image
    msg = ChatMessage(
        RoomId=room_id,
        SenderId=current_user.UserId,
        Content="[Image]",
        MessageType="image",
        MediaUrl=object_key,
    )
    db.add(msg)

    room_r = await db.execute(select(ChatRoom).where(ChatRoom.RoomId == room_id))
    room = room_r.scalars().first()
    if room:
        room.UpdatedAt = datetime.utcnow()

    await db.commit()
    await db.refresh(msg)
    await _broadcast_message(msg, db, exclude_user=current_user.UserId)
    return {
        "message_id": str(msg.MessageId),
        "room_id": str(room_id),
        "sender_id": str(current_user.UserId),
        "sender_username": current_user.Username,
        "sender_avatar": current_user.Avatar,
        "sender_display_name": current_user.DisplayName,
        "content": msg.Content,
        "message_type": msg.MessageType,
        "media_url": media_url,
        "status": msg.Status,
        "created_at": msg.CreatedAt.isoformat() if msg.CreatedAt else None,
        "is_own": True,
    }


@router.put("/messages/{message_id}/read")
async def mark_read(
    message_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Mark messages as read up to this message."""
    msg = await db.execute(select(ChatMessage).where(ChatMessage.MessageId == message_id))
    message = msg.scalars().first()
    if not message:
        raise HTTPException(status_code=404)

    member = await db.execute(
        select(ChatRoomMember).where(
            ChatRoomMember.RoomId == message.RoomId,
            ChatRoomMember.UserId == current_user.UserId,
        )
    )
    mem = member.scalars().first()
    if mem:
        mem.LastReadAt = message.CreatedAt or datetime.utcnow()
        await db.commit()

    return {"success": True}


@router.post("/rooms/{room_id}/read")
async def mark_room_read(
    room_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Mark all messages in a room as read for current user."""
    _room, member = await _get_room_member_or_403(room_id, current_user.UserId, db)
    member.LastReadAt = datetime.utcnow()
    await db.commit()
    return {"success": True}
