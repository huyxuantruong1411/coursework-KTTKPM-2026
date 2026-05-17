# Flutter App – Kế hoạch sửa lỗi & bổ sung tính năng

> Phân tích dựa trên toàn bộ codebase dump (flutter_project_dump.txt + project_dump.txt)  
> Ngày: 2026-05-13

---

## 1. LỖI HIỂN THỊ ẢNH TRONG LỊCH SỬ CHAT (`[Image]` thay vì ảnh thật)

### Root cause

Trong `_buildMsg()` tại `lib/screens/chat/chat_screen.dart`, điều kiện hiển thị ảnh là:

```dart
if (messageType == 'image' && mediaUrl.isNotEmpty)
  Image.network(mediaUrl, ...)
else
  Text(content.toString(), ...)
```

Khi load lịch sử qua REST (`getMessages`), backend trả về field `"message_type"` (snake_case). Flutter đọc đúng:

```dart
final messageType = (msg['message_type'] ?? msg['MessageType'] ?? msg['type'] ?? '').toString();
```

**Nhưng vấn đề nằm ở `media_url`**: Backend trả về presigned URL từ MinIO tại thời điểm **upload** (trong `upload_chat_media`). Presigned URL của MinIO có thời hạn (mặc định 7 ngày hoặc theo config). Khi load lịch sử sau đó, URL trong DB vẫn là presigned URL cũ đã **hết hạn** → `Image.network` fail → fallback sang `errorBuilder` hiển thị `[Image]`.

**Nguyên nhân phụ**: `errorBuilder` hiện tại in ra text `[Image]` thay vì hiển thị icon ảnh lỗi, khiến user tưởng ảnh không được gửi.

### Fix

**Bước 1 – Cải thiện `errorBuilder` để rõ ràng hơn:**

```dart
// Trong _buildMsg(), thay errorBuilder hiện tại:
errorBuilder: (_, error, __) => Container(
  width: MediaQuery.of(context).size.width * 0.55,
  height: 150,
  decoration: BoxDecoration(
    color: Colors.black26,
    borderRadius: BorderRadius.circular(10),
    border: Border.all(color: Colors.white24),
  ),
  child: Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      const Icon(Icons.broken_image_outlined, color: Colors.white38, size: 36),
      const SizedBox(height: 4),
      Text(
        'Không tải được ảnh',
        style: TextStyle(color: Colors.white38, fontSize: 11),
      ),
    ],
  ),
),
```

**Bước 2 – Dùng `cached_network_image` thay `Image.network` để có retry logic và cache:**

```dart
import 'package:cached_network_image/cached_network_image.dart';

// Thay Image.network bằng:
CachedNetworkImage(
  imageUrl: mediaUrl,
  width: MediaQuery.of(context).size.width * 0.55,
  fit: BoxFit.cover,
  placeholder: (_, __) => Container(
    width: MediaQuery.of(context).size.width * 0.55,
    height: 150,
    color: Colors.black26,
    child: const Center(child: CircularProgressIndicator(color: _kOrange, strokeWidth: 2)),
  ),
  errorWidget: (_, __, ___) => /* icon lỗi như trên */,
),
```

**Bước 3 (phối hợp backend – xem BACKEND_FIX_PLAN.md mục 1)**: Backend cần lưu `object_key` vào DB thay vì presigned URL, sau đó generate presigned URL mới khi serve GET messages.

---

## 2. LỖI TIN NHẮN KHÔNG TỰ CẬP NHẬT REAL-TIME (phải reload mới thấy)

### Root cause

Có **hai luồng** gửi nhận tin nhắn đang xung đột:

**Luồng 1 – Gửi qua REST:** `_send()` → `ChatService.sendMessage()` → backend lưu DB → trả về response → Flutter tự thêm vào `_messages` (đúng với sender).

**Luồng 2 – Nhận qua WebSocket:** Backend broadcast tới cả phòng kể cả người gửi (không dùng `exclude_user`). Flutter nhận WS event → `_appendMessage()`.

**Vấn đề 1 – Người nhận không thấy tin nhắn mới:** Người nhận chỉ nhận được WS event **nếu đang kết nối WS cùng phòng**. Nếu WS bị ngắt (app background, lỗi network), không có fallback polling → phải reload.

**Vấn đề 2 – WS broadcast thiếu `message_type`:** Khi backend broadcast qua WS (dòng 990-999 trong `main.py`), payload **không có trường `message_type`**. Flutter đọc `msg['message_type']` → null → empty string → không render ảnh, chỉ render content text. Đây là bug tiềm ẩn ảnh hưởng cả text lẫn image messages.

