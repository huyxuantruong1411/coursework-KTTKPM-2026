# BUG FIX PLAN – Flutter App
## Báo cáo lỗi & Kế hoạch sửa cho AI Agent

> **Quy ước đọc tài liệu:**  
> - ❌ = Lỗi sai hoàn toàn / sẽ crash  
> - ⚠️ = Logic sai / response không parse được  
> - 📝 = Backend cần sửa thêm  
> - Mỗi mục ghi rõ: **File**, **Vấn đề cụ thể**, **Cách sửa đúng**

---

## TỔNG QUAN CÁC NHÓM LỖI

| # | Nhóm | Mức độ | Số lỗi |
|---|------|--------|--------|
| 1 | `manga_service.dart` – endpoint sai | ❌ | 8 |
| 2 | `chapter_service.dart` – endpoint sai | ❌ | 3 |
| 3 | `rating_service.dart` – endpoint sai | ❌ | 4 |
| 4 | `comment_service.dart` – endpoint sai | ❌ | 3 |
| 5 | `friend_service.dart` – endpoint & cấu trúc sai | ❌ | 5 |
| 6 | `chat_service.dart` – field names & endpoint sai | ❌ | 4 |
| 7 | `creator_service.dart` – endpoint sai | ❌ | 1 |
| 8 | `Manga.fromJson()` – parse sai từ backend response | ❌ | 5 |
| 9 | Chapter format mismatch qua toàn app | ❌ | 4 |
| 10 | Screen logic sai do endpoint/response sai | ⚠️ | 5 |
| 11 | Backend CORS chặn mobile | 📝 | 1 |

---

## 1. `lib/services/manga_service.dart` – ENDPOINTS SAI HOÀN TOÀN

Backend sử dụng prefix **`/mangas/`** (số nhiều), không phải `/manga/`. Các endpoint `popular`, `recent`, `recommendations`, `search`, `tags`, `stats` đều sai route.

### 1.1 ❌ Base route sai: `/manga/` → `/mangas/`

```
Sai:   GET /manga/
Đúng:  GET /mangas/
```
**Áp dụng cho `getMangaList()` và `getMangaDetail()`.**

**Sửa `getMangaList()`:**
```dart
// SaiA:
final response = await _dio.get('/manga/', queryParameters: params);

// Đúng:
final response = await _dio.get('/mangas/', queryParameters: params);
```
Response key từ backend là `items` (PaginatedResponse), **không phải** `manga`:
```dart
// Sai – backend trả về PaginatedResponse với key 'items':
return {'manga': [], 'total': 0}; // fallback sai

// Đúng – parse items:
final data = response.data as Map<String, dynamic>;
// data có: items, page, per_page, total, total_pages
```

**Sửa `getMangaDetail()`:**
```dart
// Sai:
final response = await _dio.get('/manga/$mangaId');
// Đúng:
final response = await _dio.get('/mangas/$mangaId');
```

### 1.2 ❌ `getPopularManga()` – Endpoint không tồn tại

```
Sai:   GET /manga/popular
Đúng:  GET /mangas/?sort=follows_desc&limit=20
```

```dart
static Future<List<Map<String, dynamic>>> getPopularManga({int limit = 20}) async {
  try {
    final response = await _dio.get('/mangas/', queryParameters: {
      'limit': limit,
      'sort': 'follows_desc',
    });
    final data = response.data as Map<String, dynamic>;
    return (data['items'] as List? ?? []).cast<Map<String, dynamic>>();
  } on DioException catch (e) {
    debugPrint('MangaService.getPopularManga error: ${e.response?.data}');
    return [];
  }
}
```

### 1.3 ❌ `getRecentManga()` – Endpoint không tồn tại

```
Sai:   GET /manga/recent
Đúng:  GET /mangas/?sort=updated_desc&limit=20
```

```dart
static Future<List<Map<String, dynamic>>> getRecentManga({int limit = 20}) async {
  try {
    final response = await _dio.get('/mangas/', queryParameters: {
      'limit': limit,
      'sort': 'updated_desc',
    });
    final data = response.data as Map<String, dynamic>;
    return (data['items'] as List? ?? []).cast<Map<String, dynamic>>();
  } on DioException catch (e) {
    debugPrint('MangaService.getRecentManga error: ${e.response?.data}');
    return [];
  }
}
```

### 1.4 ❌ `getRecommendations()` – Endpoint sai prefix

```
Sai:   GET /manga/recommendations
Đúng:  GET /recommendations/for-me?top_n=20
```

```dart
static Future<List<Map<String, dynamic>>> getRecommendations({int limit = 20}) async {
  try {
    final response = await _dio.get('/recommendations/for-me', queryParameters: {'top_n': limit});
    final data = response.data as Map<String, dynamic>;
    return (data['recommendations'] as List? ?? []).cast<Map<String, dynamic>>();
  } on DioException catch (e) {
    debugPrint('MangaService.getRecommendations error: ${e.response?.data}');
    return [];
  }
}
```

### 1.5 ❌ `searchManga()` – Endpoint sai và params sai

```
Sai:   GET /manga/search?q=&page=&limit=
Đúng:  GET /mangas/search?q=&include_tags=&exclude_tags=&status=&content_rating=&demographic=&year_from=&year_to=&original_lang=&page=&limit=&sort=
```

Ngoài ra, `search_screen.dart` gọi `getMangaList()` thay vì `searchManga()` khi có filter tags – phải dùng `searchManga()`.

