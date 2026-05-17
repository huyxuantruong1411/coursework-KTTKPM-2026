# FIX PLAN V2 – Flutter Manga App
> Kiểm tra toàn bộ source code từ dump mới nhất, kết hợp với ảnh chụp màn hình.  
> Mỗi mục ghi rõ: **File cần sửa**, **Vấn đề cụ thể**, **Code fix hoàn chỉnh**.

---

## MỨC ĐỘ
- 🔴 **CRASH / BUG cứng** – phải fix để feature hoạt động
- 🟠 **BUG logic** – feature chạy nhưng sai
- 🟡 **UX/UI** – hiển thị kém, chưa hoàn thiện

---

## LỖI 1 – Không gửi tin nhắn được 🔴

**File:** `lib/screens/chat/chat_screen.dart`

**Nguyên nhân:** Hàm `_send()` gọi `ChatService.sendMessage()` để gửi qua REST API, nhưng **không cập nhật danh sách `_messages`** sau khi gửi thành công — chỉ tin nhắn đến qua WebSocket mới được thêm vào. Nếu WebSocket không kết nối hoặc bị lỗi, tin nhắn gửi đi sẽ không hiển thị.  
Ngoài ra, WebSocket connect sau khi load xong, nếu kết nối thất bại, user thấy như không làm gì cả.

**Fix `_send()` trong `_ChatScreenState`:**
```dart
Future<void> _send() async {
  final text = _msgCtrl.text.trim();
  if (text.isEmpty) return;
  _msgCtrl.clear();
  try {
    final result = await ChatService.sendMessage(widget.roomId, text);
    // Nếu WS chưa connected hoặc server không push lại, tự thêm vào list
    if (result != null && mounted) {
      // Kiểm tra xem message đã được WS đẩy về chưa
      final msgId = result['message_id']?.toString() ?? result['id']?.toString() ?? '';
      final alreadyAdded = _messages.any((m) =>
          (m['message_id']?.toString() ?? m['id']?.toString() ?? '') == msgId && msgId.isNotEmpty);
      if (!alreadyAdded) {
        setState(() => _messages.add(result));
        _scrollToBottom();
      }
    }
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi gửi tin: $e'), backgroundColor: Colors.red));
    }
  }
}
```

**Fix WebSocket handler** – đảm bảo không duplicate khi WS cũng push về:
```dart
_ws!.stream.listen((data) {
  if (!mounted) return;
  try {
    final msg = jsonDecode(data as String) as Map<String, dynamic>;
    // De-duplicate theo message_id
    final incomingId = msg['message_id']?.toString() ?? msg['id']?.toString() ?? '';
    final duplicate = incomingId.isNotEmpty &&
        _messages.any((m) =>
            (m['message_id']?.toString() ?? m['id']?.toString() ?? '') == incomingId);
    if (!duplicate) {
      setState(() => _messages.add(msg));
      _scrollToBottom();
    }
  } catch (_) {}
}, onError: (_) {}, onDone: () {});
```

---

## LỖI 2 – Bấm "Chương sau" quay về chương hiện tại 🔴

**File:** `lib/screens/reader/reader_screen.dart`

**Nguyên nhân:** `_goToChapter(int index)` dùng `widget.chapters[index]` nhưng `widget.chapters` là `final` – nó là danh sách được truyền từ `DetailScreen` tại thời điểm mở reader và **không bao giờ thay đổi**. Khi gọi `_goToChapter(_currentChapterIndex + 1)`, `_currentChapterIndex` đã được cập nhật từ `setState()`, nhưng chính xác vấn đề là: trong `_buildEndCard()` có dòng:

```dart
label: Text('Ch. ${widget.chapters[_currentChapterIndex + 1]['chapter']}'),
```

Lỗi **thực sự** nằm ở `_ChapterDrawerContent`: khi drawer lọc filtered list và user bấm vào một chương, nó tìm `index` trong `widget.chapters` nguyên gốc:

```dart
final index = widget.chapters.indexWhere((c) => c['id'] == chap['id']);
```

Nếu drawer đang sort theo `_sortAsc = false` (descending, mặc định), `filtered` sẽ theo thứ tự ngược. User bấm chương tiếp theo nhưng `index` tìm được vẫn là index trong list gốc (ascending) → đúng.

