# AUDIT & FIX PLAN – Flutter Manga App
> Tổng hợp kết quả kiểm tra toàn bộ source code so với backend API và MangaDex API
> Dành cho AI agent thực thi từng fix độc lập.

---

## MỨC ĐỘ KÝ HIỆU
- 🔴 **CRASH** – sẽ crash ngay, phải fix trước khi build
- 🟠 **BUG** – logic sai, feature không hoạt động
- 🟡 **WARN** – UX kém, dữ liệu thiếu/sai nhỏ
- ✅ **OK** – đã đúng

---

## KẾT QUẢ KIỂM TRA TỪNG FILE

### `lib/screens/creator/creator_screen.dart` 🔴🔴

**Lỗi 1 – Constructor thiếu `creatorId` param (CRASH NGAY)**

`detail_screen.dart` đang gọi:
```dart
CreatorScreen(creatorId: creator?['id']?.toString(), creatorName: name)
```
Nhưng `CreatorScreen` chỉ có:
```dart
const CreatorScreen({super.key, required this.creatorName});
```
→ **Đây chính là lỗi gây crash trong error log ban đầu.**

**Fix bắt buộc:**
```dart
class CreatorScreen extends StatefulWidget {
  final String? creatorId;   // thêm field này
  final String creatorName;
  const CreatorScreen({super.key, this.creatorId, required this.creatorName});
  // ...
}
```

**Lỗi 2 – `_loadMangas()` dùng sai API và parse sai response**

```dart
// HIỆN TẠI (SAI):
final res = await MangaService.getMangaList(query: widget.creatorName);
final list = ((res['manga'] ?? []) as List)  // 'manga' không tồn tại, phải là 'items'
```

```dart
// FIX:
Future<void> _loadMangas() async {
  try {
    if (widget.creatorId != null && widget.creatorId!.isNotEmpty) {
      // Dùng CreatorService nếu có ID
      final res = await CreatorService.getCreatorDetail(widget.creatorId!);
      final mangas = ((res?['mangas']?['items'] ?? []) as List)
          .cast<Map<String, dynamic>>()
          .map((e) => Manga.fromJson(e))
          .toList();
      if (mounted) setState(() { _mangas = mangas; _isLoading = false; });
    } else {
      // Fallback: search theo tên qua MangaDex API
      final results = await MangaDexApi().searchManga(query: widget.creatorName, limit: 20);
      if (mounted) setState(() { _mangas = results; _isLoading = false; });
    }
  } catch (e) {
    if (mounted) setState(() => _isLoading = false);
  }
}
```
Cần thêm imports: `../../services/creator_service.dart` và `../../services/mangadex_api.dart`

---

### `lib/screens/explore/search_screen.dart` 🟠

**`_performSearch()` dùng `getMangaList()` với params không tồn tại, và parse key sai**

```dart
// HIỆN TẠI (SAI):
final res = await MangaService.getMangaList(
  query: query, tag: _includedTags.isNotEmpty ? _includedTags.join(',') : null, ...
);
final results = ((res['manga'] ?? []) as List)  // 'manga' không tồn tại!
```

`getMangaList()` đã được sửa để redirect sang `searchManga()` khi có query/tag, nhưng response key vẫn dùng `'manga'` thay vì `'items'`.

```dart
// FIX:
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
final results = ((res['items'] ?? []) as List)  // đổi 'manga' → 'items'
    .cast<Map<String, dynamic>>()
    .map((e) => Manga.fromJson(e))
    .toList();
```

---

### `lib/screens/friends/friends_screen.dart` 🟠🟠

**Lỗi 1 – Accept/Reject dùng `request_id` thay vì `user_id`**

Backend `/friends/requests` trả về `{user_id, username, avatar, display_name, requested_at}`.
Không có field `RequestId` hay `request_id`.

```dart
// HIỆN TẠI (SAI):
final reqId = r['RequestId']?.toString() ?? r['request_id']?.toString() ?? '';
await FriendService.acceptRequest(reqId);
await FriendService.rejectRequest(reqId);

// FIX: dùng user_id thay vì request_id
final userId = r['user_id']?.toString() ?? r['UserId']?.toString() ?? '';
await FriendService.acceptRequest(userId);
await FriendService.rejectRequest(userId);
```

**Lỗi 2 – Chat với friend dùng `friendId` làm `roomId` (sai hoàn toàn)**

`friendId` là UUID của user, không phải `roomId` của chat room.

