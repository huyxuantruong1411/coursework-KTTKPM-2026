# 📱 FLUTTER APP – HƯỚNG DẪN PHÁT TRIỂN CHO AI AGENT
> **Dự án:** `ktgk_2324802010044` – Manga Reader App (Flutter)  
> **Phân tích đầy đủ từ:** `flutter_project_dump.txt`, `project_dump.md` (frontend), `project_dump.txt` (backend)  
> **Mục đích:** Tài liệu này dùng để AI agent đọc và thực hiện fix lỗi + bổ sung tính năng còn thiếu.

---

## 📋 MỤC LỤC

1. [Kiến trúc tổng quan](#1-kiến-trúc-tổng-quan)
2. [🔴 Lỗi CRASH – Fix ngay](#2--lỗi-crash--fix-ngay)
3. [🟠 Lỗi BUG – Logic sai](#3--lỗi-bug--logic-sai)
4. [🟡 Lỗi WARN – UX kém / Data thiếu](#4--lỗi-warn--ux-kém--data-thiếu)
5. [✨ Tính năng còn thiếu – Bổ sung mới](#5--tính-năng-còn-thiếu--bổ-sung-mới)
6. [📦 Dependencies cần thêm vào pubspec.yaml](#6--dependencies-cần-thêm-vào-pubspecyaml)
7. [Thứ tự thực hiện đề nghị](#7-thứ-tự-thực-hiện-đề-nghị)

---

## 1. Kiến trúc tổng quan

```
lib/
├── core/
│   ├── constants.dart        # BASE_URL, headers
│   ├── dio_client.dart       # Dio singleton với JWT interceptor
│   └── token_storage.dart    # SharedPreferences token storage
├── models/
│   ├── manga.dart            # Manga model + fromJson()
│   ├── chapter.dart
│   ├── manga_list.dart       # MangaListBrief model
│   ├── reading_history.dart
│   └── user.dart
├── providers/
│   ├── app_provider.dart     # Lists, reading history, etc.
│   └── auth_provider.dart    # Auth state
├── screens/
│   ├── main_tab_screen.dart  # Bottom nav (6 tabs)
│   ├── auth/auth_screen.dart
│   ├── chat/chat_screen.dart         # ChatRoomsScreen + ChatScreen
│   ├── creator/creator_screen.dart   # 🔴 CÓ BUG CRASH
│   ├── detail/detail_screen.dart     # 3 tabs (thiếu: comments, recommendations)
│   ├── explore/explore_screen.dart
│   ├── explore/search_screen.dart    # 🟠 parse key sai
│   ├── friends/friends_screen.dart   # 🟠 nhiều lỗi logic
│   ├── history/history_screen.dart
│   ├── library/library_screen.dart
│   ├── library/list_detail_screen.dart
│   ├── profile/profile_screen.dart
│   ├── profile/settings_screen.dart
│   └── reader/reader_screen.dart
└── services/
    ├── analytics_service.dart   # Stub – chỉ có print, không gọi backend
    ├── auth_service.dart
    ├── chapter_service.dart     # ✅ Đúng
    ├── chat_service.dart        # ✅ Đúng
    ├── comment_service.dart     # ✅ Service đúng nhưng KHÔNG có UI
    ├── creator_service.dart     # ✅ Đúng
    ├── friend_service.dart      # ✅ Đúng
    ├── history_service.dart     # ✅ Đúng
    ├── list_service.dart        # ✅ Đúng
    ├── mangadex_api.dart        # ✅ Đúng
    ├── manga_service.dart       # 🟡 minor issues
    ├── rating_service.dart      # ✅ Đúng
    └── supabase_service.dart
    # ❌ THIẾU: recommendation_service.dart
    # ❌ THIẾU: download_service.dart
```

**Backend base URL:** `http://<host>/api/v1`  
**MangaDex API:** `https://api.mangadex.org`  
**Design màu sắc:** Orange `#FF6740`, Card bg `#2C2C2C`, Screen bg `#121212`

---

## 2. 🔴 Lỗi CRASH – Fix ngay

### BUG-01 – `creator_screen.dart`: Constructor thiếu param `creatorId` → CRASH ngay khi tap tác giả

**File:** `lib/screens/creator/creator_screen.dart`

**Hiện tại (SAI):**
```dart
class CreatorScreen extends StatefulWidget {
  final String creatorName;
  const CreatorScreen({super.key, required this.creatorName});
}
```

**`detail_screen.dart` đang gọi (gây crash compile):**
```dart
CreatorScreen(creatorId: creator?['id']?.toString(), creatorName: name)
```

**FIX:**
```dart
class CreatorScreen extends StatefulWidget {
  final String? creatorId;   // ← THÊM field này
  final String creatorName;
  const CreatorScreen({super.key, this.creatorId, required this.creatorName});
  @override
  State<CreatorScreen> createState() => _CreatorScreenState();
}
```

---

### BUG-02 – `creator_screen.dart`: `_loadMangas()` gọi API sai, parse key sai

**File:** `lib/screens/creator/creator_screen.dart`

**Hiện tại (SAI):**
```dart
final res = await MangaService.getMangaList(query: widget.creatorName);
final list = ((res['manga'] ?? []) as List)  // 'manga' không tồn tại trong backend response!
```

**FIX:**
```dart
// Thêm imports ở đầu file:
import '../../services/creator_service.dart';
import '../../services/mangadex_api.dart';

Future<void> _loadMangas() async {
  setState(() => _isLoading = true);
  try {
    if (widget.creatorId != null && widget.creatorId!.isNotEmpty) {
      // Dùng CreatorService nếu có ID (gọi GET /api/v1/creators/{id})
      final res = await CreatorService.getCreatorDetail(widget.creatorId!);
      final mangas = ((res?['mangas']?['items'] ?? []) as List)
          .cast<Map<String, dynamic>>()
          .map((e) => Manga.fromJson(e))
          .toList();
      if (mounted) setState(() { _mangas = mangas; _isLoading = false; });
    } else {
      // Fallback: search qua MangaDex API trực tiếp
      final results = await MangaDexApi().searchManga(
        query: widget.creatorName, limit: 20,
      );
      if (mounted) setState(() { _mangas = results; _isLoading = false; });
    }
  } catch (e) {
    if (mounted) setState(() => _isLoading = false);
  }
}
```

---

## 3. 🟠 Lỗi BUG – Logic sai

### BUG-03 – `search_screen.dart`: Dùng method sai + parse key sai

**File:** `lib/screens/explore/search_screen.dart`

**Hiện tại (SAI):**
```dart
final res = await MangaService.getMangaList(
  query: query, tag: _includedTags.isNotEmpty ? _includedTags.join(',') : null, ...
);
final results = ((res['manga'] ?? []) as List)  // KEY SAI! Backend trả 'items'
```

**FIX:**
```dart
final res = await MangaService.searchManga(
  query: query,
  includeTags: _includedTags.isNotEmpty ? _includedTags : null,
  excludeTags: _excludedTags.isNotEmpty ? _excludedTags : null,
  status: _statuses.isNotEmpty ? _statuses.first : null,
  contentRating: _contentRatings.isNotEmpty ? _contentRatings.first : null,
  demographic: _demographics.isNotEmpty ? _demographics.first : null,
  year: _year,
  sort: sortKey,
);
final results = ((res['items'] ?? []) as List)  // ← đổi 'manga' → 'items'
    .cast<Map<String, dynamic>>()
    .map((e) => Manga.fromJson(e))
    .toList();
```

---

### BUG-04 – `friends_screen.dart`: Accept/Reject dùng `request_id` thay vì `user_id`

**File:** `lib/screens/friends/friends_screen.dart`

**Vấn đề:** Backend `/friends/requests` trả về `{user_id, username, avatar, display_name, requested_at}`. **Không có** field `RequestId` hay `request_id`.

**FIX:**
```dart
// Tìm chỗ gọi acceptRequest/rejectRequest trong _buildRequestItem():

// SAI:
final reqId = r['RequestId']?.toString() ?? r['request_id']?.toString() ?? '';
await FriendService.acceptRequest(reqId);

// ĐÚNG:
final userId = r['user_id']?.toString() ?? r['UserId']?.toString() ?? '';
await FriendService.acceptRequest(userId);
await FriendService.rejectRequest(userId);
```

---

### BUG-05 – `friends_screen.dart`: Mở chat dùng `friendId` làm `roomId`

**File:** `lib/screens/friends/friends_screen.dart`

**Vấn đề:** `friendId` là UUID của user, không phải `roomId` của chat room. Mở `ChatScreen(roomId: friendId)` sẽ gửi message vào room không tồn tại.

**FIX:** Thêm method `_openDirectChat()`:
```dart
Future<void> _openDirectChat(String friendId, String friendName) async {
  try {
    // Tạo hoặc tìm DM room qua API
    final result = await ChatService.createRoom(
      type: 'direct',
      userIds: [friendId],
    );
    if (!mounted) return;
    final roomId = result?['room_id']?.toString()
        ?? result?['id']?.toString()
        ?? result?['RoomId']?.toString()
        ?? '';
    if (roomId.isNotEmpty) {
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => ChatScreen(roomId: roomId, roomName: friendName),
      ));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không thể mở chat lúc này')),
      );
    }
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi mở chat: $e')),
      );
    }
  }
}

// Thay thế chỗ tap vào friend button:
// onPressed: () => _openDirectChat(friendId, name)
```

---

### BUG-06 – `manga_service.dart`: Primary search endpoint sai (hit 404 rồi mới fallback)

**File:** `lib/services/manga_service.dart`

**Hiện tại (SAI – lãng phí 1 request):**
```dart
// Luôn hit 404 trước vì /mangas/advanced-search không tồn tại
final response = await _dio.get('/mangas/advanced-search', queryParameters: params);
```

**FIX:**
```dart
// Đổi thẳng sang endpoint đúng:
final response = await _dio.get('/mangas/search', queryParameters: params);
return _normalizePaginated(response.data);
```

---

### BUG-07 – `manga_service.dart`: Sort param sai trong `getRecentManga()`

**File:** `lib/services/manga_service.dart`

**FIX:**
```dart
static Future<List<Map<String, dynamic>>> getRecentManga({int limit = 20}) async {
  try {
    final response = await _dio.get('/mangas/', queryParameters: {
      'limit': limit,
      'sort': 'updated_desc',  // ← đổi từ 'recent' → 'updated_desc'
    });
    final data = response.data as Map<String, dynamic>;
    return (data['items'] as List? ?? []).cast<Map<String, dynamic>>();
  } on DioException catch (e) {
    debugPrint('MangaService.getRecentManga error: ${e.response?.data}');
    return [];
  }
}
```

---

## 4. 🟡 Lỗi WARN – UX kém / Data thiếu

### WARN-01 – `manga_list.dart`: Model thiếu field `containsManga`

**File:** `lib/models/manga_list.dart`

**FIX:** Thêm field optional vào `MangaListBrief`:
```dart
class MangaListBrief {
  // ... các field hiện có ...
  final bool? containsManga;  // ← THÊM

  MangaListBrief({
    // ... các param hiện có ...
    this.containsManga,        // ← THÊM
  });

  factory MangaListBrief.fromJson(Map<String, dynamic> json) {
    return MangaListBrief(
      // ... parse hiện có ...
      containsManga: json['contains_manga'] as bool?,  // ← THÊM
    );
  }
}
```

---

### WARN-02 – `app_provider.dart`: `getListsContainingManga()` luôn trả về rỗng

**File:** `lib/providers/app_provider.dart`

**Hiện tại (SAI – `MangaListBrief` không có field `contains`):**
```dart
return lists.where((l) => l.contains == true).map((l) => l.listId).toList();
```

**FIX (sau khi fix WARN-01):**
```dart
Future<List<String>> getListsContainingManga(String mangaId) async {
  try {
    final res = await ListService.getMyLists(mangaId: mangaId);
    final lists = (res['my_lists'] as List? ?? [])
        .map((e) => MangaListBrief.fromJson(e as Map<String, dynamic>))
        .toList();
    return lists
        .where((l) => l.containsManga == true)
        .map((l) => l.listId)
        .toList();
  } catch (e) {
    return [];
  }
}
```

---

### WARN-03 – `friends_screen.dart`: Tab "Đã gửi" luôn rỗng (backend không hỗ trợ)

**File:** `lib/screens/friends/friends_screen.dart`

**FIX:** Thêm placeholder message vào `_buildPendingSent()`:
```dart
Widget _buildPendingSent() {
  return const Center(
    child: Padding(
      padding: EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.hourglass_empty_rounded, color: Colors.white24, size: 48),
          SizedBox(height: 12),
          Text(
            'Tính năng xem lời mời đã gửi\nchưa được hỗ trợ.',
            style: TextStyle(color: Colors.white38, fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}
```

---

### WARN-04 – `manga.dart` model: CoverUrl trả về localhost URL sẽ không load trên mobile

**File:** `lib/models/manga.dart`

**FIX:** Thêm helper trong `Manga.fromJson()`:
```dart
factory Manga.fromJson(Map<String, dynamic> json) {
  final rawCoverUrl = json['cover_url']?.toString()
      ?? json['CoverUrl']?.toString()
      ?? json['coverUrl']?.toString()
      ?? '';
  final mangaId = json['MangaId']?.toString()
      ?? json['manga_id']?.toString()
      ?? json['id']?.toString()
      ?? '';

  return Manga(
    // ...
    coverUrl: _sanitizeCoverUrl(rawCoverUrl, mangaId),
    // ...
  );
}

static String _sanitizeCoverUrl(String rawUrl, String mangaId) {
  if (rawUrl.isEmpty) {
    return 'https://via.placeholder.com/256x360?text=No+Cover';
  }
  // Nếu URL là localhost/127.0.0.1 → không load được trên device/emulator
  if (rawUrl.contains('localhost') || rawUrl.contains('127.0.0.1')) {
    // Trả về placeholder vì không có coverFileName riêng lẻ
    return 'https://via.placeholder.com/256x360?text=No+Cover';
  }
  return rawUrl;
}
```

---

### WARN-05 – `chat_screen.dart`: `_myUserId` có thể null nếu chưa đăng nhập

**File:** `lib/screens/chat/chat_screen.dart` (trong `_ChatScreenState`)

**FIX:** Thêm guard trong `initState()`:
```dart
@override
void initState() {
  super.initState();
  _loadMyUserId().then((_) {
    if (_myUserId == null || _myUserId!.isEmpty) {
      // Redirect về auth nếu chưa đăng nhập
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pushReplacementNamed('/auth');
      });
      return;
    }
    _connect();
    _loadMessages();
  });
}
```

---

## 5. ✨ Tính năng còn thiếu – Bổ sung mới

---

### FEAT-01 – Comments Tab trong `detail_screen.dart`

**Trạng thái:** `CommentService` đã có đầy đủ endpoints, nhưng **hoàn toàn không có UI** trong `detail_screen.dart`. Frontend (Next.js) có `CommentsSection` component đầy đủ với: đăng bình luận, spoiler toggle, like/dislike, edit, delete, report.

**File cần sửa:** `lib/screens/detail/detail_screen.dart`

**Bước 1 – Thêm imports:**
```dart
import '../../services/comment_service.dart';
```

**Bước 2 – Đổi TabController length từ 3 → 4, thêm tab Comments:**
```dart
// Trong initState():
_tabController = TabController(length: 4, vsync: this);  // ← 3 → 4

// Trong onTap:
onTap: (i) {
  if (i == 2) _loadCovers();
  // Tab 3 (comments) tự load khi build
},

// Trong tabs array:
tabs: const [
  Tab(icon: Icon(Icons.info_outline, size: 18), text: 'Thông tin'),
  Tab(icon: Icon(Icons.list_alt, size: 18), text: 'Chương'),
  Tab(icon: Icon(Icons.photo_library_outlined, size: 18), text: 'Cover Art'),
  Tab(icon: Icon(Icons.chat_bubble_outline, size: 18), text: 'Bình luận'),  // ← THÊM
],

// Trong TabBarView children:
children: [
  _buildInfoTab(manga),
  _buildChaptersTab(manga),
  _buildCoversTab(),
  _buildCommentsTab(),  // ← THÊM
],
```

**Bước 3 – Thêm state variables vào `_DetailScreenState`:**
```dart
List<Map<String, dynamic>> _comments = [];
bool _commentsLoading = false;
bool _commentsLoaded = false;
final _commentController = TextEditingController();
bool _commentIsSpoiler = false;
bool _postingComment = false;
int? _editingCommentIndex;
String _editDraft = '';
```

**Bước 4 – Thêm method `_loadComments()` và `_postComment()`:**
```dart
Future<void> _loadComments() async {
  if (_commentsLoaded) return;
  setState(() => _commentsLoading = true);
  try {
    final res = await CommentService.getComments(widget.manga.id, limit: 50);
    if (mounted) {
      setState(() {
        _comments = (res['items'] as List? ?? []).cast<Map<String, dynamic>>();
        _commentsLoading = false;
        _commentsLoaded = true;
      });
    }
  } catch (e) {
    if (mounted) setState(() => _commentsLoading = false);
  }
}

Future<void> _postComment() async {
  final content = _commentController.text.trim();
  if (content.length < 5) return;
  setState(() => _postingComment = true);
  try {
    final res = await CommentService.postComment(
      widget.manga.id, content, isSpoiler: _commentIsSpoiler,
    );
    if (res != null && mounted) {
      final newComment = res['comment'] as Map<String, dynamic>?;
      if (newComment != null) {
        setState(() {
          _comments.insert(0, newComment);
          _commentController.clear();
          _commentIsSpoiler = false;
        });
      }
    }
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi đăng bình luận: $e'), backgroundColor: Colors.red),
      );
    }
  } finally {
    if (mounted) setState(() => _postingComment = false);
  }
}
```

**Bước 5 – Đăng ký lazy load trong `_tabController` listener (trong `initState()`):**
```dart
_tabController.addListener(() {
  if (_tabController.index == 3) _loadComments();
});
```

**Bước 6 – Tạo `_buildCommentsTab()` widget:**
```dart
Widget _buildCommentsTab() {
  final auth = context.watch<AppProvider>();
  final isLoggedIn = auth.isLoggedIn; // hoặc dùng Provider<AuthProvider>

  return ListView(
    padding: const EdgeInsets.all(16),
    children: [
      // ── Ô nhập bình luận ──
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _commentController,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              maxLines: 3,
              enabled: isLoggedIn,
              decoration: InputDecoration(
                hintText: isLoggedIn ? 'Chia sẻ suy nghĩ của bạn...' : 'Đăng nhập để bình luận',
                hintStyle: const TextStyle(color: Colors.white38),
                border: InputBorder.none,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Row(
                  children: [
                    Checkbox(
                      value: _commentIsSpoiler,
                      onChanged: isLoggedIn
                          ? (v) => setState(() => _commentIsSpoiler = v ?? false)
                          : null,
                      activeColor: _kOrange,
                    ),
                    const Text('Spoiler', style: TextStyle(color: Colors.white70, fontSize: 13)),
                  ],
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: (isLoggedIn && !_postingComment)
                      ? _postComment
                      : null,
                  icon: _postingComment
                      ? const SizedBox(
                          width: 14, height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.send, size: 16),
                  label: const Text('Đăng', style: TextStyle(fontSize: 13)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kOrange,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),

      // ── Danh sách bình luận ──
      if (_commentsLoading)
        const Center(child: CircularProgressIndicator(color: _kOrange))
      else if (_comments.isEmpty)
        const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text('Chưa có bình luận. Hãy là người đầu tiên!',
              style: TextStyle(color: Colors.white38)),
          ),
        )
      else
        ..._comments.asMap().entries.map((entry) =>
          _buildCommentItem(entry.value, entry.key)),
    ],
  );
}

Widget _buildCommentItem(Map<String, dynamic> comment, int index) {
  final commentId = comment['CommentId']?.toString() ?? comment['comment_id']?.toString() ?? '';
  final username = comment['Username']?.toString() ?? comment['username']?.toString() ?? 'Ẩn danh';
  final content = comment['Content']?.toString() ?? '';
  final isSpoiler = comment['IsSpoiler'] as bool? ?? false;
  final likeCount = comment['LikeCount'] as int? ?? 0;
  final dislikeCount = comment['DislikeCount'] as int? ?? 0;
  final createdAt = comment['CreatedAt']?.toString() ?? '';
  final isEditing = _editingCommentIndex == index;

  // TODO: lấy currentUserId từ AuthProvider để check canManage
  // final canManage = comment['UserId'] == currentUser?.userId;

  return Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: _kCard,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: _kOrange.withValues(alpha: 0.2),
              child: Text(
                username.isNotEmpty ? username[0].toUpperCase() : 'U',
                style: const TextStyle(color: _kOrange, fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
            const SizedBox(width: 8),
            Text(username, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
            if (isSpoiler) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text('Spoiler', style: TextStyle(color: Colors.amber, fontSize: 11)),
              ),
            ],
            const Spacer(),
            if (createdAt.isNotEmpty)
              Text(_formatDate(createdAt), style: const TextStyle(color: Colors.white38, fontSize: 11)),
          ],
        ),
        const SizedBox(height: 8),
        if (isEditing)
          Column(
            children: [
              TextField(
                onChanged: (v) => _editDraft = v,
                controller: TextEditingController(text: _editDraft),
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.black26,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  ElevatedButton(
                    onPressed: () async {
                      if (commentId.isEmpty) return;
                      try {
                        await CommentService.updateComment(commentId, _editDraft);
                        setState(() {
                          _comments[index]['Content'] = _editDraft;
                          _editingCommentIndex = null;
                        });
                      } catch (e) {
                        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Lỗi cập nhật: $e')),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: _kOrange, foregroundColor: Colors.white),
                    child: const Text('Lưu', style: TextStyle(fontSize: 12)),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () => setState(() => _editingCommentIndex = null),
                    child: const Text('Hủy', style: TextStyle(color: Colors.white54, fontSize: 12)),
                  ),
                ],
              ),
            ],
          )
        else
          Text(
            isSpoiler ? '⚠️ Nội dung spoiler – nhấn để xem' : content,
            style: TextStyle(
              color: isSpoiler ? Colors.amber : Colors.white70,
              fontSize: 13,
              height: 1.5,
            ),
          ),
        const SizedBox(height: 8),
        Row(
          children: [
            // Like
            InkWell(
              onTap: () async {
                if (commentId.isEmpty) return;
                try {
                  final res = await CommentService.likeComment(commentId);
                  setState(() {
                    _comments[index]['LikeCount'] = res['like_count'];
                    _comments[index]['DislikeCount'] = res['dislike_count'];
                  });
                } catch (_) {}
              },
              child: Row(
                children: [
                  const Icon(Icons.thumb_up_alt_outlined, color: Colors.white38, size: 16),
                  const SizedBox(width: 4),
                  Text('$likeCount', style: const TextStyle(color: Colors.white38, fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Dislike
            InkWell(
              onTap: () async {
                if (commentId.isEmpty) return;
                try {
                  final res = await CommentService.dislikeComment(commentId);
                  setState(() {
                    _comments[index]['LikeCount'] = res['like_count'];
                    _comments[index]['DislikeCount'] = res['dislike_count'];
                  });
                } catch (_) {}
              },
              child: Row(
                children: [
                  const Icon(Icons.thumb_down_alt_outlined, color: Colors.white38, size: 16),
                  const SizedBox(width: 4),
                  Text('$dislikeCount', style: const TextStyle(color: Colors.white38, fontSize: 12)),
                ],
              ),
            ),
            const Spacer(),
            // Edit & Delete (chỉ hiện nếu là chủ comment – cần check userId)
            // Tạm hiện nút report
            InkWell(
              onTap: () => _showReportCommentDialog(commentId),
              child: const Icon(Icons.flag_outlined, color: Colors.white24, size: 16),
            ),
          ],
        ),
      ],
    ),
  );
}

void _showReportCommentDialog(String commentId) {
  final reasons = ['Spam', 'Quấy rối', 'Spoiler không được đánh dấu', 'Nội dung không phù hợp', 'Thông tin sai', 'Khác'];
  String? selectedReason;
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: _kCard,
      title: const Text('Báo cáo bình luận', style: TextStyle(color: Colors.white)),
      content: StatefulBuilder(
        builder: (ctx, setS) => Column(
          mainAxisSize: MainAxisSize.min,
          children: reasons.map((r) => RadioListTile<String>(
            title: Text(r, style: const TextStyle(color: Colors.white70, fontSize: 13)),
            value: r,
            groupValue: selectedReason,
            activeColor: _kOrange,
            onChanged: (v) => setS(() => selectedReason = v),
          )).toList(),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy', style: TextStyle(color: Colors.white54))),
        ElevatedButton(
          onPressed: selectedReason == null ? null : () async {
            Navigator.pop(ctx);
            try {
              await CommentService.reportComment(commentId, selectedReason!);
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Đã gửi báo cáo!'), backgroundColor: Colors.green),
              );
            } catch (e) {
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
              );
            }
          },
          style: ElevatedButton.styleFrom(backgroundColor: _kOrange),
          child: const Text('Gửi báo cáo', style: TextStyle(color: Colors.white)),
        ),
      ],
    ),
  );
}

String _formatDate(String iso) {
  try {
    final dt = DateTime.parse(iso).toLocal();
    return '${dt.day}/${dt.month}/${dt.year}';
  } catch (_) {
    return iso;
  }
}
```

---

### FEAT-02 – Recommendations Tab trong `detail_screen.dart`

**Trạng thái:** `recommendation_service.dart` **chưa tồn tại**. Backend có endpoint `GET /api/v1/recommendations/manga/{id}/similar`. Frontend đã có tab này.

**Bước 1 – Tạo file `lib/services/recommendation_service.dart`:**
```dart
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../core/dio_client.dart';
import '../models/manga.dart';
import 'mangadex_api.dart';

class RecommendationService {
  static final _dio = DioClient.instance;
  static final _mdxApi = MangaDexApi();

  /// GET /recommendations/manga/{id}/similar?limit=20
  /// Trả về list manga gợi ý từ backend (proxy MangaDex recommendation API)
  static Future<List<Manga>> getSimilarManga(
    String mangaId, {
    int limit = 20,
  }) async {
    try {
      final response = await _dio.get(
        '/recommendations/manga/$mangaId/similar',
        queryParameters: {'limit': limit},
      );
      final data = response.data as Map<String, dynamic>;
      final items = (data['recommendations'] as List? ?? [])
          .cast<Map<String, dynamic>>();

      // items chỉ có manga_id và score, cần enrich từ MangaDex API
      final enriched = <Manga>[];
      for (final item in items.take(limit)) {
        final recMangaId = item['manga_id']?.toString() ?? '';
        if (recMangaId.isEmpty) continue;
        try {
          final manga = await _mdxApi.getMangaDetail(recMangaId);
          if (manga != null) enriched.add(manga);
        } catch (_) {}
      }
      return enriched;
    } on DioException catch (e) {
      debugPrint('RecommendationService.getSimilarManga error: ${e.response?.data}');
      return [];
    }
  }

  /// GET /recommendations/for-me?top_n=20
  /// Personalized recommendations (collaborative filtering) – requires auth
  static Future<List<Manga>> getForMe({int topN = 20}) async {
    try {
      final response = await _dio.get(
        '/recommendations/for-me',
        queryParameters: {'top_n': topN},
      );
      final data = response.data as Map<String, dynamic>;
      final items = (data['recommendations'] as List? ?? [])
          .cast<Map<String, dynamic>>();

      return items
          .map((item) {
            try {
              return Manga.fromJson(item);
            } catch (_) {
              return null;
            }
          })
          .whereType<Manga>()
          .toList();
    } on DioException catch (e) {
      debugPrint('RecommendationService.getForMe error: ${e.response?.data}');
      return [];
    }
  }
}
```

**Bước 2 – Thêm tab vào `detail_screen.dart`:**

Thêm vào `_DetailScreenState`:
```dart
List<Manga> _recommendations = [];
bool _recsLoading = false;
bool _recsLoaded = false;
```

Thêm method load:
```dart
Future<void> _loadRecommendations() async {
  if (_recsLoaded) return;
  setState(() => _recsLoading = true);
  try {
    final recs = await RecommendationService.getSimilarManga(widget.manga.id);
    if (mounted) setState(() { _recommendations = recs; _recsLoading = false; _recsLoaded = true; });
  } catch (_) {
    if (mounted) setState(() => _recsLoading = false);
  }
}
```

Cập nhật `TabController` length lên **5** (hoặc **4** nếu chỉ muốn Recs, không có Comments):
```dart
_tabController = TabController(length: 5, vsync: this);
```

Cập nhật `onTap`:
```dart
onTap: (i) {
  if (i == 2) _loadCovers();
  if (i == 3) _loadComments();
  if (i == 4) _loadRecommendations();
},
```

Thêm tab và view:
```dart
// Tabs:
Tab(icon: Icon(Icons.recommend_outlined, size: 18), text: 'Gợi ý'),

// TabBarView:
_buildRecommendationsTab(),
```

**Bước 3 – Widget `_buildRecommendationsTab()`:**
```dart
Widget _buildRecommendationsTab() {
  if (_recsLoading) {
    return const Center(child: CircularProgressIndicator(color: _kOrange));
  }
  if (_recommendations.isEmpty) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'Chưa có gợi ý từ cộng đồng cho manga này.',
          style: TextStyle(color: Colors.white38),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
  return GridView.builder(
    padding: const EdgeInsets.all(12),
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 3,
      childAspectRatio: 0.6,
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
    ),
    itemCount: _recommendations.length,
    itemBuilder: (ctx, i) {
      final rec = _recommendations[i];
      return GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => DetailScreen(manga: rec)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: CachedNetworkImage(
                  imageUrl: rec.coverUrl,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  errorWidget: (_, _, _) => Container(
                    color: _kCard,
                    child: const Icon(Icons.broken_image, color: Colors.white24),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              rec.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 11, height: 1.3),
            ),
            Text(
              rec.status.toUpperCase(),
              style: const TextStyle(color: Colors.white38, fontSize: 10),
            ),
          ],
        ),
      );
    },
  );
}
```

---

### FEAT-03 – Zoom & Download ảnh trong Chat

**Trạng thái:** Chat images hiện tại chỉ dùng `CachedNetworkImage` trong `ClipRRect`, không có gesture nào để zoom hoặc tải về.

**File cần sửa:** `lib/screens/chat/chat_screen.dart`

**Bước 1 – Thêm dependency vào `pubspec.yaml`:**
```yaml
dependencies:
  photo_view: ^0.15.0
  dio: ^5.4.0          # đã có
  path_provider: ^2.1.3
  permission_handler: ^11.3.1
```

**Bước 2 – Bọc ảnh trong chat với `GestureDetector`:**

Tìm đoạn render image message trong `_buildMsg()`:
```dart
// TRƯỚC (không có gesture):
if (messageType == 'image' && mediaUrl.isNotEmpty)
  ClipRRect(
    borderRadius: BorderRadius.circular(10),
    child: CachedNetworkImage(
      imageUrl: mediaUrl,
      width: imageWidth,
      fit: BoxFit.cover,
      ...
    ),
  )

// SAU (có tap to zoom + long press to download):
if (messageType == 'image' && mediaUrl.isNotEmpty)
  GestureDetector(
    onTap: () => _openImageViewer(mediaUrl),
    onLongPress: () => _showImageOptions(mediaUrl),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: CachedNetworkImage(
        imageUrl: mediaUrl,
        width: imageWidth,
        fit: BoxFit.cover,
        placeholder: (context, url) => _imagePlaceholder(imageWidth),
        errorWidget: (context, url, error) => _imageError(imageWidth),
      ),
    ),
  )
```

**Bước 3 – Thêm methods mở viewer và options:**
```dart
import 'dart:io';
import 'package:dio/dio.dart' as dio_pkg;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:photo_view/photo_view.dart';

void _openImageViewer(String url) {
  Navigator.push(
    context,
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => _ImageViewerPage(imageUrl: url),
    ),
  );
}

void _showImageOptions(String url) {
  showModalBottomSheet(
    context: context,
    backgroundColor: const Color(0xFF2C2C2C),
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.zoom_in, color: Colors.white70),
            title: const Text('Xem ảnh', style: TextStyle(color: Colors.white)),
            onTap: () { Navigator.pop(ctx); _openImageViewer(url); },
          ),
          ListTile(
            leading: const Icon(Icons.download_rounded, color: Colors.white70),
            title: const Text('Tải ảnh xuống', style: TextStyle(color: Colors.white)),
            onTap: () { Navigator.pop(ctx); _downloadImage(url); },
          ),
        ],
      ),
    ),
  );
}

Future<void> _downloadImage(String url) async {
  // Xin quyền storage (Android)
  if (Platform.isAndroid) {
    final status = await Permission.storage.request();
    if (!status.isGranted) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cần quyền truy cập bộ nhớ để tải ảnh')),
      );
      return;
    }
  }
  try {
    final dir = await getApplicationDocumentsDirectory();
    final fileName = 'chat_image_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final savePath = '${dir.path}/$fileName';
    final dioInstance = dio_pkg.Dio();
    await dioInstance.download(url, savePath);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã tải ảnh: $fileName'),
          backgroundColor: Colors.green,
          action: SnackBarAction(label: 'OK', textColor: Colors.white, onPressed: () {}),
        ),
      );
    }
  } catch (e) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Tải ảnh thất bại: $e'), backgroundColor: Colors.red),
    );
  }
}
```

**Bước 4 – Tạo `_ImageViewerPage` (có thể đặt ở cuối file):**
```dart
class _ImageViewerPage extends StatelessWidget {
  final String imageUrl;
  const _ImageViewerPage({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.download_rounded, color: Colors.white),
            onPressed: () async {
              // Gọi download logic tương tự ở trên
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Đang tải ảnh...')),
              );
            },
          ),
        ],
      ),
      body: PhotoView(
        imageProvider: CachedNetworkImageProvider(imageUrl),
        minScale: PhotoViewComputedScale.contained,
        maxScale: PhotoViewComputedScale.covered * 4.0,
        backgroundDecoration: const BoxDecoration(color: Colors.black),
        loadingBuilder: (_, _) => const Center(
          child: CircularProgressIndicator(color: Color(0xFFFF6740)),
        ),
        errorBuilder: (_, _, _) => const Center(
          child: Icon(Icons.broken_image, color: Colors.white24, size: 60),
        ),
      ),
    );
  }
}
```

---

### FEAT-04 – Tính năng đóng gói & tải manga xuống

**Trạng thái:** Tính năng này **hoàn toàn chưa có** trong app. Cần thêm vào `detail_screen.dart` và tạo service mới.

**Bước 1 – Thêm dependencies:**
```yaml
dependencies:
  archive: ^3.6.1           # Zip/tạo archive
  path_provider: ^2.1.3
  permission_handler: ^11.3.1
  dio: ^5.4.0               # đã có
  share_plus: ^10.0.2       # Chia sẻ file
```

**Bước 2 – Tạo `lib/services/manga_download_service.dart`:**
```dart
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:archive/archive_io.dart';
import '../models/manga.dart';
import 'chapter_service.dart';

enum DownloadLanguage { english, vietnamese, all }
enum DownloadFormat { folderPerChapter, chapterPdf, fullMangaPdf }
enum DownloadQuality { standard, dataSaver }

class MangaDownloadOptions {
  final DownloadLanguage language;
  final DownloadFormat format;
  final DownloadQuality quality;
  final List<Map<String, dynamic>> selectedChapters;
  final String mangaTitle;

  const MangaDownloadOptions({
    required this.language,
    required this.format,
    required this.quality,
    required this.selectedChapters,
    required this.mangaTitle,
  });
}

class MangaDownloadService {
  static final _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 60),
  ));

  /// Xử lý tải manga theo options
  /// Trả về đường dẫn đến file .zip hoặc folder zip
  static Future<String> downloadManga(
    MangaDownloadOptions options, {
    void Function(double progress, String status)? onProgress,
  }) async {
    final dir = await getApplicationDocumentsDirectory();
    final safeTitle = options.mangaTitle.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
    final outDir = Directory('${dir.path}/manga_downloads/$safeTitle');
    await outDir.create(recursive: true);

    final archive = Archive();
    final chapters = options.selectedChapters;
    int totalPages = 0;
    int downloadedPages = 0;

    // Đếm tổng số trang
    for (final ch in chapters) {
      totalPages += (ch['pages'] as int? ?? 10);
    }

    for (int chIdx = 0; chIdx < chapters.length; chIdx++) {
      final chapter = chapters[chIdx];
      final chapterId = chapter['id']?.toString() ?? '';
      final chapterNum = chapter['chapter']?.toString() ?? '${chIdx + 1}';
      final chapterTitle = chapter['title']?.toString() ?? '';
      final displayName = chapterTitle.isNotEmpty
          ? 'Chapter $chapterNum - $chapterTitle'
          : 'Chapter $chapterNum';

      onProgress?.call(
        chIdx / chapters.length,
        'Đang tải $displayName...',
      );

      List<String> pageUrls;
      if (options.quality == DownloadQuality.dataSaver) {
        pageUrls = await ChapterService.getChapterPagesSaver(chapterId);
      } else {
        pageUrls = await ChapterService.getChapterPages(chapterId);
      }

      for (int pageIdx = 0; pageIdx < pageUrls.length; pageIdx++) {
        final pageUrl = pageUrls[pageIdx];
        try {
          final response = await _dio.get(
            pageUrl,
            options: Options(responseType: ResponseType.bytes),
          );
          final bytes = response.data as List<int>;
          final ext = pageUrl.endsWith('.png') ? 'png' : 'jpg';
          final pageName = 'page_${(pageIdx + 1).toString().padLeft(3, '0')}.$ext';

          switch (options.format) {
            case DownloadFormat.folderPerChapter:
              // Structure: Chapter X/page_001.jpg
              final archivePath = '$displayName/$pageName';
              archive.addFile(ArchiveFile(archivePath, bytes.length, bytes));
              break;
            case DownloadFormat.chapterPdf:
              // TODO: Tạo PDF cho từng chapter (cần thêm package pdf)
              // Tạm thời lưu ảnh thô trong folder
              archive.addFile(ArchiveFile('$displayName/$pageName', bytes.length, bytes));
              break;
            case DownloadFormat.fullMangaPdf:
              // Tất cả ảnh thô (xử lý PDF bên ngoài)
              archive.addFile(ArchiveFile('all_pages/${displayName}_$pageName', bytes.length, bytes));
              break;
          }

          downloadedPages++;
          onProgress?.call(
            downloadedPages / (totalPages > 0 ? totalPages : 1),
            'Trang ${pageIdx + 1}/${pageUrls.length} – $displayName',
          );
        } catch (e) {
          // Bỏ qua trang lỗi, tiếp tục
          downloadedPages++;
        }
      }
    }

    // Tạo file zip
    final zipPath = '${outDir.path}/$safeTitle.zip';
    final zipFile = File(zipPath);
    final encoder = ZipEncoder();
    final zipBytes = encoder.encode(archive);
    if (zipBytes != null) {
      await zipFile.writeAsBytes(zipBytes);
    }

    onProgress?.call(1.0, 'Hoàn thành!');
    return zipPath;
  }
}
```

**Bước 3 – Thêm nút Download vào `detail_screen.dart`:**

Trong `_buildHeroHeader()`, thêm action button:
```dart
// Trong Row actions buttons (cạnh nút Lưu và Đọc ngay):
_ActionBtn(
  icon: Icons.download_rounded,
  label: 'Tải về',
  onTap: _showDownloadDialog,
),
```

**Bước 4 – Tạo `_showDownloadDialog()`:**
```dart
void _showDownloadDialog() {
  if (_chapters.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Không có chapter để tải!')),
    );
    return;
  }

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _DownloadOptionsSheet(
      manga: _fullManga ?? widget.manga,
      chapters: _chapters,
    ),
  );
}
```

**Bước 5 – Widget `_DownloadOptionsSheet`:**
```dart
class _DownloadOptionsSheet extends StatefulWidget {
  final Manga manga;
  final List<Map<String, dynamic>> chapters;
  const _DownloadOptionsSheet({required this.manga, required this.chapters});

  @override
  State<_DownloadOptionsSheet> createState() => _DownloadOptionsSheetState();
}

class _DownloadOptionsSheetState extends State<_DownloadOptionsSheet> {
  DownloadLanguage _language = DownloadLanguage.english;
  DownloadFormat _format = DownloadFormat.folderPerChapter;
  DownloadQuality _quality = DownloadQuality.standard;
  bool _allChapters = true;
  final Set<String> _selectedChapterIds = {};
  bool _isDownloading = false;
  double _progress = 0;
  String _progressStatus = '';

  List<Map<String, dynamic>> get _filteredChapters {
    return widget.chapters.where((c) {
      if (_language == DownloadLanguage.english) return c['language'] == 'en';
      if (_language == DownloadLanguage.vietnamese) return c['language'] == 'vi';
      return true;
    }).toList();
  }

  List<Map<String, dynamic>> get _chaptersToDownload {
    if (_allChapters) return _filteredChapters;
    return _filteredChapters
        .where((c) => _selectedChapterIds.contains(c['id']?.toString()))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (ctx, controller) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1E1E1E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: _isDownloading
            ? _buildProgressUI()
            : _buildOptionsUI(controller),
      ),
    );
  }

  Widget _buildOptionsUI(ScrollController controller) {
    return ListView(
      controller: controller,
      padding: const EdgeInsets.all(20),
      children: [
        // Handle
        Center(
          child: Container(
            width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            const Icon(Icons.download_rounded, color: Color(0xFFFF6740)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Tải manga: ${widget.manga.title}',
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                maxLines: 2, overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // ── Ngôn ngữ ──
        _SectionLabel(label: '🌐 Ngôn ngữ'),
        const SizedBox(height: 8),
        _RadioGroup<DownloadLanguage>(
          value: _language,
          options: const [
            (DownloadLanguage.english, 'Tiếng Anh (en)'),
            (DownloadLanguage.vietnamese, 'Tiếng Việt (vi)'),
            (DownloadLanguage.all, 'Tất cả ngôn ngữ'),
          ],
          onChanged: (v) => setState(() => _language = v),
        ),
        const SizedBox(height: 16),

        // ── Định dạng ──
        _SectionLabel(label: '📁 Định dạng đầu ra'),
        const SizedBox(height: 8),
        _RadioGroup<DownloadFormat>(
          value: _format,
          options: const [
            (DownloadFormat.folderPerChapter, 'Thư mục theo chapter\n(Chapter X/ → page_001.jpg, ...)'),
            (DownloadFormat.chapterPdf, 'File .zip chứa ảnh từng chapter\n(Tương đương chapter .pdf)'),
            (DownloadFormat.fullMangaPdf, 'Toàn bộ manga gộp chung\n(all_pages/ → tất cả trang)'),
          ],
          onChanged: (v) => setState(() => _format = v),
        ),
        const SizedBox(height: 16),

        // ── Chất lượng ──
        _SectionLabel(label: '🖼️ Chất lượng ảnh'),
        const SizedBox(height: 8),
        _RadioGroup<DownloadQuality>(
          value: _quality,
          options: const [
            (DownloadQuality.standard, 'Gốc (Standard) – chất lượng cao'),
            (DownloadQuality.dataSaver, 'Data Saver – file nhỏ hơn'),
          ],
          onChanged: (v) => setState(() => _quality = v),
        ),
        const SizedBox(height: 16),

        // ── Chọn chapter ──
        _SectionLabel(label: '📚 Chapter cần tải'),
        Row(
          children: [
            Checkbox(
              value: _allChapters,
              onChanged: (v) => setState(() { _allChapters = v ?? true; _selectedChapterIds.clear(); }),
              activeColor: const Color(0xFFFF6740),
            ),
            Text(
              'Tất cả (${_filteredChapters.length} chapter)',
              style: const TextStyle(color: Colors.white70),
            ),
          ],
        ),
        if (!_allChapters) ...[
          const SizedBox(height: 8),
          Container(
            height: 200,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: _filteredChapters.length,
              itemBuilder: (_, i) {
                final ch = _filteredChapters[i];
                final id = ch['id']?.toString() ?? '';
                return CheckboxListTile(
                  dense: true,
                  value: _selectedChapterIds.contains(id),
                  title: Text(
                    'Ch. ${ch['chapter']} ${ch['title']?.isNotEmpty == true ? "– ${ch['title']}" : ""}',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                  ),
                  activeColor: const Color(0xFFFF6740),
                  onChanged: (v) => setState(() {
                    if (v == true) _selectedChapterIds.add(id);
                    else _selectedChapterIds.remove(id);
                  }),
                );
              },
            ),
          ),
        ],
        const SizedBox(height: 8),
        Text(
          '${_chaptersToDownload.length} chapter sẽ được tải',
          style: const TextStyle(color: Colors.white38, fontSize: 12),
        ),
        const SizedBox(height: 24),

        // ── Nút tải ──
        ElevatedButton.icon(
          onPressed: _chaptersToDownload.isEmpty ? null : _startDownload,
          icon: const Icon(Icons.download_rounded),
          label: Text(
            'Tải xuống (${_chaptersToDownload.length} chapter)',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFF6740),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          '⚠️ Lưu ý: Tải manga theo nguyên tắc sử dụng cá nhân. Không phân phối lại nội dung có bản quyền.',
          style: TextStyle(color: Colors.white24, fontSize: 11, height: 1.5),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildProgressUI() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.downloading_rounded, color: Color(0xFFFF6740), size: 60),
          const SizedBox(height: 24),
          Text(
            'Đang tải ${widget.manga.title}',
            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          LinearProgressIndicator(
            value: _progress,
            backgroundColor: Colors.white12,
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFF6740)),
            minHeight: 6,
            borderRadius: BorderRadius.circular(3),
          ),
          const SizedBox(height: 12),
          Text(
            '${(_progress * 100).toInt()}%',
            style: const TextStyle(color: Color(0xFFFF6740), fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            _progressStatus,
            style: const TextStyle(color: Colors.white54, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Future<void> _startDownload() async {
    // Xin quyền storage
    if (Platform.isAndroid) {
      final status = await Permission.storage.request();
      if (!status.isGranted) return;
    }

    setState(() { _isDownloading = true; _progress = 0; });

    try {
      final options = MangaDownloadOptions(
        language: _language,
        format: _format,
        quality: _quality,
        selectedChapters: _chaptersToDownload,
        mangaTitle: widget.manga.title,
      );

      final filePath = await MangaDownloadService.downloadManga(
        options,
        onProgress: (progress, status) {
          if (mounted) setState(() { _progress = progress; _progressStatus = status; });
        },
      );

      if (!mounted) return;
      Navigator.pop(context);
      // Chia sẻ hoặc mở file
      await Share.shareXFiles([XFile(filePath)], text: 'Manga: ${widget.manga.title}');
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi tải manga: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}

// Helper widgets
class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});
  @override
  Widget build(BuildContext context) => Text(
    label,
    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
  );
}

class _RadioGroup<T> extends StatelessWidget {
  final T value;
  final List<(T, String)> options;
  final void Function(T) onChanged;
  const _RadioGroup({required this.value, required this.options, required this.onChanged});

  @override
  Widget build(BuildContext context) => Column(
    children: options.map((opt) => RadioListTile<T>(
      dense: true,
      contentPadding: EdgeInsets.zero,
      value: opt.$1,
      groupValue: value,
      title: Text(opt.$2, style: const TextStyle(color: Colors.white70, fontSize: 13)),
      activeColor: const Color(0xFFFF6740),
      onChanged: (v) { if (v != null) onChanged(v); },
    )).toList(),
  );
}
```

---

## 6. 📦 Dependencies cần thêm vào `pubspec.yaml`

```yaml
dependencies:
  flutter:
    sdk: flutter

  # === ĐÃ CÓ ===
  provider: ^6.1.2
  dio: ^5.4.0
  image_picker: ^1.1.2
  cached_network_image: ^3.4.1
  cupertino_icons: ^1.0.8
  google_fonts: ^6.2.1
  flutter_markdown: ^0.7.7+1
  shared_preferences: ^2.3.2
  web_socket_channel: ^3.0.1

  # === CẦN THÊM MỚI ===

  # FEAT-03: Zoom ảnh trong chat
  photo_view: ^0.15.0

  # FEAT-03 & FEAT-04: Lưu file, path
  path_provider: ^2.1.3

  # FEAT-03 & FEAT-04: Xin quyền storage/media
  permission_handler: ^11.3.1

  # FEAT-04: Tạo file ZIP để đóng gói manga
  archive: ^3.6.1

  # FEAT-04: Chia sẻ file sau khi tải
  share_plus: ^10.0.2
```

**Android – `android/app/src/main/AndroidManifest.xml` cần thêm:**
```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE"
    android:maxSdkVersion="28" />
<!-- Android 13+ -->
<uses-permission android:name="android.permission.READ_MEDIA_IMAGES" />
```

---

## 7. Thứ tự thực hiện đề nghị

| Ưu tiên | Ticket | File | Mô tả |
|---------|--------|------|-------|
| 🔴 P1 | BUG-01 | `creator_screen.dart` | Thêm `creatorId` param (fix crash) |
| 🔴 P1 | BUG-02 | `creator_screen.dart` | Fix `_loadMangas()` |
| 🟠 P2 | BUG-03 | `search_screen.dart` | Fix parse key `'items'` |
| 🟠 P2 | BUG-04 | `friends_screen.dart` | Fix accept/reject dùng `user_id` |
| 🟠 P2 | BUG-05 | `friends_screen.dart` | Fix open DM chat tạo room đúng cách |
| 🟠 P2 | BUG-06 | `manga_service.dart` | Fix endpoint `/mangas/search` |
| 🟠 P2 | BUG-07 | `manga_service.dart` | Fix sort `updated_desc` |
| 🟡 P3 | WARN-01 | `manga_list.dart` | Thêm `containsManga` field |
| 🟡 P3 | WARN-02 | `app_provider.dart` | Fix `getListsContainingManga()` |
| 🟡 P3 | WARN-03 | `friends_screen.dart` | Placeholder tab "Đã gửi" |
| 🟡 P3 | WARN-04 | `manga.dart` | Fix localhost cover URL |
| ✨ P4 | FEAT-01 | `detail_screen.dart` | Thêm Comments tab |
| ✨ P4 | FEAT-02 | `recommendation_service.dart` + `detail_screen.dart` | Tạo service + Recommendations tab |
| ✨ P5 | FEAT-03 | `chat_screen.dart` | Zoom ảnh + tải ảnh chat |
| ✨ P5 | FEAT-04 | `manga_download_service.dart` + `detail_screen.dart` | Đóng gói & tải manga |

---

## Ghi chú quan trọng cho AI Agent

1. **Màu sắc chuẩn của app:** `_kOrange = Color(0xFFFF6740)`, `_kCard = Color(0xFF2C2C2C)`, `_kBg = Color(0xFF121212)`
2. **Tất cả API calls dùng `DioClient.instance`** với JWT token tự động từ interceptor
3. **MangaDex API calls** dùng `MangaDexApi()` trực tiếp (KHÔNG qua backend)
4. **Backend prefix:** `/api/v1/` (VD: `/api/v1/comments/manga/{id}/comments`)
5. **Response format chuẩn:** `{items: [], page: 1, per_page: 20, total: N, total_pages: M}`
6. **Không import** `flutter/foundation.dart` nếu không cần `debugPrint`
7. Sau mỗi thay đổi TabController length, đảm bảo `dispose()` vẫn gọi `_tabController.dispose()`