**Vấn đề thực sự** là: sau khi `_goToChapter()` update `_currentChapterIndex`, nút Prev/Next tính dựa trên index mới. Nhưng kiểm tra `_hasNext`:
```dart
bool get _hasNext => _currentChapterIndex < widget.chapters.length - 1;
```
Điều này đúng. Kiểm tra thêm `_goToChapter`:
```dart
void _goToChapter(int index) {
  if (index < 0 || index >= widget.chapters.length) return;
  final chap = widget.chapters[index];
  setState(() {
    _currentChapterId = chap['id'];
    _currentChapterTitle = chap['chapter'];
    _currentChapterIndex = index;   // ✅ index được cập nhật
  });
  _fetchImages();   // ✅ fetch images của chapter mới
  _saveHistory();
}
```

**Root cause thực sự:** `_fetchImages()` gọi `ChapterService.getChapterPages(_currentChapterId)` nhưng trong `setState()` ở trên, `_currentChapterId` đã được set. Tuy nhiên do Flutter's `setState()` là async, có thể `_fetchImages()` chạy với `_currentChapterId` cũ.

**Fix đảm bảo an toàn** – truyền chapterId trực tiếp:
```dart
void _goToChapter(int index) {
  if (index < 0 || index >= widget.chapters.length) return;
  final chap = widget.chapters[index];
  final newChapterId = chap['id'].toString();
  final newChapterTitle = chap['chapter'].toString();
  setState(() {
    _currentChapterId = newChapterId;
    _currentChapterTitle = newChapterTitle;
    _currentChapterIndex = index;
    _currentPage = 0;       // Reset về trang đầu khi đổi chương
    _imageUrls = [];        // Clear ảnh cũ để tránh flash
    _isLoading = true;
  });
  // Scroll về đầu trang ngay lập tức
  if (_scrollController.hasClients) {
    _scrollController.jumpTo(0);
  }
  _fetchImagesForChapter(newChapterId);  // Truyền ID trực tiếp
  _saveHistory();
}

Future<void> _fetchImagesForChapter(String chapterId) async {
  final urls = await ChapterService.getChapterPages(chapterId);
  if (!mounted) return;
  // Chỉ update nếu vẫn đang xem chương này (user chưa chuyển sang chương khác)
  if (_currentChapterId == chapterId) {
    setState(() {
      _imageUrls = urls;
      _isLoading = false;
      _currentPage = 0;
    });
    if (_readMode == _ReadMode.singlePage) {
      _pageController = PageController();
    }
  }
}

// Đổi _fetchImages() gọi _fetchImagesForChapter(_currentChapterId):
Future<void> _fetchImages() async {
  setState(() => _isLoading = true);
  await _fetchImagesForChapter(_currentChapterId);
}
```

---

## LỖI 3 – Tìm kiếm không load được creator name và description 🟠

**File:** `lib/screens/explore/search_screen.dart`

**Nguyên nhân quan sát từ ảnh:** Search results hiển thị "Unknown" cho author và "No description available." cho description. Backend `/mangas/search` trả về `creators: [{id, name, role}]` và `descriptions: [{LangCode, Description}]` nhưng `Manga.fromJson()` cần parse đúng format.

**Kiểm tra:** `Manga.fromJson()` trong `lib/models/manga.dart` đã có logic parse `creators` và `descriptions` đúng. Vậy vấn đề nằm ở chỗ backend `/mangas/search` có thể **không trả về** `creators` và `descriptions` trong kết quả search (chỉ trả về trong `/mangas/{id}` detail).

**Fix trong `search_screen.dart` – Hiển thị author từ field đơn giản hơn:**

Backend search có thể chỉ trả `author` hoặc `artist` dưới dạng string thay vì nested `creators`. Cần xử lý fallback tốt hơn trong `Manga.fromJson()`:

```dart
// Trong lib/models/manga.dart, trong factory Manga.fromJson():
// Thêm fallback sau khi extract từ creators:
author: _extractCreatorByRole(creators, 'author',
    fallback: _string(
      json['Author'] ?? json['author'] ??
      json['author_name'] ?? json['AuthorName'],
      fallback: creators.isNotEmpty ? creators.first['name'] ?? 'Unknown' : 'Unknown',
    )),
```

**Fix hiển thị trong `_MangaListCard`** (search_screen.dart): Thêm fallback khi author là empty:
```dart
// Trong _MangaListCard._buildContent():
Text(
  manga.author.isEmpty ? 'Tác giả: Đang cập nhật' : manga.author,
  style: const TextStyle(color: Colors.white54, fontSize: 11),
  maxLines: 1,
),
Text(
  manga.description.isEmpty || manga.description == 'No description available.'
      ? 'Chưa có mô tả.'
      : manga.description,
  ...
),
```

**Nguyên nhân thực sự cần kiểm tra:** Gọi `curl http://localhost:8000/api/v1/mangas/search?q=test` và kiểm tra response có `creators[]` và `descriptions[]` không. Nếu không có, phải dùng MangaDex API để enrich data sau khi search, hoặc chấp nhận dữ liệu thiếu.