```dart
// HIỆN TẠI (SAI):
Navigator.push(context, MaterialPageRoute(
  builder: (_) => ChatScreen(roomId: friendId, roomName: name)));

// FIX: tạo/tìm DM room trước
Future<void> _openDirectChat(String friendId, String friendName) async {
  try {
    final result = await ChatService.createRoom(type: 'direct', userIds: [friendId]);
    if (!mounted) return;
    final roomId = result?['room_id']?.toString() ?? result?['id']?.toString() ?? '';
    if (roomId.isNotEmpty) {
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => ChatScreen(roomId: roomId, roomName: friendName)));
    }
  } catch (e) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Không thể mở chat: $e')));
  }
}
```
Thay `onPressed: () { Navigator.push(...)` bằng `onPressed: () => _openDirectChat(friendId, name)`.

**Lỗi 3 – Field name sai khi đọc friend data**

Backend `/friends/` trả về field `username` (lowercase), không phải `Username`.
Field `UserId` → `user_id`. Nhưng code dùng cả hai dạng nên OK với fallback hiện tại.

**Lỗi 4 – Tab "Đã gửi" sẽ luôn rỗng (không phải crash nhưng gây confusion)**

Backend không có endpoint `/friends/pending-sent`. `_pendingSent` luôn là `[]`.
→ Nên thêm label hoặc ẩn tab này:
```dart
Widget _buildPendingSent() {
  return const Center(
    child: Padding(
      padding: EdgeInsets.all(24),
      child: Text('Tính năng xem lời mời đã gửi chưa được hỗ trợ.',
        style: TextStyle(color: Colors.white38), textAlign: TextAlign.center),
    ),
  );
}
```

---

### `lib/services/manga_service.dart` 🟡

**`searchManga()` dùng `/mangas/advanced-search` với fallback về `/mangas/search`**

Backend chỉ có `/mangas/search` (xem BUG_FIX_PLAN). Endpoint `advanced-search` không tồn tại → luôn hit 404 rồi fallback. Lãng phí một request.

```dart
// FIX: đổi primary endpoint trực tiếp sang /mangas/search, bỏ try/catch 404:
final response = await _dio.get('/mangas/search', queryParameters: params);
return _normalizePaginated(response.data);
```

**`getRecentManga()` sort param sai**

Dùng `sort: 'recent'` nhưng backend nhận `sort: 'updated_desc'` (theo BUG_FIX_PLAN mục 1.3).

```dart
// FIX:
final response = await _dio.get('/mangas/', queryParameters: {
  'limit': limit,
  'sort': 'updated_desc',  // đổi từ 'recent' → 'updated_desc'
});
```

---

### `lib/screens/explore/explore_screen.dart` 🟡

**Genre filter dùng MangaDex UUID hardcode nhưng call `getMangaList()`**

`getMangaList()` hiện redirect sang `searchManga()` khi có `tag`, nên về kỹ thuật sẽ hoạt động **nếu** UUID tag trong backend trùng với MangaDex UUID.

Vì backend import từ MangaDex nên UUID **sẽ trùng**. Đây là điểm ổn nhưng cần kiểm tra thực tế.

Nếu `/mangas/search?include_tags=<uuid>` trả về kết quả rỗng thì cần load tags từ backend thay vì hardcode.

---

### `lib/screens/library/library_screen.dart` 🟡

**Public lists response key sai**

```dart
// HIỆN TẠI (cần kiểm tra):
_publicLists = ((res['lists'] ?? []) as List)...
// Backend trả PaginatedResponse với key 'items', không phải 'lists'

// FIX nếu đang dùng key 'lists':
_publicLists = ((res['items'] ?? res['lists'] ?? []) as List)...
```

---

### `lib/providers/app_provider.dart` 🟡

**`getListsContainingManga()` sẽ luôn trả về rỗng**

```dart
// HIỆN TẠI (SAI):
return lists.where((l) => l.contains == true).map((l) => l.listId).toList();
// MangaListBrief không có field 'contains'
```

Cần kiểm tra `ListService.getMyLists(mangaId: mangaId)` trả về gì từ backend khi có `manga_id` param.
Backend `/lists/?manga_id=` trả về lists với flag `contains_manga`. Cần update `MangaListBrief` model hoặc parse thêm field này.

```dart
// FIX tạm (chấp nhận feature disabled):
Future<List<String>> getListsContainingManga(String mangaId) async {
  try {
    final res = await ListService.getMyLists(mangaId: mangaId);
    final lists = res['my_lists'] ?? <MangaListBrief>[];
    // Backend trả 'contains_manga' bool trong response
    // Nếu MangaListBrief chưa có field này thì tạm return []
    return [];
  } catch (e) {
    return [];
  }
}
```