```dart
static Future<Map<String, dynamic>> searchManga({
  required String query,
  int page = 1,
  int limit = 20,
  List<String>? includeTags,
  List<String>? excludeTags,
  String? status,
  String? contentRating,
  String? demographic,
  int? yearFrom,
  int? yearTo,
  String? originalLang,
  String? sort,
}) async {
  try {
    final params = <String, dynamic>{'page': page, 'limit': limit};
    if (query.isNotEmpty) params['q'] = query;
    if (includeTags != null && includeTags.isNotEmpty) params['include_tags'] = includeTags.join(',');
    if (excludeTags != null && excludeTags.isNotEmpty) params['exclude_tags'] = excludeTags.join(',');
    if (status != null) params['status'] = status;
    if (contentRating != null) params['content_rating'] = contentRating;
    if (demographic != null) params['demographic'] = demographic;
    if (yearFrom != null) params['year_from'] = yearFrom;
    if (yearTo != null) params['year_to'] = yearTo;
    if (originalLang != null) params['original_lang'] = originalLang;
    if (sort != null) params['sort'] = sort;

    final response = await _dio.get('/mangas/search', queryParameters: params);
    return response.data as Map<String, dynamic>;
  } on DioException catch (e) {
    debugPrint('MangaService.searchManga error: ${e.response?.data}');
    return {'items': [], 'total': 0};
  }
}
```

### 1.6 ❌ `getTags()` – Endpoint sai

```
Sai:   GET /manga/tags
Đúng:  GET /tags/
```

```dart
static Future<List<Map<String, dynamic>>> getTags() async {
  try {
    final response = await _dio.get('/tags/');
    final data = response.data;
    if (data is List) return data.cast<Map<String, dynamic>>();
    return [];
  } on DioException catch (e) {
    debugPrint('MangaService.getTags error: ${e.response?.data}');
    return [];
  }
}
```

Backend trả về list dạng `[{group_name: "genre", tags: [{TagId, GroupName, NameEn}]}, ...]`.

### 1.7 ❌ `getMangaStats()` – Endpoint không tồn tại

```
Sai:   GET /manga/{id}/stats
```

Backend không có endpoint này. Stats (`Follows`, `AverageRating`) được trả về inline trong `/mangas/{id}` response dưới key `stats`. Xóa method này hoặc thay bằng `getMangaDetail()`.

### 1.8 ❌ `getMangaList()` params không khớp backend

Backend `/mangas/` nhận: `page, limit, sort, status, content_rating, demographic, year`.
Không có param `tag` hay `q` (search dùng endpoint riêng `/mangas/search`).

```dart
// Sửa getMangaList() signature:
static Future<Map<String, dynamic>> getMangaList({
  int page = 1,
  int limit = 20,
  String? sort,
  String? status,
  String? contentRating,
  String? demographic,
  int? year,
  // XÓA: String? query, String? tag (không có trong backend)
}) async {
  final params = <String, dynamic>{'page': page, 'limit': limit};
  if (sort != null) params['sort'] = sort;
  if (status != null) params['status'] = status;
  if (contentRating != null) params['content_rating'] = contentRating;
  if (demographic != null) params['demographic'] = demographic;
  if (year != null) params['year'] = year;

  final response = await _dio.get('/mangas/', queryParameters: params);
  return response.data as Map<String, dynamic>;
}
```

---

## 2. `lib/services/chapter_service.dart` – ENDPOINTS SAI HOÀN TOÀN

### 2.1 ❌ `getChapters()` – Endpoint sai, response format sai

```
Sai:   GET /chapters/manga/{id}?page=&limit=&sort=chapter_asc
Đúng:  GET /manga/{id}/chapters?lang=&sort=asc
```

Backend trả về **List trực tiếp**, không bọc trong object `{chapters: [...]}`.  
Sort values: `"asc"` hoặc `"desc"`, không phải `"chapter_asc"`.

```dart
static Future<List<Map<String, dynamic>>> getChapters(
  String mangaId, {
  String? lang,
  String sort = 'asc',
}) async {
  try {
    final params = <String, dynamic>{'sort': sort};
    if (lang != null) params['lang'] = lang;

    final response = await _dio.get('/manga/$mangaId/chapters', queryParameters: params);
    final data = response.data;
    if (data is List) return data.cast<Map<String, dynamic>>();
    return [];
  } on DioException catch (e) {
    debugPrint('ChapterService.getChapters error: ${e.response?.data}');
    return [];
  }
}
```

**Quan trọng:** Cần cập nhật `detail_screen.dart` để gọi đúng:
```dart
// Sai (detail_screen):
ChapterService.getChapters(widget.manga.id).then((res) =>
    ((res['chapters'] ?? []) as List).cast<Map<String, dynamic>>())

// Đúng:
ChapterService.getChapters(widget.manga.id)  // trả về List<Map> trực tiếp
```

### 2.2 ❌ `getChapterDetail()` – Endpoint sai, thiếu manga_id

```
Sai:   GET /chapters/{chapter_id}
Đúng:  GET /manga/{manga_id}/chapters/{chapter_id}
```

Method hiện tại chỉ nhận `chapterId` nhưng backend cần cả `mangaId`. Cập nhật signature:

```dart
static Future<Map<String, dynamic>?> getChapterDetail(
  String mangaId,
  String chapterId,
) async {
  try {
    final response = await _dio.get('/manga/$mangaId/chapters/$chapterId');
    return response.data as Map<String, dynamic>;
  } on DioException catch (e) {
    if (e.response?.statusCode == 404) return null;
    debugPrint('ChapterService.getChapterDetail error: ${e.response?.data}');
    return null;
  }
}
```

Response trả về `ChapterNav`: `{current: {...}, prev_chapter: {...}, next_chapter: {...}, page_urls: [...]}`.

### 2.3 ❌ `getChapterPages()` – Endpoint không tồn tại

```
Sai:   GET /chapters/{id}/pages
Đúng:  GET /proxy/chapter-pages/{chapter_id}?quality=data-saver
```