**Fix bổ sung – Search fallback về MangaDex** khi backend không có đủ metadata:
```dart
// Trong _SearchScreenState._performSearch(), sau khi có results:
// Nếu kết quả ít hơn 5 và user đã nhập query, thử enrich từ MangaDex
// (optional enhancement, không bắt buộc)
```

---

## LỖI 4 – Chat rooms list hiển thị raw object thay vì preview tin nhắn 🟠

**File:** `lib/screens/chat/chat_screen.dart` – trong `_ChatRoomsScreenState._buildRoomTile()`

**Từ ảnh:** Subtitle hiển thị `{content: né, sender_id: 8fa0d0c7-ed84-437b...}` thay vì nội dung tin nhắn.

**Nguyên nhân:** `lastMsg` được lấy từ `room['LastMessage'] ?? room['last_message']`. Backend trả `last_message` là một **object** `{content, sender_id, sent_at, ...}` không phải string.

**Fix `_buildRoomTile()`:**
```dart
Widget _buildRoomTile(Map<String, dynamic> room) {
  final name = room['Name'] ?? room['name'] ?? 'Chat Room';
  final roomId = room['RoomId']?.toString() ?? room['room_id']?.toString() ?? '';
  
  // last_message là object, cần extract .content
  final lastMsgRaw = room['LastMessage'] ?? room['last_message'];
  String lastMsgText = '';
  if (lastMsgRaw is Map) {
    lastMsgText = lastMsgRaw['content']?.toString() ??
                  lastMsgRaw['Content']?.toString() ?? '';
  } else if (lastMsgRaw is String) {
    lastMsgText = lastMsgRaw;
  }

  // Unread count
  final unread = room['unread_count'] ?? room['UnreadCount'] ?? 0;

  return ListTile(
    leading: CircleAvatar(
      backgroundColor: _kOrange.withValues(alpha: 0.2),
      child: const Icon(Icons.chat_bubble_outline, color: _kOrange),
    ),
    title: Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
    subtitle: lastMsgText.isNotEmpty
        ? Text(
            lastMsgText,
            style: const TextStyle(color: Colors.white38, fontSize: 12),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          )
        : const Text('Chưa có tin nhắn', style: TextStyle(color: Colors.white24, fontSize: 12)),
    trailing: unread > 0
        ? Container(
            padding: const EdgeInsets.all(6),
            decoration: const BoxDecoration(color: _kOrange, shape: BoxShape.circle),
            child: Text('$unread', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
          )
        : null,
    onTap: () => Navigator.push(context, MaterialPageRoute(
      builder: (_) => ChatScreen(roomId: roomId, roomName: name),
    )).then((_) => _loadRooms()),
  );
}
```

---

## LỖI 5 – Không upload được avatar (Unsupported operation: Platform._pathSeparator) 🔴

**File:** `lib/services/auth_service.dart` – method `uploadAvatar()`

**Nguyên nhân:** Dòng này crash trên **Flutter Web**:
```dart
filename: file.path.split(Platform.pathSeparator).last,
```
`Platform.pathSeparator` không hoạt động trên web vì không có filesystem thật. Error: `Unsupported operation: Platform._pathSeparator`.

**Fix `uploadAvatar()` trong `auth_service.dart`:**
```dart
/// POST /auth/me/avatar  multipart: file → {success, avatar_url}
static Future<String?> uploadAvatar(dynamic file) async {
  try {
    MultipartFile multipartFile;
    
    if (kIsWeb) {
      // Flutter Web: dùng XFile từ image_picker
      // file là XFile
      final xFile = file as dynamic; // XFile
      final bytes = await xFile.readAsBytes();
      final filename = xFile.name.isNotEmpty ? xFile.name : 'avatar.jpg';
      multipartFile = MultipartFile.fromBytes(bytes, filename: filename);
    } else {
      // Mobile/Desktop: dùng File
      final ioFile = file as File;
      // Dùng path_provider-safe cách lấy filename
      final filename = ioFile.path.split('/').last.split('\\').last;
      multipartFile = await MultipartFile.fromFile(ioFile.path, filename: filename);
    }
    
    final formData = FormData.fromMap({'file': multipartFile});
    final response = await _dio.post(
      '/auth/me/avatar',
      data: formData,
      options: Options(contentType: 'multipart/form-data'),
    );
    return response.data['avatar_url'] as String?;
  } on DioException catch (e) {
    debugPrint('Avatar upload error: ${e.response?.data}');
    throw Exception(e.response?.data?['detail'] ?? 'Failed to upload avatar');
  }
}
```