**Vấn đề 3 – User trong ảnh 2 (`user_18`):** Hiển thị "User" thay vì username thật là do `sender_username` trong WS broadcast có thể null (nếu DB lookup thất bại), và Flutter fallback sang `'User'`. Cộng với việc các tin nhắn cũ (load từ REST) cũng có thể `sender_username` = null.

### Fix – phía Flutter

**A. Thêm WS reconnect tự động:**

```dart
// Trong _ChatScreenState, thêm:
Timer? _reconnectTimer;
int _reconnectAttempts = 0;

void _connectWs() async {
  final token = await TokenStorage.getToken();
  if (token == null) return;
  try {
    _ws = WebSocketChannel.connect(
      Uri.parse('${AppConstants.wsBaseUrl}/chat/${widget.roomId}?token=$token'),
    );
    _reconnectAttempts = 0;
    _ws!.stream.listen(
      (data) {
        if (!mounted) return;
        try {
          final msg = jsonDecode(data as String) as Map<String, dynamic>;
          _handleWsMessage(msg);
        } catch (_) {}
      },
      onError: (_) => _scheduleReconnect(),
      onDone: () => _scheduleReconnect(),
    );
  } catch (e) {
    _scheduleReconnect();
  }
}

void _scheduleReconnect() {
  if (!mounted) return;
  _reconnectTimer?.cancel();
  final delay = Duration(seconds: (2 << _reconnectAttempts.clamp(0, 4)));
  _reconnectAttempts++;
  _reconnectTimer = Timer(delay, _connectWs);
}

void _handleWsMessage(Map<String, dynamic> msg) {
  final type = msg['type']?.toString();
  if (type == 'message') {
    // Normalize message_type nếu thiếu
    msg.putIfAbsent('message_type', () => 'text');
    _appendMessage(msg);
  }
  // typing, read indicators có thể xử lý sau
}

@override
void dispose() {
  _reconnectTimer?.cancel();
  _ws?.sink.close();
  // ...
}
```

**B. Thêm periodic polling fallback (khi WS mất kết nối):**

```dart
Timer? _pollTimer;

void _startPolling() {
  _pollTimer?.cancel();
  _pollTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
    if (_ws == null) {
      // Chỉ poll khi WS bị ngắt
      final msgs = await ChatService.getMessages(widget.roomId, page: 1, limit: 20);
      for (final m in msgs) {
        _appendMessage(m);
      }
    }
  });
}
```

**C. Normalize field `sender_username` khi hiển thị:**

```dart
// Trong _buildMsg():
final senderName = (
  msg['SenderUsername'] ?? msg['sender_username'] ??
  msg['sender_display_name'] ?? 'Người dùng'
).toString();
```

---

## 3. AVATAR NGƯỜI DÙNG HIỂN THỊ Ô VUÔNG "User" (ảnh 2)

### Root cause

`ChatRoomsScreen._buildRoomTile()` dùng `CircleAvatar` với icon cố định, không load avatar thật. Tương tự trong `_buildMsg()`, không có widget avatar cho sender.

Trong ảnh 2, tất cả tin nhắn từ `user_18` hiển thị ô vuông tối "User" thay vì chứa nội dung. Nguyên nhân thêm: `sender_username` từ WS broadcast lấy từ `User.Username` DB nhưng có thể là `None` nếu user không có username (dùng email). Flutter fallback `'User'` nhưng không hiển thị nội dung tin nhắn đúng cách.

### Fix

**Thêm avatar thật trong room list:**

```dart
Widget _buildRoomTile(Map<String, dynamic> room) {
  final avatarUrl = room['avatar_url']?.toString() ?? room['AvatarUrl']?.toString() ?? '';
  // ...
  leading: CircleAvatar(
    backgroundColor: _kOrange.withValues(alpha: 0.2),
    backgroundImage: avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
    child: avatarUrl.isEmpty
        ? const Icon(Icons.chat_bubble_outline, color: _kOrange)
        : null,
  ),
```

**Hiển thị username rõ hơn trong bubble:**

```dart
// Trong _buildMsg(), đổi fallback:
final senderName = (msg['sender_username'] ?? msg['SenderUsername'] ?? '').toString();
final displayName = senderName.isNotEmpty ? senderName : 'Người dùng';
```

