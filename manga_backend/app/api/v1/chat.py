"""Chat API – rooms, messages, media upload."""
import math, uuid
from datetime import datetime
from fastapi import APIRouter, Depends, HTTPException, Query, UploadFile, File
from sqlalchemy import desc, func, or_, and_, case
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from pydantic import BaseModel

from app.core.database import get_db
from app.api.dependencies import get_current_user
from app.models.models import ChatRoom, ChatRoomMember, ChatMessage, User
from app.services.minio_service import minio_service

router = APIRouter()


# ── Schemas ──────────────────────────────────────────────
class RoomCreate(BaseModel):
    type: str = "direct"  # 'direct' or 'group'
    name: str | None = None
    user_ids: list[str] = []  # For direct: 1 user. For group: multiple.


class MessageCreate(BaseModel):
    content: str
    reply_to_id: str | None = None


# ── Rooms ────────────────────────────────────────────────
@router.get("/rooms")
async def get_rooms(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Get all chat rooms the current user is a member of."""
    result = await db.execute(
        select(ChatRoom)
        .join(ChatRoomMember, ChatRoom.RoomId == ChatRoomMember.RoomId)
        .where(ChatRoomMember.UserId == current_user.UserId)
        .order_by(desc(ChatRoom.UpdatedAt))
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
            select(User.UserId, User.Username, User.Avatar, User.DisplayName)
            .join(ChatRoomMember, User.UserId == ChatRoomMember.UserId)
            .where(ChatRoomMember.RoomId == room.RoomId)
        )
        members = [
            {"user_id": str(m.UserId), "username": m.Username, "avatar": m.Avatar, "display_name": m.DisplayName}
            for m in members_r.all()
        ]

        # For direct chats, use the other user's name as room name
        display_name = room.Name
        if room.Type == "direct":
            other = [m for m in members if m["user_id"] != str(current_user.UserId)]
            if other:
                display_name = other[0]["display_name"] or other[0]["username"]

        items.append({
            "room_id": str(room.RoomId),
            "type": room.Type,
            "name": display_name,
            "avatar_url": room.AvatarUrl,
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
    if body.type == "direct" and len(body.user_ids) != 1:
        raise HTTPException(status_code=400, detail="Direct chat requires exactly 1 other user")

    target_user_id = uuid.UUID(body.user_ids[0]) if body.type == "direct" else None

    # For direct chat, check if room already exists
    if body.type == "direct" and target_user_id:
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
        Type=body.type,
        Name=body.name if body.type == "group" else None,
        CreatedBy=current_user.UserId,
    )
    db.add(room)
    await db.flush()

    # Add creator as member (admin for groups)
    db.add(ChatRoomMember(
        RoomId=room.RoomId, UserId=current_user.UserId,
        Role="admin" if body.type == "group" else "member",
    ))

    # Add other members
    for uid_str in body.user_ids:
        uid = uuid.UUID(uid_str)
        if uid != current_user.UserId:
            db.add(ChatRoomMember(RoomId=room.RoomId, UserId=uid))

    await db.commit()
    return {"room_id": str(room.RoomId), "existing": False}


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
    # Verify membership
    member = await db.execute(
        select(ChatRoomMember).where(
            ChatRoomMember.RoomId == room_id, ChatRoomMember.UserId == current_user.UserId
        )
    )
    if not member.scalars().first():
        raise HTTPException(status_code=403, detail="Not a member of this room")

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
        sender_r = await db.execute(
            select(User.Username, User.Avatar, User.DisplayName).where(User.UserId == msg.SenderId)
        )
        sender = sender_r.first()
        items.append({
            "message_id": str(msg.MessageId),
            "room_id": str(msg.RoomId),
            "sender_id": str(msg.SenderId),
            "sender_username": sender.Username if sender else None,
            "sender_avatar": sender.Avatar if sender else None,
            "sender_display_name": sender.DisplayName if sender else None,
            "content": msg.Content,
            "message_type": msg.MessageType,
            "media_url": msg.MediaUrl,
            "reply_to_id": str(msg.ReplyToId) if msg.ReplyToId else None,
            "status": msg.Status,
            "created_at": msg.CreatedAt.isoformat() if msg.CreatedAt else None,
            "edited_at": msg.EditedAt.isoformat() if msg.EditedAt else None,
            "is_own": msg.SenderId == current_user.UserId,
        })

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
    member = await db.execute(
        select(ChatRoomMember).where(
            ChatRoomMember.RoomId == room_id, ChatRoomMember.UserId == current_user.UserId
        )
    )
    if not member.scalars().first():
        raise HTTPException(status_code=403, detail="Not a member of this room")

    msg = ChatMessage(
        RoomId=room_id,
        SenderId=current_user.UserId,
        Content=body.content,
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

    return {
        "message_id": str(msg.MessageId),
        "created_at": msg.CreatedAt.isoformat() if msg.CreatedAt else None,
    }


@router.post("/rooms/{room_id}/media", status_code=201)
async def upload_chat_media(
    room_id: uuid.UUID,
    file: UploadFile = File(...),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Upload an image to a chat room."""
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
        MediaUrl=media_url,
    )
    db.add(msg)

    room_r = await db.execute(select(ChatRoom).where(ChatRoom.RoomId == room_id))
    room = room_r.scalars().first()
    if room:
        room.UpdatedAt = datetime.utcnow()

    await db.commit()
    return {"message_id": str(msg.MessageId), "media_url": media_url}


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