**Fix `profile_screen.dart` – `_uploadAvatar()`:**

Cần dùng `XFile` thống nhất thay vì ép sang `File` (crash trên web):
```dart
Future<void> _uploadAvatar() async {
  try {
    final picker = ImagePicker();
    final imageFile = await picker.pickImage(
      source: ImageSource.gallery, maxWidth: 512, maxHeight: 512, imageQuality: 85,
    );
    if (imageFile == null) return;
    if (!mounted) return;

    setState(() => _isUploading = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Đang tải ảnh lên...')),
    );

    // Truyền XFile trực tiếp, không ép sang File (crash trên Web)
    await context.read<AuthProvider>().uploadAvatar(imageFile);

    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Cập nhật Avatar thành công!'), backgroundColor: Colors.green),
    );
  } catch (e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Lỗi upload: $e'), backgroundColor: Colors.red),
    );
  } finally {
    if (mounted) setState(() => _isUploading = false);
  }
}
```

**Thêm import vào `auth_service.dart`:**
```dart
import 'package:flutter/foundation.dart'; // kIsWeb
import 'dart:io'; // File (chỉ dùng trên non-web)
```

---

## LỖI 6 – Không load được cover và thông tin trong phần "Gợi ý cho bạn" ở Explore 🟠

**File:** `lib/screens/explore/explore_screen.dart`

**Từ ảnh:** Section "Gợi ý cho bạn" hiển thị title đúng nhưng cover không load (ảnh vỡ màu đỏ), author là "Unknown".

**Nguyên nhân:** `getRecommendations()` trả về list recommendation objects. Backend `/recommendations/for-me` có thể trả về format khác:
```json
{
  "recommendations": [
    {"manga_id": "...", "score": 0.9, "title": "...", "cover_url": "..."}
  ]
}
```
Không có đủ fields để `Manga.fromJson()` parse cover_url và author.

**Fix trong `manga_service.dart` – `getRecommendations()`:**
```dart
static Future<List<Map<String, dynamic>>> getRecommendations({int limit = 20}) async {
  try {
    final response = await _dio.get('/recommendations/for-me', queryParameters: {'top_n': limit});
    final data = response.data;
    List<Map<String, dynamic>> recs = [];
    
    if (data is List) {
      recs = data.cast<Map<String, dynamic>>();
    } else if (data is Map && data['recommendations'] is List) {
      recs = (data['recommendations'] as List).cast<Map<String, dynamic>>();
    } else if (data is Map && data['items'] is List) {
      recs = (data['items'] as List).cast<Map<String, dynamic>>();
    }
    
    // Nếu recommendation object chỉ có manga_id, fetch full detail
    // Nhưng để tránh N+1 requests, chỉ enrich nếu cover_url thiếu
    final enriched = <Map<String, dynamic>>[];
    for (final rec in recs) {
      if (rec['cover_url'] != null && rec['cover_url'].toString().isNotEmpty) {
        enriched.add(rec);
      } else {
        // Thử lấy manga_id và fetch detail
        final mangaId = rec['manga_id']?.toString() ?? rec['MangaId']?.toString() ?? '';
        if (mangaId.isNotEmpty) {
          try {
            final detail = await _dio.get('/mangas/$mangaId');
            enriched.add(detail.data as Map<String, dynamic>);
          } catch (_) {
            enriched.add(rec); // fallback với data thiếu
          }
        }
      }
    }
    return enriched;
  } on DioException catch (e) {
    debugPrint('MangaService.getRecommendations error: ${e.response?.data}');
    return [];
  }
}
```

**Lưu ý quan trọng:** N+1 requests sẽ chậm nếu có nhiều recommendations. Giải pháp tốt hơn là đảm bảo backend endpoint `/recommendations/for-me` trả về đủ `cover_url`, `title`, `creators`, `descriptions` inline. Nếu được, đây là fix phía backend.

**Fix tạm thời không N+1 – dùng MangaDex CDN cho cover:**

Trong `Manga.fromJson()`, thêm fallback:
```dart
// Sau khi lấy coverUrl từ backend:
coverUrl: _buildCoverUrlSafe(
  _string(json['cover_url'] ?? json['CoverUrl']),
  _string(json['MangaId'] ?? json['manga_id'] ?? json['id']),
),

static String _buildCoverUrlSafe(String rawUrl, String mangaId) {
  // Nếu URL hợp lệ và không phải localhost
  if (rawUrl.isNotEmpty && 
      !rawUrl.contains('localhost') && 
      !rawUrl.contains('127.0.0.1') &&
      !rawUrl.contains('10.0.2.2')) {
    return rawUrl;
  }
  // Không có cover → placeholder
  return 'https://via.placeholder.com/256x360/2C2C2C/FF6740?text=No+Cover';
}
```