```dart
static Future<List<String>> getChapterPages(String chapterId, {bool dataSaver = true}) async {
  try {
    final quality = dataSaver ? 'data-saver' : 'data';
    final response = await _dio.get(
      '/proxy/chapter-pages/$chapterId',
      queryParameters: {'quality': quality},
    );
    final data = response.data as Map<String, dynamic>;
    return (data['pages'] as List? ?? []).cast<String>();
  } on DioException catch (e) {
    debugPrint('ChapterService.getChapterPages error: ${e.response?.data}');
    return [];
  }
}
```

---

## 3. `lib/services/rating_service.dart` – ENDPOINTS SAI

### 3.1 ❌ `getRatingSummary()` – Endpoint không tồn tại

```
Sai:   GET /ratings/manga/{id}
```

Backend không có endpoint tổng hợp rating. Rating trung bình nằm trong `manga.stats.AverageRating` từ `/mangas/{id}`. **Xóa method này** hoặc thay bằng `getMangaDetail()`.

### 3.2 ❌ `getMyRating()` – Endpoint sai

```
Sai:   GET /ratings/manga/{id}/me
Đúng:  GET /ratings/manga/{id}/my-rating
```

```dart
static Future<int?> getMyRating(String mangaId) async {
  try {
    final response = await _dio.get('/ratings/manga/$mangaId/my-rating');
    final data = response.data as Map<String, dynamic>;
    return data['score'] as int?; // backend trả về {'score': null | int}
  } on DioException catch (e) {
    if (e.response?.statusCode == 401 || e.response?.statusCode == 404) return null;
    debugPrint('RatingService.getMyRating error: ${e.response?.data}');
    return null;
  }
}
```

### 3.3 ❌ `rateManga()` – Endpoint sai

```
Sai:   POST /ratings/manga/{id}
Đúng:  POST /ratings/manga/{id}/rate
```

```dart
static Future<void> rateManga(String mangaId, int score) async {
  try {
    await _dio.post('/ratings/manga/$mangaId/rate', data: {'Score': score});
  } on DioException catch (e) {
    throw Exception(e.response?.data?['detail'] ?? 'Failed to rate');
  }
}
```

### 3.4 ❌ `deleteRating()` – Endpoint không tồn tại

```
Sai:   DELETE /ratings/manga/{id}
```

Backend không có DELETE rating. **Xóa method này.**

---

## 4. `lib/services/comment_service.dart` – ENDPOINTS SAI

### 4.1 ❌ `getComments()` – Endpoint thiếu `/comments` suffix

```
Sai:   GET /comments/manga/{id}
Đúng:  GET /comments/manga/{id}/comments
```

```dart
static Future<Map<String, dynamic>> getComments(String mangaId, {int page = 1, int limit = 20}) async {
  try {
    final response = await _dio.get('/comments/manga/$mangaId/comments',
      queryParameters: {'page': page, 'limit': limit});
    return response.data as Map<String, dynamic>;
    // Response: PaginatedResponse {items: [...], page, per_page, total, total_pages}
  } on DioException catch (e) {
    debugPrint('CommentService.getComments error: ${e.response?.data}');
    return {'items': [], 'total': 0};
  }
}
```

### 4.2 ❌ `postComment()` – Endpoint thiếu `/comments` suffix, body sai field

```
Sai:   POST /comments/manga/{id}  body: {Content, ParentId?}
Đúng:  POST /comments/manga/{id}/comments  body: {Content, IsSpoiler, ChapterId?}
```

Backend không có `ParentId` (không support threaded comments). Thay bằng `IsSpoiler`:

```dart
static Future<Map<String, dynamic>?> postComment(
  String mangaId,
  String content, {
  bool isSpoiler = false,
  String? chapterId,
}) async {
  try {
    final data = <String, dynamic>{'Content': content, 'IsSpoiler': isSpoiler};
    if (chapterId != null) data['ChapterId'] = chapterId;
    final response = await _dio.post('/comments/manga/$mangaId/comments', data: data);
    return response.data as Map<String, dynamic>;
  } on DioException catch (e) {
    throw Exception(e.response?.data?['detail'] ?? 'Failed to post comment');
  }
}
```

### 4.3 ⚠️ `updateComment()` body key cần kiểm tra

Backend `PUT /comments/{id}` nhận `{Content: string}`. Service gửi `{'Content': content}` – **khớp** ✓.

---

## 5. `lib/services/friend_service.dart` – CẤU TRÚC VÀ ENDPOINTS SAI

### 5.1 ❌ `getFriends()` – Endpoint sai, response structure không tồn tại trong backend

Backend có **2 endpoint riêng biệt**:
- `GET /friends/` → `{friends: [...]}`  (accepted friends only)
- `GET /friends/requests` → `{requests: [...]}` (pending requests, chỉ received)
- **Không có** `pending_sent` endpoint

`getFriends()` hiện gọi `GET /friends/` và tự chế response structure `{friends, pending_received, pending_sent}` không khớp.

```dart
// Thay bằng 2 method riêng:

static Future<List<Map<String, dynamic>>> getAcceptedFriends() async {
  try {
    final response = await _dio.get('/friends/');
    final data = response.data as Map<String, dynamic>;
    return (data['friends'] as List? ?? []).cast<Map<String, dynamic>>();
  } on DioException catch (e) {
    debugPrint('FriendService.getAcceptedFriends error: ${e.response?.data}');
    return [];
  }
}

static Future<List<Map<String, dynamic>>> getPendingRequests() async {
  try {
    final response = await _dio.get('/friends/requests');
    final data = response.data as Map<String, dynamic>;
    // Backend trả về {requests: [...]} với mỗi item có user_id, username, avatar, display_name, requested_at
    return (data['requests'] as List? ?? []).cast<Map<String, dynamic>>();
  } on DioException catch (e) {
    debugPrint('FriendService.getPendingRequests error: ${e.response?.data}');
    return [];
  }
}
```

### 5.2 ❌ `sendRequest()` – Param type sai: query param → path param

