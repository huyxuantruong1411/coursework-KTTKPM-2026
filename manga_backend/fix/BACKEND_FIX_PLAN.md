# Backend – Kế hoạch sửa lỗi & bổ sung tính năng

> Phân tích dựa trên toàn bộ codebase dump (project_dump.txt + project_dump.md)  
> Ngày: 2026-05-13

---

## 1. LỖI ẢNH CHAT KHÔNG HIỂN THỊ ĐƯỢC (presigned URL hết hạn)

### Root cause

`upload_chat_media` trong `app/api/v1/chat.py` (dòng ~2150-2165):

```python
object_key = f"chat/{room_id}/{uuid.uuid4()}.{ext}"
media_url = await minio_service.get_presigned_url(object_key)  # presigned URL
msg = ChatMessage(
    ...
    MediaUrl=media_url,   # ← LƯU PRESIGNED URL VÀO DB
)
```

Presigned URL của MinIO mặc định hết hạn sau 7 ngày (hoặc theo config `PRESIGNED_EXPIRY`). Sau khi hết hạn, `GET messages` trả về URL không còn hợp lệ → Flutter không load được ảnh.

### Fix

**Lưu `object_key` thay vì presigned URL vào DB, generate URL mới khi serve:**

```python
# upload_chat_media – thay đổi:
object_key = f"chat/{room_id}/{uuid.uuid4()}.{ext}"
await minio_service.upload_file(file, object_key)  # upload trước

msg = ChatMessage(
    RoomId=room_id,
    SenderId=current_user.UserId,
    MessageType="image",
    MediaUrl=object_key,   # ← LƯU OBJECT KEY, không phải presigned URL
)
db.add(msg)
await db.commit()
await db.refresh(msg)

# Generate presigned URL để trả về client ngay
presigned = await minio_service.get_presigned_url(object_key)
return {"message_id": str(msg.MessageId), "media_url": presigned}
```

**Trong `get_room_messages`, generate presigned URL mới khi serve:**

```python
for msg in reversed(messages):
    media_url = None
    if msg.MediaUrl:
        if msg.MediaUrl.startswith("chat/"):
            # Object key → generate fresh presigned URL
            media_url = await minio_service.get_presigned_url(msg.MediaUrl)
        else:
            # Backward compat: đã là full URL (cũ)
            media_url = msg.MediaUrl
    items.append({
        ...
        "media_url": media_url,
        ...
    })
```

**Tương tự với `send_room_message` (REST)**: hiện tại không xử lý media, nhưng nếu sau này mở rộng cần nhất quán.

---

## 2. BUG `createRoom` TRẢ VỀ `room_id` SAI KHI PHÒNG ĐÃ TỒN TẠI

### Root cause

Trong `create_room` (`app/api/v1/chat.py`, dòng ~1994-1995):

```python
existing_room = existing.scalars().first()
if existing_room:
    return {"room_id": str(existing_room), "existing": True}
    # ← str(existing_room) = "<ChatRoom object at 0x...>" hay tên model class
    # KHÔNG phải UUID string!
```

`existing_room` là ORM object, `str()` trả về đại diện Python của object thay vì UUID.

### Fix

```python
if existing_room:
    return {"room_id": str(existing_room.RoomId), "existing": True}
    #                              ↑ thêm .RoomId
```

---

## 3. WEBSOCKET BROADCAST THIẾU TRƯỜNG `message_type`

### Root cause

Trong `main.py`, handler WebSocket `websocket_chat` (dòng ~990-999):

```python
broadcast = {
    "type": "message",
    "message_id": str(chat_msg.MessageId),
    "room_id": room_id,
    "sender_id": user_id,
    "sender_username": ...,
    "sender_avatar": ...,
    "content": content,
    "created_at": ...,
    # ← THIẾU "message_type": "text"
}
```

Khi Flutter nhận WS event, không có `message_type` → Flutter đọc là empty string → không render đúng loại tin nhắn.

### Fix

```python
broadcast = {
    "type": "message",
    "message_id": str(chat_msg.MessageId),
    "room_id": room_id,
    "sender_id": user_id,
    "sender_username": sender.Username if sender else None,
    "sender_avatar": sender.Avatar if sender else None,
    "content": content,
    "message_type": chat_msg.MessageType,   # ← THÊM
    "media_url": None,                       # ← THÊM (text message không có media)
    "created_at": chat_msg.CreatedAt.isoformat() if chat_msg.CreatedAt else None,
}
```