---

## LỖI 7 – UX/UI "Cộng đồng" list quá đơn điệu, thiếu follow/unfollow và phân quyền 🟡

**File:** `lib/screens/library/library_screen.dart` và `lib/screens/library/list_detail_screen.dart`

### 7A – Tab Cộng đồng: Thêm search + follow button + pagination

**Sửa `_LibraryScreenState`** – thêm search và follow cho public lists:

```dart
// Thêm state:
final _publicSearchCtrl = TextEditingController();
String _publicSearchQuery = '';
int _publicPage = 1;
bool _publicHasMore = true;

// Sửa _loadPublicLists():
Future<void> _loadPublicLists({bool refresh = false}) async {
  if (refresh) {
    _publicPage = 1;
    _publicHasMore = true;
    _publicLists = [];
  }
  if (!_publicHasMore) return;
  setState(() => _isLoadingPublic = true);
  try {
    final res = await ListService.getPublicLists(
      page: _publicPage,
      query: _publicSearchQuery.isNotEmpty ? _publicSearchQuery : null,
    );
    final items = ((res['items'] ?? []) as List)
        .cast<Map<String, dynamic>>()
        .map((item) => <String, dynamic>{
              'id': item['ListId']?.toString() ?? item['list_id']?.toString() ?? '',
              'name': item['Name'] ?? item['name'] ?? '',
              'description': item['Description'] ?? item['description'] ?? '',
              'item_count': item['ItemCount'] ?? item['item_count'] ?? 0,
              'owner_username': item['owner_username'] ?? 
                                item['owner']?['username'] ?? 
                                item['OwnerUsername'] ?? 'Ẩn danh',
              'is_following': item['is_following'] ?? item['IsFollowing'] ?? false,
            })
        .where((item) => item['id'].toString().isNotEmpty)
        .toList();
    
    final totalPages = res['total_pages'] ?? 1;
    if (mounted) {
      setState(() {
        if (refresh) {
          _publicLists = items;
        } else {
          _publicLists.addAll(items);
        }
        _publicHasMore = _publicPage < totalPages;
        _publicPage++;
        _isLoadingPublic = false;
      });
    }
  } catch (e) {
    if (mounted) setState(() => _isLoadingPublic = false);
  }
}
```

**Sửa Tab "Cộng đồng" trong `build()`:**
```dart
// Tab 2: Cộng đồng
Column(
  children: [
    // Search bar
    Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      child: TextField(
        controller: _publicSearchCtrl,
        onChanged: (v) {
          _publicSearchQuery = v;
          _loadPublicLists(refresh: true);
        },
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: 'Tìm danh sách cộng đồng...',
          hintStyle: const TextStyle(color: Colors.white38),
          prefixIcon: const Icon(Icons.search, color: Colors.white38, size: 20),
          suffixIcon: _publicSearchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, color: Colors.white38, size: 18),
                  onPressed: () {
                    _publicSearchCtrl.clear();
                    _publicSearchQuery = '';
                    _loadPublicLists(refresh: true);
                  },
                )
              : null,
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
        ),
      ),
    ),
    Expanded(
      child: _isLoadingPublic && _publicLists.isEmpty
          ? const Center(child: CircularProgressIndicator(color: _kOrange))
          : _publicLists.isEmpty
              ? const Center(child: Text('Không có danh sách cộng đồng nào.', style: TextStyle(color: Colors.white54)))
              : RefreshIndicator(
                  onRefresh: () => _loadPublicLists(refresh: true),
                  color: _kOrange,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    itemCount: _publicLists.length + (_publicHasMore ? 1 : 0),
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (ctx, i) {
                      if (i == _publicLists.length) {
                        // Load more
                        _loadPublicLists();
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: CircularProgressIndicator(color: _kOrange),
                          ),
                        );
                      }
                      final lst = _publicLists[i];
                      return _PublicListCard(
                        lst: lst,
                        onFollowToggle: () => _toggleFollowPublicList(lst),
                        onTap: () => _navigateToDetail(lst),
                      );
                    },
                  ),
                ),
    ),
  ],
),
```

**Thêm method `_toggleFollowPublicList()`:**
```dart
Future<void> _toggleFollowPublicList(Map<String, dynamic> lst) async {
  final listId = lst['id'].toString();
  final isFollowing = lst['is_following'] == true;
  try {
    if (isFollowing) {
      await ListService.unfollowList(listId);
    } else {
      await ListService.followList(listId);
    }
    setState(() => lst['is_following'] = !isFollowing);
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red));
    }
  }
}
```