```
Sai:   POST /friends/request?target_user_id={userId}
Đúng:  POST /friends/request/{userId}   (path param)
```

```dart
static Future<void> sendRequest(String targetUserId) async {
  try {
    await _dio.post('/friends/request/$targetUserId');
  } on DioException catch (e) {
    throw Exception(e.response?.data?['detail'] ?? 'Failed to send request');
  }
}
```

### 5.3 ❌ `acceptRequest()` – Param type sai và param sai

```
Sai:   POST /friends/accept?request_id={requestId}
Đúng:  POST /friends/accept/{userId}   (path param, dùng user_id của người gửi request)
```

Backend accept bằng `user_id` của người đã gửi request (không phải request_id). Trong `friends_screen.dart`, cần lấy `user_id` từ request item thay vì `RequestId`:

```dart
static Future<void> acceptRequest(String userId) async {
  try {
    await _dio.post('/friends/accept/$userId');
  } on DioException catch (e) {
    throw Exception(e.response?.data?['detail'] ?? 'Failed to accept');
  }
}
```

### 5.4 ❌ `rejectRequest()` – Param type sai và param sai

```
Sai:   POST /friends/reject?request_id={requestId}
Đúng:  POST /friends/reject/{userId}   (path param, dùng user_id)
```

```dart
static Future<void> rejectRequest(String userId) async {
  try {
    await _dio.post('/friends/reject/$userId');
  } on DioException catch (e) {
    throw Exception(e.response?.data?['detail'] ?? 'Failed to reject');
  }
}
```

### 5.5 ❌ `removeFriend()` – Endpoint không tồn tại

```
Sai:   DELETE /friends/{id}
```

Backend không có endpoint xóa bạn bè. Tạm thời có thể dùng `block` thay thế hoặc loại bỏ feature này:

```dart
// Thay bằng block, hoặc xóa method
static Future<void> blockUser(String userId) async {
  try {
    await _dio.post('/friends/block/$userId');
  } on DioException catch (e) {
    throw Exception(e.response?.data?['detail'] ?? 'Failed to block');
  }
}
```

---

## 6. `lib/services/chat_service.dart` – FIELD NAMES VÀ ENDPOINTS SAI

### 6.1 ❌ `createRoom()` – Body field names sai

```
Sai body:   {IsDirect: bool, Name: string, MemberIds: list}
Đúng body:  {type: "direct"|"group", user_ids: [string], name?: string}
```

```dart
static Future<Map<String, dynamic>?> createRoom({
  String type = 'group',
  String? name,
  List<String>? userIds,
}) async {
  try {
    final data = <String, dynamic>{'type': type};
    if (name != null) data['name'] = name;
    if (userIds != null) data['user_ids'] = userIds;
    final response = await _dio.post('/chat/rooms', data: data);
    return response.data as Map<String, dynamic>;
  } on DioException catch (e) {
    throw Exception(e.response?.data?['detail'] ?? 'Failed to create room');
  }
}
```

### 6.2 ❌ `getMessages()` – Params sai

```
Sai:   GET /chat/rooms/{id}/messages?before=&limit=
Đúng:  GET /chat/rooms/{id}/messages?page=&limit=
```

```dart
static Future<List<Map<String, dynamic>>> getMessages(
  String roomId, {
  int page = 1,
  int limit = 50,
}) async {
  try {
    final params = <String, dynamic>{'page': page, 'limit': limit};
    final response = await _dio.get('/chat/rooms/$roomId/messages', queryParameters: params);
    final data = response.data;
    if (data is Map && data['messages'] is List) {
      return (data['messages'] as List).cast<Map<String, dynamic>>();
    }
    if (data is List) return data.cast<Map<String, dynamic>>();
    return [];
  } on DioException catch (e) {
    debugPrint('ChatService.getMessages error: ${e.response?.data}');
    return [];
  }
}
```

### 6.3 ❌ `sendMessage()` – Body field names sai (PascalCase → snake_case)

```
Sai body:   {Content: string, MediaUrl?: string}
Đúng body:  {content: string, reply_to_id?: string}
```

Backend `POST /chat/rooms/{id}/messages` nhận snake_case. Xem `chat.py`:
```python
class MessageCreateRequest(BaseModel):
    content: str
    reply_to_id: Optional[UUID] = None
```

```dart
static Future<Map<String, dynamic>?> sendMessage(
  String roomId,
  String content, {
  String? replyToId,
}) async {
  try {
    final data = <String, dynamic>{'content': content};
    if (replyToId != null) data['reply_to_id'] = replyToId;
    final response = await _dio.post('/chat/rooms/$roomId/messages', data: data);
    return response.data as Map<String, dynamic>;
  } on DioException catch (e) {
    throw Exception(e.response?.data?['detail'] ?? 'Failed to send message');
  }
}
```

### 6.4 ❌ `uploadMedia()` – Endpoint sai

```
Sai:   POST /chat/upload
Đúng:  POST /chat/rooms/{room_id}/media
```

```dart
static Future<String?> uploadMedia(String roomId, String filePath) async {
  try {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath),
    });
    final response = await _dio.post(
      '/chat/rooms/$roomId/media',
      data: formData,
      options: Options(contentType: 'multipart/form-data'),
    );
    return response.data['media_url'] as String?;
  } on DioException catch (e) {
    debugPrint('ChatService.uploadMedia error: ${e.response?.data}');
    return null;
  }
}
```

---

## 7. `lib/services/creator_service.dart` – ENDPOINT SAI

### 7.1 ❌ `getCreatorMangas()` – Endpoint không tồn tại

```
Sai:   GET /creators/{id}/mangas
```

Backend `GET /creators/{id}` trả về **cả creator info lẫn manga list** trong một response:
```json
{
  "creator": {"id": "...", "name": "...", "image_url": "...", "biography": "..."},
  "mangas": {PaginatedResponse}
}
```