---

### `lib/screens/chat/chat_screen.dart` 🟡

**`_myUserId` có thể null nếu chưa đăng nhập**

Xem BUG_FIX_PLAN mục 12.5. Chuỗi `AuthService.login()` → `getMe()` → `saveUserInfo()` đã đúng, nhưng nếu user mở chat trực tiếp mà không qua login flow thì `_myUserId` sẽ null.

Thêm guard:
```dart
if (_myUserId == null || _myUserId!.isEmpty) {
  // Redirect về auth screen
  return;
}
```

---

### `lib/services/history_service.dart` 🟡

Cần xác nhận response structure từ `getContinueReading()`. Backend trả `{chapter_id, last_page}`, không có `chapter_number`. `getLastReadChapter()` trong `app_provider.dart` đã xử lý đúng (default `''` cho `chapter_number`).

✅ **Ổn** – `detail_screen.dart` đã có safe display logic.

---

### `lib/models/manga_list.dart` 🟡

`MangaListBrief` không có field `containsManga` (bool) tương ứng với `contains_manga` từ backend khi gọi `/lists/?manga_id=`.

```dart
// FIX: thêm field optional vào MangaListBrief:
final bool? containsManga;

// Trong fromJson():
containsManga: json['contains_manga'] as bool?,
```

Sau đó sửa `getListsContainingManga()` trong `app_provider.dart`:
```dart
return lists.where((l) => l.containsManga == true).map((l) => l.listId).toList();
```

---

## PHẦN QUAN TRỌNG: COVER & CHAPTER IMAGES (MangaDex API Integration)

### Tình trạng hiện tại
- ✅ Cover tab trong `detail_screen.dart` đã gọi `MangaDexApi().getMangaCovers()` → **hoạt động tốt**
- ✅ Chapter pages: `ChapterService.getChapterPages()` gọi backend proxy `/proxy/chapter-pages/{id}` với fallback về MangaDex at-home API → **đã có fallback đúng**
- 🟡 Cover chính (`manga.coverUrl`) lấy từ backend `/mangas/{id}` → backend tự fallback về MangaDex CDN nếu MinIO không có → **thường OK**
- 🟡 Danh sách manga ở Explore/Search: `coverUrl` từ backend response, backend trả URL từ MinIO hoặc MangaDex fallback

### Vấn đề tiềm ẩn với cover
Nếu backend trả `cover_url` là URL MinIO nội bộ (e.g. `http://localhost:9000/...`) thì Flutter mobile sẽ không load được.

**Fix:** Trong `Manga.fromJson()`, kiểm tra và fallback về MangaDex CDN:
```dart
// Trong Manga.fromJson() sau khi lấy coverUrl:
coverUrl: _buildCoverUrl(
  _string(json['cover_url'] ?? json['CoverUrl'] ?? json['coverUrl']),
  _string(json['MangaId'] ?? json['manga_id'] ?? json['id']),
),

// Helper:
static String _buildCoverUrl(String rawUrl, String mangaId) {
  if (rawUrl.isNotEmpty && !rawUrl.contains('localhost') && !rawUrl.contains('127.0.0.1')) {
    return rawUrl; // Backend đã trả URL public (MangaDex CDN)
  }
  // Fallback về MangaDex CDN nếu URL là localhost hoặc rỗng
  // Cần cover filename – không có thể lấy từ backend. Tạm return placeholder.
  return rawUrl.isNotEmpty ? rawUrl : 'https://via.placeholder.com/256x360?text=No+Cover';
}
```

**Giải pháp tốt hơn:** Dùng backend `/covers/{manga_id}/primary` endpoint để lấy cover URL đúng:

```dart
// Trong CoverService (tạo mới nếu chưa có):
static Future<String> getPrimaryCoverUrl(String mangaId) async {
  try {
    final response = await _dio.get('/covers/$mangaId/primary');
    return response.data['url']?.toString() ?? '';
  } on DioException catch (_) {
    // Fallback: MangaDex CDN (cần filename, không có → dùng mangadex API)
    return '';
  }
}
```

### Vấn đề với Chapter Pages khi backend offline
`ChapterService.getChapterPages()` đã có fallback hoàn hảo sang MangaDex at-home API qua `_fetchMangaDexPages()`. ✅

---

## THỨ TỰ FIX ĐỀ NGHỊ

### 🔴 PRIORITY 1 – Fix ngay để app build được

| # | File | Fix |
|---|------|-----|
| 1 | `creator_screen.dart` | Thêm `creatorId` param vào constructor |
| 2 | `creator_screen.dart` | Sửa `_loadMangas()` dùng `CreatorService` hoặc `MangaDexApi` |