---

## 4. THIẾU TÍNH NĂNG TÌM USER ĐỂ NHẮN TIN TRỰC TIẾP TRONG CHAT

### Phân tích hiện trạng

- `friends_screen.dart` đã có `_showSearchDialog()` với `FriendService.searchUsers()` → gọi `GET /api/v1/friends/search?q=...`
- Nhưng trong `ChatRoomsScreen`, nút FAB (+) chỉ tạo **group room** với tên nhập tay, **không có UI chọn user**

### Fix – Thêm flow "Nhắn tin với user" trong ChatRoomsScreen

```dart
void _createNewRoom() async {
  final result = await showModalBottomSheet<Map<String, dynamic>>(
    context: context,
    backgroundColor: _kCard,
    builder: (ctx) => _NewChatSheet(),
  );
  if (result == null) return;

  if (result['type'] == 'direct') {
    final userId = result['user_id'] as String;
    final name = result['name'] as String;
    final roomResult = await ChatService.createRoom(type: 'direct', userIds: [userId]);
    final roomId = roomResult?['room_id']?.toString() ?? '';
    if (roomId.isNotEmpty && mounted) {
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => ChatScreen(roomId: roomId, roomName: name),
      )).then((_) => _loadRooms());
    }
  } else {
    // group room – giữ flow cũ
  }
}
```

**Tạo widget `_NewChatSheet`** cho phép:
- Tab "Nhắn tin trực tiếp": search user → chọn → tạo direct room
- Tab "Tạo nhóm": nhập tên + chọn nhiều user

---

## 5. CRUD QUẢN LÝ PHÒNG CHAT

### Hiện trạng thiếu

| Tính năng | Backend | Flutter |
|-----------|---------|---------|
| Xem danh sách phòng | ✅ | ✅ |
| Tạo phòng | ✅ | ✅ (chỉ group, không có user picker) |
| Đổi tên phòng | ❌ | ❌ |
| Xóa / rời phòng | ❌ | ❌ |
| Xem thành viên | ✅ (qua get_rooms) | ❌ |
| Thêm thành viên | ❌ | ❌ |
| Xóa thành viên | ❌ | ❌ |

### Fix Flutter (sau khi backend bổ sung – xem BACKEND_FIX_PLAN.md mục 3)

**Thêm long-press menu trên room tile:**

```dart
// Wrap ListTile bằng GestureDetector hoặc dùng onLongPress:
onLongPress: () => _showRoomOptions(room),

void _showRoomOptions(Map<String, dynamic> room) {
  showModalBottomSheet(context: context, builder: (_) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      ListTile(
        leading: const Icon(Icons.edit),
        title: const Text('Đổi tên phòng'),
        onTap: () { /* gọi ChatService.renameRoom */ },
      ),
      ListTile(
        leading: const Icon(Icons.group),
        title: const Text('Xem thành viên'),
        onTap: () { /* push MembersScreen */ },
      ),
      ListTile(
        leading: const Icon(Icons.exit_to_app, color: Colors.red),
        title: const Text('Rời phòng', style: TextStyle(color: Colors.red)),
        onTap: () { /* gọi ChatService.leaveRoom */ },
      ),
    ],
  ));
}
```

**Thêm vào `chat_service.dart`:**

```dart
// PUT /chat/rooms/{id}  body: {name}
static Future<void> renameRoom(String roomId, String name) async { ... }

// DELETE /chat/rooms/{id}/members/me  (rời phòng)
static Future<void> leaveRoom(String roomId) async { ... }

// GET /chat/rooms/{id}/members
static Future<List<Map<String, dynamic>>> getMembers(String roomId) async { ... }
```

---

## 6. CÁC LỖI TIỀM ẨN KHÁC

### 6.1 `_myUserId` có thể null khi so sánh `isMe`

```dart
// Hiện tại:
final isMe = msg['is_own'] == true || senderId == _myUserId;
```

`_myUserId` được load async. Nếu `_init()` chưa xong mà WS nhận được message sớm → `_myUserId == null` → tất cả messages bên trái (isMe = false). **Fix**: Chờ `_myUserId` load xong mới `_connectWs()` (hiện tại đã đúng thứ tự trong `_init()`, nhưng cần guard).

### 6.2 `_pendingSent` luôn rỗng trong FriendsScreen

```dart
// Trong _loadFriends():
_pendingSent = const [];  // ← KHÔNG BAO GIỜ được load!
```