---

## 4. THIẾU ENDPOINT `GET /friends/sent` (danh sách lời mời đã gửi)

### Root cause

`friends_screen.dart` có Tab "Đã gửi" nhưng Flutter hard-code `_pendingSent = const []` vì backend thiếu endpoint này. `friends.py` không có route `/sent`.

### Fix – Thêm vào `app/api/v1/friends.py`

```python
@router.get("/sent")
async def list_sent_requests(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """List pending friend requests sent by current user."""
    result = await db.execute(
        select(Friendship).where(
            Friendship.UserId == current_user.UserId,
            Friendship.Status == "pending",
        )
    )
    requests = result.scalars().all()

    items = []
    for f in requests:
        info = await _user_info(f.FriendId, db)
        if info:
            info["requested_at"] = f.CreatedAt.isoformat() if f.CreatedAt else None
            items.append(info)

    return {"requests": items}
```

---

## 5. THIẾU CRUD QUẢN LÝ PHÒNG CHAT

### Các endpoint cần bổ sung vào `app/api/v1/chat.py`

```python
# PUT /chat/rooms/{room_id} – đổi tên phòng
@router.put("/rooms/{room_id}")
async def update_room(
    room_id: uuid.UUID,
    body: dict,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Rename a group chat room. Only members can rename."""
    room = await _get_room_member_or_403(room_id, current_user.UserId, db)
    if room.Type != "group":
        raise HTTPException(status_code=400, detail="Cannot rename direct chats")
    name = body.get("name", "").strip()
    if not name:
        raise HTTPException(status_code=422, detail="Name is required")
    room.Name = name
    await db.commit()
    return {"room_id": str(room_id), "name": name}


# DELETE /chat/rooms/{room_id}/members/me – rời phòng
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
        raise HTTPException(status_code=404)
    await db.delete(member)
    await db.commit()


# GET /chat/rooms/{room_id}/members – danh sách thành viên
@router.get("/rooms/{room_id}/members")
async def get_room_members(
    room_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Get members of a room (must be a member)."""
    await _get_room_member_or_403(room_id, current_user.UserId, db)
    members_r = await db.execute(
        select(ChatRoomMember).where(ChatRoomMember.RoomId == room_id)
    )
    members = members_r.scalars().all()
    items = []
    for m in members:
        info = await _user_info(m.UserId, db)  # reuse helper từ friends.py hoặc tạo riêng
        if info:
            items.append(info)
    return {"members": items}


# POST /chat/rooms/{room_id}/members – thêm thành viên
@router.post("/rooms/{room_id}/members", status_code=201)
async def add_member(
    room_id: uuid.UUID,
    body: dict,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    room = await _get_room_member_or_403(room_id, current_user.UserId, db)
    if room.Type == "direct":
        raise HTTPException(status_code=400, detail="Cannot add members to direct chats")
    user_id = uuid.UUID(body.get("user_id"))
    db.add(ChatRoomMember(RoomId=room_id, UserId=user_id))
    await db.commit()
    return {"success": True}


# Helper
async def _get_room_member_or_403(room_id, user_id, db) -> ChatRoom:
    room_r = await db.execute(select(ChatRoom).where(ChatRoom.RoomId == room_id))
    room = room_r.scalars().first()
    if not room:
        raise HTTPException(status_code=404)
    member_r = await db.execute(
        select(ChatRoomMember).where(
            ChatRoomMember.RoomId == room_id,
            ChatRoomMember.UserId == user_id,
        )
    )
    if not member_r.scalars().first():
        raise HTTPException(status_code=403, detail="Not a member")
    return room
```

---

## 6. WEBSOCKET – BROADCAST KHÔNG GỬI VỀ CHO SENDER (tiềm ẩn duplicate)

### Phân tích

`send_to_room()` gửi tới **tất cả** kết nối trong phòng kể cả sender (`exclude_user=None`). Flutter sender tự thêm message vào local list sau khi REST call thành công (`_send()`), sau đó lại nhận thêm WS event của chính mình → `_appendMessage` có dedup check theo `message_id` nên hiện tại OK.