**Xóa `getCreatorMangas()` và cập nhật `getCreatorDetail()`:**

```dart
static Future<Map<String, dynamic>?> getCreatorDetail(
  String id, {
  int page = 1,
  int limit = 20,
}) async {
  try {
    final response = await _dio.get('/creators/$id', queryParameters: {
      'page': page,
      'limit': limit,
    });
    return response.data as Map<String, dynamic>;
    // response chứa: creator{id, name, image_url, biography} + mangas{items, total, ...}
  } on DioException catch (e) {
    if (e.response?.statusCode == 404) return null;
    throw Exception(e.response?.data?['detail'] ?? 'Failed to load creator');
  }
}
```

---

## 8. `lib/models/manga.dart` – `fromJson()` SAI KHI PARSE BACKEND RESPONSE

### 8.1 ❌ `genres` và `themes` parse sai

Backend trả về `tags` là list objects: `[{TagId, GroupName, NameEn}]`.  
Code hiện tại: `(json['Genres'] ?? json['genres'] ?? []).cast<String>()` → **crash** vì list chứa Maps.

```dart
// SỬA trong Manga.fromJson():
static List<String> _extractTagsByGroup(dynamic tagsJson, List<String> groups) {
  if (tagsJson == null) return [];
  final tags = tagsJson as List;
  return tags
      .where((t) => groups.contains((t['GroupName'] ?? '').toString().toLowerCase()))
      .map((t) => (t['NameEn'] ?? '').toString())
      .where((name) => name.isNotEmpty)
      .toList();
}

// Trong fromJson():
genres: _extractTagsByGroup(json['tags'], ['genre', 'format', 'content']),
themes: _extractTagsByGroup(json['tags'], ['theme']),
```

### 8.2 ❌ `description` parse sai

Backend trả về `descriptions` là list objects: `[{LangCode, Description}]`.  
Code hiện tại: `json['DescriptionEn'] ?? json['description']` → sẽ luôn là `null` hoặc `'Chưa có tóm tắt.'`.

```dart
static String _extractDescription(dynamic descriptionsJson) {
  if (descriptionsJson == null) return 'Chưa có thông tin tóm tắt.';
  final list = descriptionsJson as List;
  // Ưu tiên tiếng Việt, rồi tiếng Anh
  final vi = list.firstWhere(
    (d) => d['LangCode'] == 'vi', orElse: () => null);
  if (vi != null) return vi['Description'] ?? 'Chưa có thông tin tóm tắt.';
  final en = list.firstWhere(
    (d) => d['LangCode'] == 'en', orElse: () => null);
  if (en != null) return en['Description'] ?? 'Chưa có thông tin tóm tắt.';
  if (list.isNotEmpty && list.first['Description'] != null) return list.first['Description'];
  return 'Chưa có thông tin tóm tắt.';
}

// Trong fromJson():
description: _extractDescription(json['descriptions']),
```

### 8.3 ❌ `altTitles` parse sai

Backend: `alt_titles` là `[{LangCode, AltTitle}]`.  
Code hiện tại: `(json['AltTitles'] ?? json['alt_titles'] ?? []).cast<String>()` → **crash** vì là Maps.

```dart
// Trong fromJson():
altTitles: (json['alt_titles'] as List? ?? [])
    .map((t) => (t['AltTitle'] ?? '').toString())
    .where((t) => t.isNotEmpty)
    .toList(),
```

### 8.4 ❌ `author` và `artist` parse sai

Backend: `creators` là `[{id, name, role}]`. `role` là `"author"` hoặc `"artist"`.  
Code hiện tại: `json['Author'] ?? json['author']` → luôn `null` khi parse backend response.

```dart
static String _extractCreatorByRole(dynamic creatorsJson, String role) {
  if (creatorsJson == null) return '';
  final list = creatorsJson as List;
  final match = list.firstWhere(
    (c) => (c['role'] ?? '').toString().toLowerCase() == role,
    orElse: () => null,
  );
  return match?['name']?.toString() ?? '';
}

// Trong fromJson():
author: _extractCreatorByRole(json['creators'], 'author').isNotEmpty
    ? _extractCreatorByRole(json['creators'], 'author')
    : json['Author'] ?? json['author'] ?? 'Đang cập nhật',
artist: _extractCreatorByRole(json['creators'], 'artist').isNotEmpty
    ? _extractCreatorByRole(json['creators'], 'artist')
    : json['Artist'] ?? json['artist'] ?? '',
```

### 8.5 ⚠️ `views` field không tồn tại trong backend

`views` field được khai báo trong `Manga` model nhưng backend không có field này. Field `json['Views']` luôn null → default về `0`. Không crash nhưng data sai. Có thể giữ nguyên với default `0`.

---

## 9. CHAPTER FORMAT MISMATCH (Data structure không nhất quán toàn app)

**Nguyên nhân gốc:** Backend chapters có format khác MangaDex. Toàn bộ app đang dùng MangaDex-format keys (`id`, `chapter`, `language`, `title`, `pages`, `group`) nhưng backend trả về PascalCase keys (`ChapterId`, `ChapterNumber`, `TranslatedLang`, `Title`, `Pages`). `ScanlationGroup` không tồn tại trong backend.

**Giải pháp:** Tạo `_normalizeChapter()` helper để convert backend format → app format thống nhất.

### 9.1 ❌ `detail_screen.dart` – chapters stored in wrong format

Thêm normalizer sau khi load chapters từ backend:

```dart
// Thêm static helper vào DetailScreen (hoặc util file):
static Map<String, dynamic> _normalizeChapter(Map<String, dynamic> raw) {
  return {
    'id': raw['ChapterId']?.toString() ?? raw['id']?.toString() ?? '',
    'chapter': raw['ChapterNumber'] ?? raw['chapter'] ?? 'Oneshot',
    'title': raw['Title'] ?? raw['title'] ?? '',
    'volume': raw['Volume'] ?? raw['volume'] ?? '',
    'language': raw['TranslatedLang'] ?? raw['language'] ?? 'en',
    'pages': raw['Pages'] ?? raw['pages'] ?? 0,
    'publishAt': raw['PublishAt'] ?? raw['publishAt'] ?? '',
    'group': raw['ScanlationGroup'] ?? raw['group'] ?? 'Unknown',
  };
}
```

Trong `_loadData()`:
```dart
// Sửa lại:
ChapterService.getChapters(widget.manga.id)  // trả về List<Map> trực tiếp
    .then((res) => res.map(_normalizeChapter).toList()),
```

### 9.2 ❌ `chapter_service.dart` `Chapter.fromJson` – field `language` sai

```dart
// Sai: json['Language'] → không tồn tại trong backend
language: json['Language'] ?? json['language'] ?? 'en',

// Đúng:
language: json['TranslatedLang'] ?? json['language'] ?? json['Language'] ?? 'en',
```

### 9.3 ❌ `reader_screen.dart` – `_goToChapter()` dùng `chap['id']` và `chap['chapter']`

Đây là MangaDex format keys. Sau khi áp dụng `_normalizeChapter()` ở mục 9.1, reader sẽ nhận đúng format. Không cần sửa thêm gì ở reader nếu data đã normalize.

### 9.4 ⚠️ `reader_screen.dart` chapter drawer – `chap['group']` luôn là `'Unknown'`

Backend không có scanlation group trong chapter response. Chấp nhận hiển thị `'Unknown'` hoặc ẩn field này.

---

## 10. SCREEN LOGIC SAI

### 10.1 ❌ `explore_screen.dart` – Genre filter dùng MangaDex tag UUIDs với backend

```dart
// Trong explore_screen.dart:
const _featuredGenres = <String, String>{
  'Action': '391b0423-d847-456f-aff0-8b0cfc03066b',  // MangaDex UUID
  ...
};

// Khi filter:
MangaService.getMangaList(tag: id)  // Backend không nhận param 'tag'
```

**Sửa:** Genre filter cần dùng tag UUID từ backend database và đổi sang `/mangas/search?include_tags=`:

```dart
void _filterByGenre(String name, String tagId) {
  setState(() {
    if (_selectedGenreId == tagId) {
      _selectedGenreId = null;
      _selectedGenreName = null;
      _popularFuture = MangaService.getPopularManga()
          .then((res) => res.map((e) => Manga.fromJson(e)).toList());
    } else {
      _selectedGenreId = tagId;
      _selectedGenreName = name;
      _popularFuture = MangaService.searchManga(
        query: '',
        includeTags: [tagId],
        limit: 20,
      ).then((res) => (res['items'] as List? ?? [])
          .cast<Map<String, dynamic>>()
          .map((e) => Manga.fromJson(e))
          .toList());
    }
  });
}
```

**Lưu ý:** Tag UUIDs hardcode trong `_featuredGenres` có thể là MangaDex UUIDs – nếu backend đã import data từ MangaDex, các UUID này sẽ trùng khớp vì cùng nguồn dữ liệu. Nếu không trùng khớp thì cần load tags từ `MangaService.getTags()` và map theo tên.

### 10.2 ❌ `search_screen.dart` – Dùng `getMangaList()` thay vì `searchManga()`

```dart
// Sai (trong _performSearch()):
final res = await MangaService.getMangaList(
  query: query,
  tag: _includedTags.isNotEmpty ? _includedTags.join(',') : null,
  ...
);
final results = ((res['manga'] ?? []) as List)...;

// Đúng:
final res = await MangaService.searchManga(
  query: query,
  includeTags: _includedTags.isNotEmpty ? _includedTags : null,
  excludeTags: _excludedTags.isNotEmpty ? _excludedTags : null,
  status: _statuses.isNotEmpty ? _statuses.first : null,
  contentRating: _contentRatings.isNotEmpty ? _contentRatings.first : null,
  demographic: _demographics.isNotEmpty ? _demographics.first : null,
  year: _year,
  sort: _getSortParam(),
);
final results = ((res['items'] ?? []) as List)
    .cast<Map<String, dynamic>>()
    .map((e) => Manga.fromJson(e))
    .toList();
```

### 10.3 ❌ `library_screen.dart` – Public lists response key sai

```dart
// Sai: backend PaginatedResponse có 'items' không phải 'lists'
_publicLists = ((res['lists'] ?? []) as List).cast<Map<String, dynamic>>();

// Đúng:
_publicLists = ((res['items'] ?? []) as List).cast<Map<String, dynamic>>();
```

### 10.4 ❌ `friends_screen.dart` – Cần cập nhật sau khi sửa `friend_service.dart`

**a) `_loadFriends()` cần gọi 2 method riêng:**
```dart
Future<void> _loadFriends() async {
  setState(() => _loading = true);
  final friends = await FriendService.getAcceptedFriends();
  final requests = await FriendService.getPendingRequests();
  if (mounted) {
    setState(() {
      _friends = friends;
      _pendingReceived = requests;
      _pendingSent = []; // Backend không có pending_sent endpoint
      _loading = false;
    });
  }
}
```

**b) Accept/Reject dùng `user_id` thay vì `RequestId`:**

Backend `/friends/requests` trả về: `{user_id, username, avatar, display_name, requested_at}`.

```dart
// Sai (trong _buildPendingReceived()):
final reqId = r['RequestId']?.toString() ?? r['request_id']?.toString() ?? '';
await FriendService.acceptRequest(reqId);

// Đúng: dùng user_id của người gửi request
final userId = r['user_id']?.toString() ?? '';
await FriendService.acceptRequest(userId);
await FriendService.rejectRequest(userId);
```