**Tạo widget `_PublicListCard`** (thêm vào cuối file):
```dart
class _PublicListCard extends StatelessWidget {
  final Map<String, dynamic> lst;
  final VoidCallback onFollowToggle;
  final VoidCallback onTap;

  const _PublicListCard({
    required this.lst,
    required this.onFollowToggle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isFollowing = lst['is_following'] == true;
    return Card(
      color: _kCard,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              // Folder icon
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFF3A3A3A),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.folder_special, color: _kOrange, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(lst['name'] ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 3),
                    Text(
                      '${lst['item_count'] ?? 0} truyện • ${lst['owner_username'] ?? 'Ẩn danh'}',
                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                    if ((lst['description'] ?? '').toString().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Text(
                          lst['description'],
                          style: const TextStyle(color: Colors.white38, fontSize: 11),
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Follow/Unfollow button
              GestureDetector(
                onTap: onFollowToggle,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isFollowing ? _kOrange.withValues(alpha: 0.15) : _kOrange,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _kOrange),
                  ),
                  child: Text(
                    isFollowing ? 'Đang theo' : 'Theo dõi',
                    style: TextStyle(
                      color: isFollowing ? _kOrange : Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

### 7B – Phân quyền trong `list_detail_screen.dart`

Hiện tại `list_detail_screen.dart` cho phép xóa/sửa manga trong list ngay cả khi đang xem list của người khác. Cần thêm check `isOwner`.

**Trong `ListDetailScreen` và `_ListDetailScreenState`:**
```dart
// Thêm vào constructor:
class ListDetailScreen extends StatefulWidget {
  final String listId;
  final String listName;
  final bool isOwner; // thêm field này, default true cho list của mình