### 🟠 PRIORITY 2 – Fix để feature hoạt động đúng

| # | File | Fix |
|---|------|-----|
| 3 | `search_screen.dart` | Đổi sang `MangaService.searchManga()`, parse key `'items'` |
| 4 | `friends_screen.dart` | Accept/Reject dùng `user_id` thay vì `request_id` |
| 5 | `friends_screen.dart` | Chat: tạo DM room trước, không dùng `friendId` làm `roomId` |
| 6 | `manga_service.dart` | Đổi primary search endpoint về `/mangas/search` |
| 7 | `manga_service.dart` | Sửa `getRecentManga()` sort param: `updated_desc` |

### 🟡 PRIORITY 3 – Cải thiện UX/data

| # | File | Fix |
|---|------|-----|
| 8 | `manga_list.dart` model | Thêm field `containsManga` |
| 9 | `app_provider.dart` | Sửa `getListsContainingManga()` dùng `containsManga` |
| 10 | `library_screen.dart` | Kiểm tra và đổi key `'lists'` → `'items'` nếu sai |
| 11 | `friends_screen.dart` | Thêm message cho tab "Đã gửi" |
| 12 | `manga.dart` model | Thêm guard cho `coverUrl` localhost → placeholder |

---

## QUICK REFERENCE – Các điểm đã ĐÚNG (không cần sửa)

- ✅ `manga_service.dart`: tất cả endpoints (`/mangas/`, `/mangas/{id}`, `/mangas/search`, `/tags/`, `/recommendations/for-me`) đã đúng
- ✅ `chapter_service.dart`: endpoints (`/manga/{id}/chapters`, `/manga/{id}/chapters/{cid}`, `/proxy/chapter-pages/{id}`) + MangaDex fallback đã đúng
- ✅ `comment_service.dart`: tất cả endpoints đã đúng
- ✅ `rating_service.dart`: endpoints đã đúng
- ✅ `friend_service.dart`: endpoints đã đúng (vấn đề nằm ở `friends_screen.dart`)
- ✅ `chat_service.dart`: endpoints và field names đã đúng
- ✅ `creator_service.dart`: endpoint đã đúng
- ✅ `manga.dart` model: `fromJson()` parse logic đã đúng (genres/themes/description/authors từ backend format)
- ✅ `detail_screen.dart`: `_normalizeChapter()`, `_loadData()`, Cover Art tab (MangaDex API) đã đúng
- ✅ `reader_screen.dart`: load pages + fallback + chapter navigation đã đúng
- ✅ `app_provider.dart`: history save/load, list CRUD đã đúng
- ✅ `auth_provider.dart`, `auth_screen.dart`: JWT flow đã đúng
- ✅ `MangaDexApi`: `getMangaCovers()`, `getMangaChapters()`, `getChapterPages()` đã đúng

---

## GHI CHÚ VỀ MANGADEX API HYBRID

App đang kết hợp đúng cách:
- **Browse/Search manga**: Backend API (có cover MinIO → MangaDex fallback)
- **Cover Art gallery**: MangaDex API trực tiếp (`MangaDexApi().getMangaCovers()`) ✅
- **Chapter pages**: Backend proxy → MangaDex at-home fallback ✅
- **Creator screen**: Cần sửa để dùng Backend `CreatorService` (nếu có ID) hoặc `MangaDexApi.searchManga` (fallback)

Để đảm bảo demo đẹp:
1. Cover Art tab đã lấy đủ tất cả cover từ MangaDex → ✅ đẹp
2. Chapter pages có dual source → ✅ ít bị lỗi
3. Main cover trong danh sách phụ thuộc backend URL quality – nếu thấy placeholder nhiều thì kiểm tra `cover_url` field trong response backend

---

## BACKEND CORS (nhắc lại từ BUG_FIX_PLAN)

Để Flutter web/mobile kết nối được backend local, cần sửa `manga_backend/main.py`:
```python
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Development only
    allow_credentials=False,  # Phải False khi allow_origins="*"
    allow_methods=["*"],
    allow_headers=["*"],
)
```
**Lưu ý**: `allow_origins=["*"]` + `allow_credentials=True` bị trình duyệt từ chối theo CORS spec. Phải chọn một trong hai, không dùng cả hai.

---

*Báo cáo này tổng hợp audit toàn bộ source code từ `flutter_project_dump.txt`, `BUG_FIX_PLAN.md`, và `FLUTTER_IMPLEMENTATION_PLAN.md`.*