**c) Tab "Đã gửi" nên ẩn hoặc hiện thông báo:**
```dart
Widget _buildPendingSent() {
  return const Center(
    child: Text('Tính năng này chưa được hỗ trợ.', style: TextStyle(color: Colors.white38)),
  );
}
```

### 10.5 ❌ `friends_screen.dart` – Chat với friend dùng friend_id làm room_id sai

```dart
// Sai – friendId là UserId, không phải RoomId:
Navigator.push(context, MaterialPageRoute(
  builder: (_) => ChatScreen(roomId: friendId, roomName: name)));

// Đúng – phải tạo/tìm direct chat room trước:
Future<void> _openChat(String friendId, String friendName) async {
  try {
    final result = await ChatService.createRoom(type: 'direct', userIds: [friendId]);
    if (!mounted) return;
    final roomId = result?['room_id']?.toString() ?? '';
    if (roomId.isNotEmpty) {
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => ChatScreen(roomId: roomId, roomName: friendName)));
    }
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không thể mở chat: $e')));
    }
  }
}
```

### 10.6 ⚠️ `app_provider.dart` – `getLastReadChapter()` thiếu `chapter_number` field

`HistoryService.getContinueReading()` trả về `{chapter_id, last_page}` không có `chapter_number`.  
`detail_screen.dart` hiển thị `_lastRead!['chapter_number']` sẽ là `null`.

```dart
// Trong app_provider.getLastReadChapter():
Future<Map<String, dynamic>?> getLastReadChapter(String mangaId) async {
  try {
    final data = await HistoryService.getContinueReading(mangaId);
    if (data == null) return null;
    return {
      'chapter_id': data['chapter_id']?.toString() ?? '',
      'chapter_number': data['chapter_number']?.toString() ?? '',  // có thể null từ backend
      'page_index': data['last_page'] ?? 0,
    };
  } catch (e) {
    return null;
  }
}
```

Trong `detail_screen.dart`, hiển thị safe:
```dart
// Sửa display text để tránh crash:
_lastRead != null ? 'Tiếp tục ${_lastRead!['chapter_number']?.toString().isNotEmpty == true ? "Ch.${_lastRead!['chapter_number']}" : ""}' : 'Đọc ngay'
```

---

## 11. BACKEND – CORS CHẶN MOBILE CLIENT

**File cần sửa:** `manga_backend/main.py`

```python
# Hiện tại – chỉ cho localhost:3000:
app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "http://localhost:3000",
        "http://127.0.0.1:3000"
    ],
    ...
)

# Sửa thành cho phép mobile (development):
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Development only
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
```

> **Lưu ý:** `allow_origins=["*"]` với `allow_credentials=True` sẽ bị trình duyệt từ chối (CORS spec). Khi vào production, đổi sang list domain cụ thể thay vì `"*"`.

---

## 12. CÁC VẤN ĐỀ NHỎ KHÁC

### 12.1 ⚠️ `pubspec.yaml` – `supabase_flutter` còn trong dependency

Không có code nào dùng Supabase nữa nhưng package vẫn được liệt kê. Nên xóa:
```yaml
# Xóa dòng này:
supabase_flutter: ^2.5.0
```

### 12.2 ⚠️ `creator_screen.dart` – Dùng `MangaService.getMangaList()` với query để tìm manga của creator

```dart
// Hiện tại: tìm theo tên creator trong getMangaList()
final res = await MangaService.getMangaList(query: widget.creatorName);

// Đúng: dùng CreatorService.getCreatorDetail() với creator_id, không phải creator_name
// Cần đổi CreatorScreen để nhận creator_id thay vì creatorName
```

Cần cập nhật `CreatorScreen` widget:
```dart
// Đổi constructor:
class CreatorScreen extends StatefulWidget {
  final String creatorId;   // đổi từ creatorName sang creatorId
  final String creatorName; // giữ để hiện tên trên AppBar
  const CreatorScreen({super.key, required this.creatorId, required this.creatorName});
}

// Trong _loadMangas():
final res = await CreatorService.getCreatorDetail(widget.creatorId);
final mangaItems = ((res?['mangas']?['items'] ?? []) as List)
    .cast<Map<String, dynamic>>()
    .map((e) => Manga.fromJson(e))
    .toList();
```

Trong `detail_screen.dart`, cần truyền `creatorId` khi navigate đến `CreatorScreen`. Backend manga detail trả về `creators: [{id, name, role}]` nên có thể lấy `id`.

### 12.3 ⚠️ `history_screen.dart` – `deleteHistoryItem()` là no-op

`AppProvider.deleteHistoryItem()` hiện trống. Backend không có DELETE history item endpoint.  
Dismissible sẽ xóa khỏi UI nhưng data vẫn tồn tại trong DB. Tạm chấp nhận hoặc thêm endpoint vào backend.

### 12.4 ⚠️ `history_screen.dart` – `clearReadingHistory()` là no-op

`AppProvider.clearReadingHistory()` hiện trống. Backend không có DELETE all history endpoint. Tương tự mục 12.3.

### 12.5 ⚠️ `chat_screen.dart` – `_myUserId` có thể null

```dart
_myUserId = await TokenStorage.getUserId();
```

Nếu user chưa gọi `TokenStorage.saveUserInfo()` (chỉ được gọi trong `AuthService.getMe()`), `_myUserId` sẽ null và tất cả messages sẽ hiện như từ người khác. Cần ensure `saveUserInfo` được gọi khi login.

`AuthService.login()` → `getMe()` → `saveUserInfo()` – chain này đã đúng ✓ miễn là login được thực hiện trước khi vào chat.

---

## THỨ TỰ SỬA LỖI ĐỀ NGHỊ

Sửa theo thứ tự ưu tiên để app có thể chạy được càng sớm càng tốt:

```
ƯU TIÊN 1 – App không chạy được nếu thiếu
├── [Backend] Sửa CORS (mục 11)
├── manga_service.dart – sửa tất cả endpoints (mục 1.1 → 1.8)
├── chapter_service.dart – sửa tất cả endpoints (mục 2.1 → 2.3)
├── Manga.fromJson() – sửa parse genres/themes/description/author/altTitles (mục 8.1 → 8.4)
├── detail_screen.dart – sửa chapter data structure (mục 9.1)

ƯU TIÊN 2 – Các tính năng bị hỏng
├── rating_service.dart – sửa endpoints (mục 3.1 → 3.4)
├── comment_service.dart – sửa endpoints (mục 4.1 → 4.3)
├── friend_service.dart – sửa cấu trúc và endpoints (mục 5.1 → 5.5)
├── friends_screen.dart – cập nhật sau service fix (mục 10.4)
├── chat_service.dart – sửa field names và endpoints (mục 6.1 → 6.4)
├── creator_service.dart – sửa endpoint (mục 7.1)

ƯU TIÊN 3 – UX issues
├── explore_screen.dart – genre filter (mục 10.1)
├── search_screen.dart – dùng đúng searchManga() (mục 10.2)
├── library_screen.dart – public lists key (mục 10.3)
├── friends_screen.dart – chat navigation (mục 10.5)
├── app_provider.dart – chapter_number null (mục 10.6)
├── creator_screen.dart – dùng creatorId (mục 12.2)

ƯU TIÊN 4 – Cleanup
├── Xóa supabase_flutter khỏi pubspec.yaml (mục 12.1)
├── Xóa supabase_service.dart
```

---

## QUICK REFERENCE – Backend API Đúng (để đối chiếu khi sửa)

```
Manga:
  GET  /mangas/                          ?page, limit, sort, status, content_rating, demographic, year
  GET  /mangas/search                    ?q, include_tags, exclude_tags, status, content_rating, demographic, year_from, year_to, original_lang, page, limit, sort
  GET  /mangas/{id}                      → MangaDetail (bao gồm tags[], creators[], descriptions[], alt_titles[], stats{})

Chapters:
  GET  /manga/{id}/chapters              ?lang, sort (asc/desc) → List<Chapter> trực tiếp
  GET  /manga/{id}/chapters/{chapter_id} → {current, prev_chapter, next_chapter, page_urls}
  GET  /proxy/chapter-pages/{id}         ?quality=data|data-saver → {pages: [...], hash, quality}

Comments:
  GET  /comments/manga/{id}/comments     ?page, limit
  POST /comments/manga/{id}/comments     body: {Content, IsSpoiler, ChapterId?}
  PUT  /comments/{id}                    body: {Content}
  DELETE /comments/{id}
  POST /comments/{id}/like
  POST /comments/{id}/dislike
  POST /comments/{id}/report             body: {Reason}

Ratings:
  POST /ratings/manga/{id}/rate          body: {Score: 1-10}
  GET  /ratings/manga/{id}/my-rating     → {score: null | int}

History:
  POST /history/                         body: {MangaId, ChapterId, LastPageRead}
  GET  /history/                         ?page, limit → PaginatedResponse
  GET  /history/grouped                  ?limit → {groups: [{label, items}]}
  GET  /history/manga/{id}/continue      → {chapter_id, last_page}

Lists:
  GET  /lists/                           ?manga_id → {my_lists, followed_lists}
  POST /lists/                           body: {Name, Description?, Visibility}
  GET  /lists/public                     ?page, limit, sort, q → PaginatedResponse (key 'items')
  GET  /lists/{id}                       → ListDetail
  PUT  /lists/{id}                       body: {Name?, Description?, Visibility?}
  DELETE /lists/{id}
  POST /lists/{id}/items                 ?manga_id={uuid}
  DELETE /lists/{id}/items/{manga_id}
  POST /lists/{id}/follow
  DELETE /lists/{id}/follow

Friends:
  GET  /friends/                         → {friends: [{user_id, username, avatar, display_name, is_online, last_seen}]}
  GET  /friends/requests                 → {requests: [{user_id, username, avatar, display_name, requested_at}]}
  POST /friends/request/{user_id}        (path param)
  POST /friends/accept/{user_id}         (path param, user_id của người gửi request)
  POST /friends/reject/{user_id}         (path param)
  POST /friends/block/{user_id}          (path param)
  GET  /friends/search                   ?q=query → {users: [...]}

Chat:
  GET  /chat/rooms                       → {rooms: [{room_id, type, name, members, last_message, unread_count}]}
  POST /chat/rooms                       body: {type: "direct"|"group", user_ids: [], name?}
  GET  /chat/rooms/{id}/messages         ?page, limit → {messages, page, total, total_pages}
  POST /chat/rooms/{id}/messages         body: {content, reply_to_id?}
  POST /chat/rooms/{id}/media            multipart: file → {message_id, media_url}
  PUT  /chat/messages/{id}/read
  WS   /ws/chat/{room_id}?token={jwt}

Tags:
  GET  /tags/                            → [{group_name, tags: [{TagId, GroupName, NameEn}]}]

Creators:
  GET  /creators/{id}                    ?page, limit → {creator: {...}, mangas: PaginatedResponse}

Recommendations:
  GET  /recommendations/for-me           ?top_n → {recommendations: [...]}
  GET  /recommendations/manga/{id}/similar ?limit → {recommendations: [...], source}

Auth:
  POST /auth/register                    body: {username, email, password} (JSON)
  POST /auth/login                       form-urlencoded: username, password → {access_token, token_type}
  GET  /auth/me                          → UserResponse {UserId, Username, Email, DisplayName, Avatar, Bio, Role, IsLocked}
  PUT  /auth/me                          body: {username?, email?, bio?, display_name?, new_password?, current_password?}
  POST /auth/me/avatar                   multipart: file → {success, avatar_url}
```