  const ListDetailScreen({
    super.key,
    required this.listId,
    required this.listName,
    this.isOwner = true, // mặc định true (list của mình)
  });
}
```

**Khi navigate từ tab Cộng đồng (library_screen.dart):**
```dart
// Trong _navigateToDetail(), phân biệt:
void _navigateToDetail(Map<String, dynamic> lst) {
  final isMyList = context.read<AppProvider>().customLists
      .any((l) => l['id'] == lst['id']);
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => ListDetailScreen(
        listId: lst['id'],
        listName: lst['name'],
        isOwner: isMyList,  // chỉ true nếu là list của mình
      ),
    ),
  ).then((_) {
    if (mounted) {
      context.read<AppProvider>().fetchLists().then((_) => _loadCovers());
    }
  });
}
```

**Trong `list_detail_screen.dart`, ẩn edit/delete khi không phải owner:**
```dart
// Tìm chỗ hiển thị nút xóa manga khỏi list và nút chỉnh sửa, thêm điều kiện:
if (widget.isOwner) ...[
  // Nút xóa/sửa manga
  IconButton(
    icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent, size: 20),
    onPressed: () => _removeManga(item),
  ),
],
```

---

## LỖI 8 – Tạo list chỉ có nhập tên, thiếu Visibility (Public/Private) và Description 🟡

**File:** `lib/screens/library/library_screen.dart` – method `_showListDialog()`

**Fix `_showListDialog()`** – thêm visibility selector và description:
```dart
void _showListDialog({String? currentId, String? currentName, String? currentVisibility, String? currentDescription}) {
  final nameCtrl = TextEditingController(text: currentName ?? '');
  final descCtrl = TextEditingController(text: currentDescription ?? '');
  String visibility = currentVisibility ?? 'private';
  final isEdit = currentId != null;

  showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx2, setDialog) => AlertDialog(
        backgroundColor: _kCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(
          isEdit ? 'Chỉnh sửa danh sách' : 'Tạo danh sách mới',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Tên
              TextField(
                controller: nameCtrl,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'Tên danh sách *',
                  hintStyle: TextStyle(color: Colors.white38),
                ),
              ),
              const SizedBox(height: 12),
              // Mô tả
              TextField(
                controller: descCtrl,
                maxLines: 2,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'Mô tả (tùy chọn)',
                  hintStyle: TextStyle(color: Colors.white38),
                ),
              ),
              const SizedBox(height: 16),
              // Visibility
              const Text('Quyền truy cập', style: TextStyle(color: Colors.white54, fontSize: 13)),
              const SizedBox(height: 8),
              Row(
                children: [
                  _VisibilityOption(
                    label: 'Riêng tư',
                    icon: Icons.lock_outline,
                    isSelected: visibility == 'private',
                    onTap: () => setDialog(() => visibility = 'private'),
                  ),
                  const SizedBox(width: 10),
                  _VisibilityOption(
                    label: 'Công khai',
                    icon: Icons.public,
                    isSelected: visibility == 'public',
                    onTap: () => setDialog(() => visibility = 'public'),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () => _submitListDialogV2(
              ctx, nameCtrl, descCtrl, visibility, isEdit, currentId,
            ),
            style: ElevatedButton.styleFrom(backgroundColor: _kOrange),
            child: Text(isEdit ? 'Lưu' : 'Tạo', style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    ),
  );
}

Future<void> _submitListDialogV2(
  BuildContext ctx,
  TextEditingController nameCtrl,
  TextEditingController descCtrl,
  String visibility,
  bool isEdit,
  String? currentId,
) async {
  final name = nameCtrl.text.trim();
  if (name.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Tên không được để trống!')));
    return;
  }
  try {
    if (isEdit) {
      await ListService.updateList(
        currentId!,
        name: name,
        description: descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
        visibility: visibility,
      );
    } else {
      await context.read<AppProvider>().createList(
        name,
        description: descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
        visibility: visibility,
      );
      _loadCovers();
    }
    if (!ctx.mounted) return;
    Navigator.pop(ctx);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(isEdit ? 'Đã cập nhật danh sách!' : 'Đã tạo danh sách!'),
        backgroundColor: Colors.green,
      ),
    );
  } catch (e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red));
  }
}
```

**Thêm widget `_VisibilityOption`** (private helper):
```dart
class _VisibilityOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _VisibilityOption({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? _kOrange.withValues(alpha: 0.15) : const Color(0xFF3A3A3A),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isSelected ? _kOrange : Colors.white24),
          ),
          child: Column(
            children: [
              Icon(icon, color: isSelected ? _kOrange : Colors.white54, size: 20),
              const SizedBox(height: 4),
              Text(label, style: TextStyle(color: isSelected ? _kOrange : Colors.white54, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}
```

**Update `AppProvider.createList()` để nhận description và visibility:**
```dart
// Trong app_provider.dart:
Future<void> createList(String name, {String? description, String visibility = 'private'}) async {
  await ListService.createList(name, description: description, visibility: visibility);
  await fetchLists();
}
```

**Update cách gọi `_showListDialog` từ edit button** để truyền visibility hiện tại:
```dart
// Trong _buildListView và _buildGridView, khi gọi onEdit:
onEdit: () => _showListDialog(
  currentId: lists[i]['id'],
  currentName: lists[i]['name'],
  currentVisibility: lists[i]['visibility'] ?? 'private',
  currentDescription: lists[i]['description'],
),
```

---

## CÁC LỖI PHỤ VÀ TIỀM NĂNG PHÁT HIỆN THÊM

### P1 – `friends_screen.dart` – Accept/Reject dùng sai field 🔴

Đã phát hiện ở audit trước, vẫn chưa fix:
```dart
// HIỆN TẠI (SAI) – _buildPendingReceived():
final reqId = r['RequestId']?.toString() ?? r['request_id']?.toString() ?? '';
await FriendService.acceptRequest(reqId);

// FIX: backend /friends/requests trả về user_id, không phải request_id
final userId = r['user_id']?.toString() ?? r['UserId']?.toString() ?? '';
await FriendService.acceptRequest(userId);
await FriendService.rejectRequest(userId);
```

### P2 – `friends_screen.dart` – Mở chat với bạn dùng friendId làm roomId 🔴

```dart
// HIỆN TẠI (SAI):
Navigator.push(context, MaterialPageRoute(
  builder: (_) => ChatScreen(roomId: friendId, roomName: name)));

// FIX: tạo DM room trước
Future<void> _openDirectChat(String friendId, String friendName) async {
  try {
    final result = await ChatService.createRoom(type: 'direct', userIds: [friendId]);
    if (!mounted) return;
    final roomId = result?['room_id']?.toString() ?? result?['RoomId']?.toString() ?? result?['id']?.toString() ?? '';
    if (roomId.isNotEmpty) {
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => ChatScreen(roomId: roomId, roomName: friendName)));
    }
  } catch (e) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Không thể mở chat: $e'), backgroundColor: Colors.red));
  }
}
```
Thay `onPressed: () { Navigator.push(...) }` bằng `onPressed: () => _openDirectChat(friendId, name)`.

### P3 – `manga_service.dart` – `getRecentManga()` sort param sai 🟠

```dart
// HIỆN TẠI:
'sort': 'recent',
// FIX:
'sort': 'updated_desc',
```

### P4 – `manga_service.dart` – `searchManga()` thử `/mangas/advanced-search` trước gây lãng phí request 🟡

```dart
// FIX: đổi primary endpoint về /mangas/search trực tiếp, bỏ try/catch 404 wrapper
try {
  final response = await _dio.get('/mangas/search', queryParameters: params);
  return _normalizePaginated(response.data);
} on DioException catch (e) {
  debugPrint('MangaService.searchManga error: ${e.response?.data}');
  return _paginatedFallback();
}
```

### P5 – `explore_screen.dart` – Horizontal list cards hiển thị "Unknown" cho author 🟡

Vì `getRecommendations()` và `getRecentManga()` trả data thiếu `creators`, cần add fallback text trong `_MangaHorizontalCard`:
```dart
Text(
  manga.author.isEmpty ? 'Tác giả chưa rõ' : manga.author,
  style: const TextStyle(fontSize: 11, color: Colors.white54),
  maxLines: 1, overflow: TextOverflow.ellipsis,
),
```

### P6 – `chat_screen.dart` – WebSocket URL dùng `AppConstants.wsBaseUrl` 🟡

Kiểm tra `constants.dart`: `wsBaseUrl` dùng `ws://10.0.2.2:8000/ws` cho non-web. Đúng cho Android emulator. Nhưng nếu chạy trên thiết bị thật qua WiFi LAN, cần thay `10.0.2.2` bằng IP thật của máy host.