Tuy nhiên nếu REST call thành công nhưng trả về `message_id` không khớp với WS broadcast → duplicate. Nên thêm `exclude_user=user_id` cho WS "message" broadcast để sender không nhận lại chính mình:

```python
await ws_manager.send_to_room(room_id, broadcast, exclude_user=user_id)
```

Flutter đã thêm tin nhắn local ngay khi gửi → trải nghiệm tốt hơn, không cần chờ WS confirm.

---

## 7. LỖI N+1 QUERY TRONG `get_rooms` VÀ `get_room_messages`

### Root cause

`get_rooms` (dòng ~1895-1958) và `get_room_messages` đều có loop:
```python
for room in rooms:
    # Execute nhiều queries riêng lẻ trong loop → N+1
    last_msg = await db.execute(...)
    member_count = await db.execute(...)
    members = await db.execute(...)
```

Với nhiều phòng chat, performance sẽ rất chậm.

### Fix (tùy thời gian)

Dùng JOIN hoặc subquery thay vì loop query. Ví dụ dùng `selectinload` hoặc explicit JOIN:

```python
from sqlalchemy.orm import selectinload

result = await db.execute(
    select(ChatRoom)
    .join(ChatRoomMember, ChatRoomMember.RoomId == ChatRoom.RoomId)
    .where(ChatRoomMember.UserId == current_user.UserId)
    .options(selectinload(ChatRoom.members))
)
```

---

## 8. THIẾU TÍNH NĂNG MARK-ALL-READ (một endpoint cho cả phòng)

### Hiện trạng

Chỉ có `PUT /chat/messages/{message_id}/read` (từng message). Flutter không gọi endpoint này.

### Fix – Thêm endpoint bulk mark-read

```python
@router.post("/rooms/{room_id}/read")
async def mark_room_read(
    room_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Mark all messages in a room as read for current user."""
    member_r = await db.execute(
        select(ChatRoomMember).where(
            ChatRoomMember.RoomId == room_id,
            ChatRoomMember.UserId == current_user.UserId,
        )
    )
    mem = member_r.scalars().first()
    if mem:
        mem.LastReadAt = datetime.utcnow()
        await db.commit()
    return {"success": True}
```

Flutter gọi endpoint này ngay khi enter `ChatScreen`.

---

## 9. KHÔNG CÓ PAGINATION CHO `get_rooms` (scalability)

Hiện tại `GET /chat/rooms` trả về **tất cả phòng** không giới hạn. Với user có nhiều phòng chat, sẽ chậm.

### Fix

```python
@router.get("/rooms")
async def get_rooms(
    page: int = Query(1, ge=1),
    limit: int = Query(20, ge=1, le=100),
    ...
):
    # Thêm .offset((page-1)*limit).limit(limit)
```

---

## 10. THIẾU VALIDATION CHO `create_room` – GROUP ROOM KHÔNG CÓ TÊN

### Root cause

```python
@router.post("/rooms")
async def create_room(body: dict, ...):
    if body.get("type") == "group" and not body.get("name"):
        pass  # Không validate – tên có thể NULL
```

Group room không có tên → hiển thị "None" hoặc empty trên UI.

### Fix

```python
room_type = body.get("type", "group")
name = body.get("name", "").strip() if room_type == "group" else None
if room_type == "group" and not name:
    raise HTTPException(status_code=422, detail="Group room must have a name")
```

---

## Tóm tắt ưu tiên

| # | Vấn đề | File | Độ ưu tiên | Effort |
|---|--------|------|-----------|--------|
| 1 | Presigned URL hết hạn → ảnh không load | chat.py | 🔴 Critical | M |
| 2 | `str(existing_room)` bug | chat.py | 🔴 Critical | S |
| 3 | WS broadcast thiếu `message_type` | main.py | 🔴 Critical | S |
| 4 | Thiếu `GET /friends/sent` | friends.py | 🟡 High | S |
| 5 | CRUD phòng chat | chat.py | 🟠 Medium | L |
| 6 | WS broadcast gửi về sender → exclude_user | main.py | 🟠 Medium | S |
| 7 | N+1 query trong get_rooms | chat.py | 🟠 Medium | M |
| 8 | Mark-all-read endpoint | chat.py | 🟠 Medium | S |
| 9 | Thiếu pagination cho get_rooms | chat.py | 🟢 Low | S |
| 10 | Validation group room name | chat.py | 🟢 Low | S |