Backend có endpoint `GET /friends/sent` nhưng `FriendService` thiếu method, `_loadFriends()` không gọi. **Fix**:

```dart
// Thêm vào friend_service.dart:
static Future<List<Map<String, dynamic>>> getSentRequests() async {
  try {
    final resp = await _dio.get('/friends/sent');
    final data = resp.data;
    if (data is Map && data['requests'] is List)
      return (data['requests'] as List).cast<Map<String, dynamic>>();
    return [];
  } on DioException catch (_) { return []; }
}

// Trong _loadFriends():
final sent = await FriendService.getSentRequests();
setState(() { _pendingSent = sent; ... });
```

> **Lưu ý**: Backend cũng cần bổ sung `GET /friends/sent` nếu chưa có – xem BACKEND_FIX_PLAN.md mục 4.

### 6.3 `createRoom` trả về `existing_room` với UUID object thay vì string

Trong backend `create_room`:
```python
return {"room_id": str(existing_room), "existing": True}
# ← existing_room là ORM object, str() → "<ChatRoom ...>" chứ không phải UUID!
```

Flutter sẽ nhận `room_id` sai khi direct chat đã tồn tại. **Fix phía backend** – xem BACKEND_FIX_PLAN.md mục 2. Flutter-side cần handle thêm key `existing: true` để navigate đúng.

### 6.4 WebSocket không gửi `message_type` trong broadcast

Broadcast WS (dòng 990-999, `main.py`) thiếu trường `message_type`:

```python
broadcast = {
    "type": "message",
    "message_id": ...,
    "content": content,
    # ← THIẾU "message_type": "text"
}
```

→ Flutter `_appendMessage` nhận message qua WS sẽ có `messageType = ''` → ảnh gửi qua REST có thể hiển thị sai khi WS push về. **Fix phía backend** – xem BACKEND_FIX_PLAN.md mục 5. Flutter không cần fix nhờ `putIfAbsent` trong mục 2A ở trên.

### 6.5 `ChatRoomsScreen` không có nút tìm kiếm user riêng

Đã đề cập ở mục 4. Hiện tại user phải vào `FriendsScreen` → search → rồi mới chat. Cần thêm shortcut từ ChatRoomsScreen.

### 6.6 Không có trạng thái online/offline trong chat list

Backend trả `is_online` trong `friends` response nhưng `ChatRoomsScreen` không hiển thị. Bổ sung dot indicator xanh/xám trên avatar.

### 6.7 `markRead` không được gọi khi mở chat screen

`ChatService.markRead(messageId)` có nhưng không được gọi trong `chat_screen.dart`. Unread count sẽ không giảm. **Fix**:

```dart
// Trong _loadMessages(), sau khi load xong:
for (final msg in _messages) {
  final id = _messageIdOf(msg);
  if (id.isNotEmpty && msg['is_own'] != true) {
    ChatService.markRead(id);  // fire-and-forget OK
  }
}
```

Hoặc đơn giản hơn: gọi 1 lần mark-all-read qua API khi enter room (backend cần endpoint này).

### 6.8 `image_picker` trên Web không có `path` – kIsWeb branch đã đúng nhưng `name` fallback cần kiểm tra

Trong `uploadMedia`, khi `kIsWeb`:
```dart
final bytes = await pickedFile.readAsBytes();
multipartFile = MultipartFile.fromBytes(bytes, filename: name.isNotEmpty ? name : 'image.jpg');
```
Trên web, `pickedFile.name` thường có giá trị → OK. Nhưng nên test kỹ.

---

## Tóm tắt ưu tiên

| # | Vấn đề | Độ ưu tiên | Effort |
|---|--------|-----------|--------|
| 1 | Ảnh chat hiển thị `[Image]` | 🔴 Critical | M |
| 2 | Tin nhắn không real-time (WS reconnect + polling) | 🔴 Critical | M |
| 3 | Avatar user hiển thị sai | 🟡 High | S |
| 4 | Tìm user để chat trực tiếp từ ChatRooms | 🟡 High | M |
| 5 | CRUD phòng chat | 🟠 Medium | L |
| 6 | `_pendingSent` luôn rỗng | 🟡 High | S |
| 7 | `createRoom` existing room bug | 🔴 Critical (phía backend) | S |
| 8 | `markRead` không được gọi | 🟠 Medium | S |
| 9 | WS thiếu `message_type` trong broadcast | 🔴 Critical (phía backend) | S |