Thêm một constant cho development:
```dart
// Trong constants.dart:
static String get wsBaseUrl {
  if (kIsWeb) return 'ws://localhost:8000/ws';
  // For physical device on same network, replace with your machine's IP
  // e.g., 'ws://192.168.1.x:8000/ws'
  return 'ws://10.0.2.2:8000/ws'; // Android emulator default
}
```

### P7 – `library_screen.dart` – List card không hiển thị visibility badge 🟡

Thêm badge "Public" / "Private" vào `_ListCard`:
```dart
// Trong _ListCard.build(), dưới Text(lst['name']):
Row(
  children: [
    if ((lst['visibility'] ?? 'private') == 'public')
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        margin: const EdgeInsets.only(top: 4),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.green.withValues(alpha: 0.5)),
        ),
        child: const Text('Public', style: TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold)),
      ),
    const SizedBox(width: 6),
    Text(
      _formatDate(lst['created_at']),
      style: const TextStyle(color: Colors.white38, fontSize: 11),
    ),
  ],
),
```

---

## THỨ TỰ FIX ĐỀ NGHỊ

```
🔴 PRIORITY 1 – Fix ngay (crash / không hoạt động)
├── LỖI 5: auth_service.dart + profile_screen.dart – Avatar upload crash trên Web
├── P1: friends_screen.dart – Accept/Reject request dùng sai field
├── P2: friends_screen.dart – Chat với bạn dùng friendId làm roomId

🔴 PRIORITY 2 – Fix để feature hoạt động đúng
├── LỖI 1: chat_screen.dart – Gửi tin nhắn không hiển thị
├── LỖI 2: reader_screen.dart – Chuyển chương bị race condition
├── LỖI 4: chat_screen.dart – last_message hiển thị raw object

🟠 PRIORITY 3 – Fix UX quan trọng
├── LỖI 3: search_screen.dart + manga.dart – Author/Description trong search
├── LỖI 6: manga_service.dart – Recommendation thiếu cover/metadata
├── P3: manga_service.dart – getRecentManga sort param
├── P4: manga_service.dart – searchManga endpoint

🟡 PRIORITY 4 – UX Enhancement
├── LỖI 7: library_screen.dart – Public list UX + follow + phân quyền
├── LỖI 8: library_screen.dart – Tạo list với visibility + description
├── P5: explore_screen.dart – Author fallback text
├── P7: library_screen.dart – Visibility badge
```

---

## QUICK REFERENCE – Danh sách file cần sửa

| File | Lỗi # |
|------|-------|
| `lib/services/auth_service.dart` | LỖI 5 |
| `lib/screens/profile/profile_screen.dart` | LỖI 5 |
| `lib/screens/chat/chat_screen.dart` | LỖI 1, LỖI 4 |
| `lib/screens/reader/reader_screen.dart` | LỖI 2 |
| `lib/services/manga_service.dart` | LỖI 6, P3, P4 |
| `lib/models/manga.dart` | LỖI 3, LỖI 6 |
| `lib/screens/library/library_screen.dart` | LỖI 7, LỖI 8, P7 |
| `lib/screens/library/list_detail_screen.dart` | LỖI 7B |
| `lib/screens/friends/friends_screen.dart` | P1, P2 |
| `lib/screens/explore/explore_screen.dart` | P5 |
| `lib/providers/app_provider.dart` | LỖI 8 (createList signature) |
