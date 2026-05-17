# FLUTTER APP – IMPLEMENTATION PLAN
## Chuyển đổi, Nâng cấp & Mở rộng

> **Mục đích tài liệu:** Hướng dẫn đầy đủ cho AI agent thực thi từng bước. Mỗi task đều có context đủ để thực hiện độc lập. Không bỏ qua bước nào.

---

## PHẦN 0 – PHÂN TÍCH TÌNH TRẠNG HIỆN TẠI

### 0.1 Flutter App (ktgk_2324802010044)

**Tech stack:** Flutter (SDK ^3.11.4), Provider, Dio, Supabase Flutter, CachedNetworkImage, GoogleFonts

**Cấu trúc hiện tại:**
```
lib/
├── main.dart                      # MaterialApp + Supabase.initialize
├── models/manga.dart              # Model Manga duy nhất (MangaDex-centric)
├── providers/app_provider.dart    # ChangeNotifier – gọi Supabase trực tiếp
├── services/
│   ├── mangadex_api.dart          # Gọi api.mangadex.org trực tiếp qua Dio
│   └── supabase_service.dart      # RỖNG (chưa implement)
└── screens/
    ├── auth/auth_screen.dart      # Login/Register qua Supabase Auth
    ├── detail/detail_screen.dart  # Chi tiết manga + chapter list
    ├── explore/explore_screen.dart & search_screen.dart
    ├── history/history_screen.dart
    ├── library/library_screen.dart & list_detail_screen.dart
    ├── main_tab_screen.dart       # Bottom navigation (4 tabs)
    ├── profile/profile_screen.dart
    └── reader/reader_screen.dart  # Đọc truyện
```

**Các vấn đề cần giải quyết:**
- Auth hoàn toàn dùng **Supabase Auth** (JWT Supabase), trong khi backend dùng **JWT riêng** (`Bearer token`)
- `app_provider.dart` gọi thẳng Supabase SDK cho lists, history, profile
- `supabase_service.dart` hoàn toàn rỗng – không dùng được
- `MangaDexApi` gọi thẳng api.mangadex.org – không qua proxy backend
- Model `Manga` chỉ có metadata MangaDex, chưa có các field của backend (ratings, stats, v.v.)
- Không có: Comments, Ratings, Chat, Friends, Recommendations

**Supabase DB hiện tại (các bảng Flutter đang dùng):**
- `profiles` (id, username, avatar_url, bio)
- `custom_lists` (id, user_id, name, created_at)
- `list_items` (id, list_id, manga_id, title, cover_url, status, genres)
- `reading_history` (id, user_id, manga_id, manga_title, manga_cover_url, chapter_id, chapter_number, chapter_title, page_index, read_at)

---

### 0.2 Backend (manga_backend – FastAPI)

**Tech stack:** FastAPI, SQLAlchemy Async, MS SQL Server (aioodbc), MinIO, JWT (python-jose), bcrypt

**Base URL:** `http://localhost:8000` | Prefix: `/api/v1`

**Tất cả các router đã có:**
| Router | Prefix | Ghi chú |
|--------|--------|---------|
| auth | `/api/v1/auth` | register, login, /me GET/PUT, avatar upload |
| manga | `/api/v1/mangas` | browse, search, detail, related, random |
| chapter | `/api/v1` | `/manga/{id}/chapters`, `/manga/{id}/chapters/{cid}` (có prev/next + pages) |
| comment | `/api/v1/comments` | CRUD + like/dislike/report |
| rating | `/api/v1/ratings` | rate (upsert) + my-rating |
| history | `/api/v1/history` | POST, GET (paginated), GET grouped, continue reading |
| list | `/api/v1/lists` | CRUD + add/remove item + follow/unfollow + public lists |
| tag | `/api/v1/tags` | list tất cả tags grouped |
| cover | `/api/v1/covers` | primary cover + all covers (MinIO → MangaDex fallback) |
| proxy | `/api/v1/proxy` | `chapter-pages/{id}` + `image` proxy |
| analytics | `/api/v1/analytics` | stats tổng hợp |
| recommendation | `/api/v1/recommendations` | for-me (collab filter) + similar manga |
| creators | `/api/v1/creators` | creator profile + manga list |
| chat | `/api/v1/chat` | rooms CRUD + messages + media upload |
| friends | `/api/v1/friends` | list, requests, send/accept/reject/block, search users |
| admin | `/api/v1/admin` | (chỉ dành cho admin role) |
| WebSocket | `/ws/chat/{room_id}?token=JWT` | room-based chat với JWT auth |

**Tình trạng DB:**
- Manga data đã có (imported từ MangaDex) – MangaId là UUID giống MangaDex
- Chapters đã có metadata, nhưng **pages trong MinIO còn thiếu** → backend fallback về MangaDex at-home API
- Covers còn thiếu trong MinIO → backend fallback về `uploads.mangadex.org`
- Auth là JWT riêng (không liên quan Supabase)

**Điểm mấu chốt:** Backend manga ID = MangaDex manga ID (cùng UUID) → Flutter có thể dùng MangaDex API để browse/search và backend API để lưu data cá nhân mà không cần mapping ID.

---

### 0.3 Frontend Web (manga_frontend – Next.js 16)

**Đã implement đầy đủ:**
- Auth (login/register + JWT stored in localStorage)
- Manga browse/search/detail (dùng backend `/api/v1/mangas`)
- Chapter reader (dùng backend `/api/v1/manga/{id}/chapters/{cid}`)
- Comments, Ratings, Lists (CRUD đầy đủ)
- Chat (WebSocket + REST)
- Friends system
- Admin page
- Profile page
- Reading history

**Phương pháp kết hợp API (frontend đang dùng):**
- Browse/Search: backend `/api/v1/mangas` (data từ DB, cover từ MinIO/MangaDex fallback)
- Read chapters: backend `/api/v1/proxy/chapter-pages/{id}` hoặc fallback về MangaDex at-home
- Tất cả user data: backend API (auth JWT)

**→ Flutter cần theo cùng pattern này**

---

## PHẦN 1 – KIẾN TRÚC MỤC TIÊU

### 1.1 Nguyên tắc lai (Hybrid Strategy)

```
┌─────────────────────────────────────────────────────────────────┐
│                    FLUTTER APP (Mục tiêu)                       │
├─────────────────────────────────────────────────────────────────┤
│  Data Nguồn gốc Manga (browse/search/read):                     │
│    PRIMARY: Backend /api/v1/mangas (cover = MinIO → MangaDex)  │
│    FALLBACK: MangaDex API trực tiếp (nếu backend offline)       │
│                                                                 │
│  Chapter Pages (đọc truyện):                                    │
│    PRIMARY: Backend /api/v1/proxy/chapter-pages/{id}            │
│    FALLBACK: MangaDex at-home API trực tiếp                     │
│                                                                 │
│  User Data (requires auth):                                     │
│    Auth    → Backend /api/v1/auth (JWT)                         │
│    Lists   → Backend /api/v1/lists                              │
│    History → Backend /api/v1/history                            │
│    Comments→ Backend /api/v1/comments                           │
│    Ratings → Backend /api/v1/ratings                            │
│    Chat    → Backend /api/v1/chat + WebSocket                   │
│    Friends → Backend /api/v1/friends                            │
│    Recs    → Backend /api/v1/recommendations                    │
└─────────────────────────────────────────────────────────────────┘
```

### 1.2 Cấu trúc thư mục Flutter mục tiêu

```
lib/
├── main.dart
├── core/
│   ├── constants.dart              # API URLs, keys
│   ├── token_storage.dart          # Lưu/đọc JWT token (SharedPreferences)
│   └── dio_client.dart             # Dio singleton + interceptors
├── models/
│   ├── manga.dart                  # Cập nhật: thêm stats, tags
│   ├── chapter.dart                # NEW: Chapter model
│   ├── comment.dart                # NEW: Comment model
│   ├── rating.dart                 # NEW: Rating model
│   ├── user.dart                   # NEW: User/Profile model (backend)
│   ├── manga_list.dart             # NEW: MangaList model (backend)
│   ├── reading_history.dart        # NEW: ReadingHistory model (backend)
│   ├── chat_room.dart              # NEW: ChatRoom, ChatMessage model
│   └── friend.dart                 # NEW: Friend/Friendship model
├── services/
│   ├── api_service.dart            # Base service (Dio + JWT header)
│   ├── auth_service.dart           # /api/v1/auth
│   ├── manga_service.dart          # /api/v1/mangas
│   ├── chapter_service.dart        # /api/v1/manga/{id}/chapters
│   ├── comment_service.dart        # /api/v1/comments
│   ├── rating_service.dart         # /api/v1/ratings
│   ├── history_service.dart        # /api/v1/history
│   ├── list_service.dart           # /api/v1/lists
│   ├── chat_service.dart           # /api/v1/chat + WebSocket
│   ├── friend_service.dart         # /api/v1/friends
│   ├── recommendation_service.dart # /api/v1/recommendations
│   ├── cover_service.dart          # /api/v1/covers
│   ├── tag_service.dart            # /api/v1/tags
│   └── mangadex_api.dart           # Giữ nguyên (fallback)
├── providers/
│   ├── auth_provider.dart          # NEW: thay thế Supabase auth
│   ├── app_provider.dart           # Refactor: dùng backend services
│   └── chat_provider.dart          # NEW: WebSocket + chat state
├── screens/
│   ├── auth/auth_screen.dart       # Refactor: dùng auth_service
│   ├── detail/detail_screen.dart   # Upgrade: thêm comments, ratings, recommendations
│   ├── explore/
│   │   ├── explore_screen.dart     # Upgrade: dùng backend manga API
│   │   └── search_screen.dart      # Upgrade: backend search
│   ├── history/history_screen.dart # Refactor: dùng history_service
│   ├── library/
│   │   ├── library_screen.dart     # Refactor: dùng list_service
│   │   └── list_detail_screen.dart # Refactor: dùng list_service
│   ├── reader/reader_screen.dart   # Upgrade: proxy + history ghi vào backend
│   ├── profile/profile_screen.dart # Upgrade: backend profile + friends
│   ├── chat/
│   │   ├── chat_list_screen.dart   # NEW: danh sách phòng chat
│   │   └── chat_room_screen.dart   # NEW: giao diện chat
│   ├── friends/
│   │   └── friends_screen.dart     # NEW: friends list + requests + search
│   └── main_tab_screen.dart        # Upgrade: thêm tab Chat
└── widgets/
    ├── manga_card.dart             # Shared widget (tách từ screens)
    ├── chapter_list_tile.dart      # NEW
    ├── comment_tile.dart           # NEW
    ├── rating_panel.dart           # NEW
    └── friend_tile.dart            # NEW
```

---

## PHẦN 2 – PHASE 1: MIGRATION (Supabase → Backend API)

> **Mục tiêu Phase 1:** App vẫn hoạt động như cũ nhưng dùng backend JWT thay Supabase, và gọi backend API cho lists/history/profile.

### TASK 1.1 – Thêm dependencies vào pubspec.yaml

**File cần sửa:** `pubspec.yaml`

**Thêm vào `dependencies:`**
```yaml
shared_preferences: ^2.3.2     # Lưu JWT token
flutter_secure_storage: ^9.2.2 # Optional: lưu token an toàn hơn
web_socket_channel: ^3.0.1     # WebSocket cho chat
sqflite: ^2.3.3+1              # Đã có (giữ nguyên nếu cần)
```

**Xóa (nếu không cần fallback Supabase):**
```yaml
supabase_flutter: ^2.5.0       # XÓA sau khi migration hoàn tất
```

> **LƯU Ý:** Trong Phase 1 giữ `supabase_flutter` như cũ để có thể rollback. Chỉ xóa sau Phase 1 hoàn tất.

---

### TASK 1.2 – Tạo core/constants.dart

**File mới:** `lib/core/constants.dart`

```dart
class AppConstants {
  // Backend API
  static const String backendBaseUrl = 'http://10.0.2.2:8000/api/v1';
  // Đổi thành IP thực khi deploy: 'http://192.168.x.x:8000/api/v1'

  // WebSocket
  static const String wsBaseUrl = 'ws://10.0.2.2:8000/ws';

  // MangaDex (fallback)
  static const String mangadexBaseUrl = 'https://api.mangadex.org';
  static const String mangadexCoverCdn = 'https://uploads.mangadex.org/covers';

  // Storage keys
  static const String tokenKey = 'backend_jwt_token';
  static const String userIdKey = 'backend_user_id';
  static const String usernameKey = 'backend_username';
}
```

> **LƯU Ý Android Emulator:** `10.0.2.2` = localhost của máy host khi chạy Android emulator. Nếu dùng thiết bị thật, đổi thành IP LAN của máy.

---

### TASK 1.3 – Tạo core/token_storage.dart

**File mới:** `lib/core/token_storage.dart`

```dart
import 'package:shared_preferences/shared_preferences.dart';
import 'constants.dart';

class TokenStorage {
  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.tokenKey, token);
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(AppConstants.tokenKey);
  }

  static Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.tokenKey);
    await prefs.remove(AppConstants.userIdKey);
    await prefs.remove(AppConstants.usernameKey);
  }

  static Future<void> saveUserInfo(String userId, String username) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.userIdKey, userId);
    await prefs.setString(AppConstants.usernameKey, username);
  }

  static Future<String?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(AppConstants.userIdKey);
  }

  static Future<String?> getUsername() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(AppConstants.usernameKey);
  }
}
```

---

### TASK 1.4 – Tạo core/dio_client.dart

**File mới:** `lib/core/dio_client.dart`

Tạo Dio singleton với interceptor tự động đính JWT token vào header `Authorization: Bearer`.

```dart
import 'package:dio/dio.dart';
import 'constants.dart';
import 'token_storage.dart';

class DioClient {
  static Dio? _instance;

  static Dio get instance {
    _instance ??= _createDio();
    return _instance!;
  }

  static Dio _createDio() {
    final dio = Dio(BaseOptions(
      baseUrl: AppConstants.backendBaseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Content-Type': 'application/json'},
    ));

    // JWT Interceptor
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await TokenStorage.getToken();
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
      onError: (DioException e, handler) async {
        if (e.response?.statusCode == 401) {
          // Token expired hoặc invalid → clear và redirect login
          await TokenStorage.clearToken();
          // TODO: trigger navigation to login screen via global key
        }
        return handler.next(e);
      },
    ));

    return dio;
  }

  // MangaDex Dio (không cần auth)
  static final Dio mangadex = Dio(BaseOptions(
    baseUrl: AppConstants.mangadexBaseUrl,
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 30),
  ));
}
```

---

### TASK 1.5 – Tạo models/user.dart

**File mới:** `lib/models/user.dart`

Dựa trên schema `UserResponse` của backend (`app/schemas/auth.py`):

```dart
class UserModel {
  final String userId;
  final String username;
  final String email;
  final String? displayName;
  final String? avatar;
  final String? bio;
  final String role;
  final bool isLocked;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  UserModel({
    required this.userId,
    required this.username,
    required this.email,
    this.displayName,
    this.avatar,
    this.bio,
    this.role = 'user',
    this.isLocked = false,
    this.createdAt,
    this.updatedAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      userId: json['UserId']?.toString() ?? '',
      username: json['Username'] ?? '',
      email: json['Email'] ?? '',
      displayName: json['DisplayName'],
      avatar: json['Avatar'],
      bio: json['Bio'],
      role: json['Role'] ?? 'user',
      isLocked: json['IsLocked'] ?? false,
      createdAt: json['CreatedAt'] != null ? DateTime.tryParse(json['CreatedAt']) : null,
      updatedAt: json['UpdatedAt'] != null ? DateTime.tryParse(json['UpdatedAt']) : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'UserId': userId,
    'Username': username,
    'Email': email,
    'DisplayName': displayName,
    'Avatar': avatar,
    'Bio': bio,
    'Role': role,
    'IsLocked': isLocked,
  };
}
```

---

### TASK 1.6 – Tạo services/auth_service.dart

**File mới:** `lib/services/auth_service.dart`

Ánh xạ đầy đủ các endpoint `/api/v1/auth`:

| Endpoint | Method | Gọi bằng |
|----------|--------|---------|
| `/auth/register` | POST | `register(username, email, password)` |
| `/auth/login` | POST | `login(username, password)` → trả về `access_token` |
| `/auth/me` | GET | `getMe()` → trả về `UserModel` |
| `/auth/me` | PUT | `updateMe(...)` → cập nhật profile |
| `/auth/me/avatar` | POST multipart | `uploadAvatar(File)` |

**Lưu ý quan trọng:** Backend login dùng `OAuth2PasswordRequestForm` → gửi `application/x-www-form-urlencoded` với `username` và `password`, không phải JSON.

```dart
// Trong login():
final response = await DioClient.instance.post(
  '/auth/login',
  data: FormData.fromMap({'username': username, 'password': password}),
  options: Options(contentType: 'application/x-www-form-urlencoded'),
);
final token = response.data['access_token'];
await TokenStorage.saveToken(token);
```

---

### TASK 1.7 – Tạo providers/auth_provider.dart

**File mới:** `lib/providers/auth_provider.dart`

Thay thế hoàn toàn `Supabase.instance.client.auth`:

```dart
class AuthProvider with ChangeNotifier {
  UserModel? _user;
  bool _isLoading = false;
  String? _error;

  UserModel? get user => _user;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _user != null;
  String? get error => _error;

  // Gọi khi app khởi động
  Future<void> initialize() async {
    final token = await TokenStorage.getToken();
    if (token == null) return;
    try {
      _user = await AuthService.getMe();
      notifyListeners();
    } catch (_) {
      await TokenStorage.clearToken();
    }
  }

  Future<bool> login(String username, String password) async { ... }
  Future<bool> register(String username, String email, String password) async { ... }
  Future<void> logout() async {
    await TokenStorage.clearToken();
    _user = null;
    notifyListeners();
  }
  Future<void> updateProfile({String? displayName, String? bio}) async { ... }
}
```

---

### TASK 1.8 – Sửa main.dart

**File cần sửa:** `lib/main.dart`

**Trước (hiện tại):**
- Gọi `Supabase.initialize(url, anonKey)`
- Provider: `AppProvider`
- Kiểm tra `Supabase.instance.client.auth.currentSession` để quyết định màn hình đầu tiên

**Sau (mục tiêu):**
- XÓA `Supabase.initialize` (hoặc comment lại trong Phase 1)
- MultiProvider: `[AuthProvider, AppProvider, ChatProvider]`
- `AuthProvider.initialize()` trong `initState` hoặc `FutureBuilder`
- Kiểm tra `AuthProvider.isAuthenticated` để route

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => AppProvider()),
        // ChangeNotifierProvider(create: (_) => ChatProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: FutureBuilder(
        future: context.read<AuthProvider>().initialize(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SplashScreen(); // hoặc CircularProgressIndicator
          }
          return Consumer<AuthProvider>(
            builder: (_, auth, __) =>
                auth.isAuthenticated ? const MainTabScreen() : const AuthScreen(),
          );
        },
      ),
    );
  }
}
```

---

### TASK 1.9 – Refactor screens/auth/auth_screen.dart

**File cần sửa:** `lib/screens/auth/auth_screen.dart`

**Thay thế:**
- `Supabase.instance.client.auth.signInWithPassword(...)` → `context.read<AuthProvider>().login(...)`
- `Supabase.instance.client.auth.signUp(...)` → `context.read<AuthProvider>().register(...)`
- Xử lý lỗi: backend trả về `{"detail": "Incorrect username or password"}` → hiển thị `detail`

**Lưu ý:** Backend login field là `username` (không phải `email`). Auth screen nên có cả 2 tab login/register và field đầu tiên là `Username`.

---

### TASK 1.10 – Tạo models/manga_list.dart và models/reading_history.dart

**File mới:** `lib/models/manga_list.dart`

Dựa trên schema backend `ListBrief`, `ListDetailResponse`, `ListMangaItem`:

```dart
class MangaListBrief {
  final String listId;
  final String name;
  final String? description;
  final String visibility;       // 'public' | 'private'
  final int itemCount;
  final int followerCount;
  final String? coverUrl;
  final DateTime? updatedAt;
  bool? contains;                // có chứa manga đang xem không

  factory MangaListBrief.fromJson(Map<String, dynamic> json) { ... }
}

class MangaListDetail {
  final String listId;
  final String name;
  final String? description;
  final String visibility;
  final String ownerId;
  final String? ownerUsername;
  final int itemCount;
  final int followerCount;
  final List<ListMangaItem> items;
  final String? coverUrl;

  factory MangaListDetail.fromJson(Map<String, dynamic> json) { ... }
}

class ListMangaItem {
  final String mangaId;
  final String? title;
  final String? coverUrl;
  final String? status;
  final int? year;
  final String? contentRating;
  final int position;

  factory ListMangaItem.fromJson(Map<String, dynamic> json) { ... }
}
```

**File mới:** `lib/models/reading_history.dart`

Dựa trên `HistoryResponse` của backend:

```dart
class ReadingHistoryItem {
  final String historyId;
  final String mangaId;
  final String chapterId;
  final int? lastPageRead;
  final DateTime? readAt;
  final String? mangaTitle;
  final String? chapterNumber;
  final String? coverUrl;

  factory ReadingHistoryItem.fromJson(Map<String, dynamic> json) { ... }
}
```

---

### TASK 1.11 – Tạo services/list_service.dart

**File mới:** `lib/services/list_service.dart`

Ánh xạ endpoints `/api/v1/lists`:

```dart
class ListService {
  static final _dio = DioClient.instance;

  // GET /lists/?manga_id={id}  → trả {my_lists: [...], followed_lists: [...]}
  static Future<Map<String, List<MangaListBrief>>> getMyLists({String? mangaId}) async { ... }

  // POST /lists/
  static Future<Map<String, dynamic>> createList(String name, {String? description, String visibility = 'private'}) async { ... }

  // PUT /lists/{id}
  static Future<void> updateList(String listId, {String? name, String? description, String? visibility}) async { ... }

  // DELETE /lists/{id}
  static Future<void> deleteList(String listId) async { ... }

  // GET /lists/{id}  → ListDetailResponse
  static Future<MangaListDetail> getListDetail(String listId) async { ... }

  // POST /lists/{id}/items?manga_id={mangaId}
  static Future<void> addItem(String listId, String mangaId) async { ... }

  // DELETE /lists/{id}/items/{mangaId}
  static Future<void> removeItem(String listId, String mangaId) async { ... }

  // POST /lists/{id}/follow
  static Future<void> followList(String listId) async { ... }

  // DELETE /lists/{id}/follow
  static Future<void> unfollowList(String listId) async { ... }

  // GET /lists/public?page=&q=&sort=
  static Future<Map<String, dynamic>> getPublicLists({int page = 1, String? query, String sort = 'updated_desc'}) async { ... }
}
```

---

### TASK 1.12 – Tạo services/history_service.dart

**File mới:** `lib/services/history_service.dart`

Ánh xạ endpoints `/api/v1/history`:

**Lưu ý quan trọng về incompatibility:**
- Supabase history lưu: `manga_id, manga_title, manga_cover_url, chapter_id, chapter_number, page_index`
- Backend history lưu: `MangaId, ChapterId, LastPageRead` (không có manga_title, cover_url inline – backend tự join khi query)
- **Khi ghi history:** Chỉ cần gửi `manga_id (UUID), chapter_id (UUID), last_page_read (int)`
- **Backend chapter_id phải là UUID của bảng Chapter trong SQL Server** (giống MangaDex chapter ID)

```dart
class HistoryService {
  // POST /history/  body: {MangaId, ChapterId, LastPageRead}
  static Future<void> recordHistory({
    required String mangaId,
    required String chapterId,
    int lastPageRead = 0,
  }) async { ... }

  // GET /history/?page=&limit=
  static Future<Map<String, dynamic>> getHistory({int page = 1, int limit = 20}) async { ... }

  // GET /history/grouped
  static Future<List<Map<String, dynamic>>> getGroupedHistory() async { ... }

  // GET /history/manga/{manga_id}/continue  → {chapter_id, last_page}
  static Future<Map<String, dynamic>?> getContinueReading(String mangaId) async { ... }
}
```

---

### TASK 1.13 – Refactor providers/app_provider.dart

**File cần sửa toàn bộ:** `lib/providers/app_provider.dart`

**XÓA:** Tất cả code gọi `Supabase.instance.client` trực tiếp

**THAY BẰNG:** Gọi `ListService` và `HistoryService` tương ứng

| Hàm cũ (Supabase) | Hàm mới (Backend Service) |
|-------------------|--------------------------|
| `fetchLists()` | `ListService.getMyLists()` |
| `createList(name)` | `ListService.createList(name)` |
| `renameList(id, name)` | `ListService.updateList(id, name: name)` |
| `deleteList(id)` | `ListService.deleteList(id)` |
| `fetchItemsInList(id)` | `ListService.getListDetail(id)` |
| `addMangaToList(listId, manga)` | `ListService.addItem(listId, manga.id)` |
| `removeMangaFromList(itemId)` | `ListService.removeItem(listId, mangaId)` |
| `saveReadingHistory(...)` | `HistoryService.recordHistory(mangaId, chapterId, page)` |
| `fetchReadingHistory()` | `HistoryService.getGroupedHistory()` |
| `deleteHistoryItem(id)` | Hiện chưa có endpoint DELETE history cụ thể → bỏ qua hoặc thêm endpoint vào backend |
| `getLastReadChapter(mangaId)` | `HistoryService.getContinueReading(mangaId)` |
| `fetchProfile()` | `AuthService.getMe()` (dùng qua AuthProvider) |

**Lưu ý về `bulkRemoveMangaFromList` và `importMangaFromList`:** Backend chưa có endpoint tương ứng. Cần implement client-side bằng cách gọi `addItem/removeItem` nhiều lần hoặc bổ sung endpoint vào backend.

---

### TASK 1.14 – Refactor các screens dùng data cá nhân

**Các file cần sửa:**

**`screens/history/history_screen.dart`:**
- Xóa import Supabase
- Dùng `AppProvider.fetchReadingHistory()` → data dạng `List<ReadingHistoryItem>`
- Backend trả về cover_url, manga_title, chapter_number đã join
- Hiển thị grouped (Today/Yesterday/This Week/Earlier) dùng `HistoryService.getGroupedHistory()`

**`screens/library/library_screen.dart`:**
- Dùng `AppProvider.fetchLists()` → data dạng `List<MangaListBrief>`
- Field `cover_url` đã có trong ListBrief (backend tự lấy cover của manga đầu tiên trong list)
- Xóa `fetchListCover()` vì backend đã include sẵn

**`screens/library/list_detail_screen.dart`:**
- Dùng `ListService.getListDetail(listId)` → `MangaListDetail`
- Items có `manga_id`, `title`, `cover_url`, `status` đủ để hiển thị
- Khi navigate đến detail screen: dùng `manga_id` để load đầy đủ từ MangaDex/backend

**`screens/profile/profile_screen.dart`:**
- Dùng `AuthProvider.user` thay vì `Supabase.instance.client.auth.currentUser`
- Logout: `AuthProvider.logout()`
- Upload avatar: `AuthService.uploadAvatar(file)` → `/api/v1/auth/me/avatar` (multipart)

---

## PHẦN 3 – PHASE 2: NÂNG CẤP (Kết hợp MangaDex + Backend cho nội dung)

> **Mục tiêu Phase 2:** Tích hợp backend vào màn hình browse/search/detail/reader. Backend làm nguồn chính cho manga metadata; MangaDex là fallback.

### TASK 2.1 – Tạo services/manga_service.dart (Backend)

**File mới:** `lib/services/manga_service.dart`

Ánh xạ endpoints `/api/v1/mangas`:

Dựa trên frontend `src/services/manga.service.ts`:

```dart
class MangaService {
  static final _dio = DioClient.instance;

  // GET /mangas/?page=&limit=&sort=&status=&content_rating=&demographic=&year=
  static Future<Map<String, dynamic>> listMangas({
    int page = 1, int limit = 24, String? sort, String? status,
    String? contentRating, String? demographic, int? year,
  }) async { ... }

  // GET /mangas/search?q=&include_tags=&exclude_tags=&year_from=&year_to=...
  static Future<Map<String, dynamic>> searchMangas({
    String? query, List<String>? includeTags, List<String>? excludeTags,
    String? sort, String? status, String? contentRating, int? year,
    String? demographic, String? originalLang, int page = 1, int limit = 20,
  }) async { ... }

  // GET /mangas/{id}  → MangaDetail (đầy đủ hơn MangaDex)
  static Future<Map<String, dynamic>?> getMangaDetail(String mangaId) async { ... }

  // GET /mangas/{id}/related
  static Future<List<Map<String, dynamic>>> getRelatedManga(String mangaId) async { ... }

  // GET /mangas/random
  static Future<Map<String, dynamic>?> getRandomManga() async { ... }

  // GET /mangas/latest  → dùng sort=updated_desc
  static Future<Map<String, dynamic>> getLatestMangas({int page = 1, int limit = 24}) async {
    return listMangas(page: page, limit: limit, sort: 'updated_desc');
  }
}
```

**Response format `MangaListItem` từ backend:**
```json
{
  "MangaId": "uuid",
  "TitleEn": "string",
  "Status": "string",
  "Year": 2020,
  "ContentRating": "safe",
  "PublicationDemographic": "shonen",
  "cover_url": "https://...",
  "stats": {"Follows": 1000, "AverageRating": 8.5}
}
```

**Response format `MangaDetail` từ backend:**
```json
{
  "MangaId": "uuid",
  "TitleEn": "string",
  "Status": "ongoing",
  "Type": "manga",
  "OriginalLanguage": "ja",
  "LastChapter": "120",
  "cover_url": "https://...",
  "tags": [{"TagId": "uuid", "GroupName": "genre", "NameEn": "Action"}],
  "alt_titles": [{"LangCode": "vi", "AltTitle": "..."}],
  "descriptions": [{"LangCode": "en", "Description": "..."}],
  "links": [],
  "creators": [{"id": "uuid", "name": "Author Name", "role": "author"}],
  "available_languages": ["en", "vi"],
  "stats": {"Follows": 1000, "AverageRating": 8.5}
}
```

---

### TASK 2.2 – Cập nhật models/manga.dart

**File cần sửa:** `lib/models/manga.dart`

Thêm các field từ backend, đồng thời giữ tương thích với MangaDex parser hiện tại:

```dart
class Manga {
  // Hiện có
  final String id;
  final String title;
  final String coverUrl;
  final String description;
  final String author;
  final String artist;
  final String status;
  final List<String> genres;
  final List<String> themes;
  final String demographic;
  final String contentRating;
  final int? year;
  final List<String> altTitles;
  final String originalLanguage;
  final String? lastChapter;
  final String? lastVolume;

  // MỚI: từ backend
  final double? averageRating;      // stats.AverageRating
  final int? followCount;           // stats.Follows
  final List<String> availableLanguages;  // available_languages
  final String? type;               // manga / manhwa / manhua

  // Factory từ backend response
  factory Manga.fromBackendJson(Map<String, dynamic> json) {
    final stats = json['stats'] as Map<String, dynamic>?;
    return Manga(
      id: json['MangaId']?.toString() ?? '',
      title: json['TitleEn'] ?? 'Unknown',
      coverUrl: json['cover_url'] ?? 'https://via.placeholder.com/256',
      description: _extractDescription(json['descriptions']),
      author: _extractAuthor(json['creators']),
      artist: _extractArtist(json['creators']),
      status: json['Status'] ?? 'Unknown',
      genres: _extractTags(json['tags'], ['genre', 'format']),
      themes: _extractTags(json['tags'], ['theme']),
      demographic: json['PublicationDemographic'] ?? '',
      contentRating: json['ContentRating'] ?? '',
      year: json['Year'] as int?,
      originalLanguage: json['OriginalLanguage'] ?? '',
      lastChapter: json['LastChapter'],
      lastVolume: json['LastVolume'],
      averageRating: (stats?['AverageRating'] as num?)?.toDouble(),
      followCount: stats?['Follows'] as int?,
      availableLanguages: List<String>.from(json['available_languages'] ?? []),
      type: json['Type'],
    );
  }

  // Giữ nguyên factory MangaDex
  // factory Manga.fromMangaDex(Map<String, dynamic> item) { ... }
}
```

---

### TASK 2.3 – Tạo models/chapter.dart

**File mới:** `lib/models/chapter.dart`

Dựa trên `ChapterResponse` của backend:

```dart
class Chapter {
  final String chapterId;
  final String mangaId;
  final String? volume;
  final String chapterNumber;  // Có thể là "Oneshot"
  final String? title;
  final String? translatedLang;
  final int? pages;
  final DateTime? publishAt;
  final bool isUnavailable;

  factory Chapter.fromJson(Map<String, dynamic> json) {
    return Chapter(
      chapterId: json['ChapterId']?.toString() ?? '',
      mangaId: json['MangaId']?.toString() ?? '',
      volume: json['Volume'],
      chapterNumber: json['ChapterNumber'] ?? 'Oneshot',
      title: json['Title'],
      translatedLang: json['TranslatedLang'],
      pages: json['Pages'] as int?,
      publishAt: json['PublishAt'] != null ? DateTime.tryParse(json['PublishAt']) : null,
      isUnavailable: json['IsUnavailable'] ?? false,
    );
  }
}

class ChapterNav {
  final Chapter current;
  final Chapter? prevChapter;
  final Chapter? nextChapter;
  final List<String> pageUrls;

  factory ChapterNav.fromJson(Map<String, dynamic> json) {
    return ChapterNav(
      current: Chapter.fromJson(json['current']),
      prevChapter: json['prev_chapter'] != null ? Chapter.fromJson(json['prev_chapter']) : null,
      nextChapter: json['next_chapter'] != null ? Chapter.fromJson(json['next_chapter']) : null,
      pageUrls: List<String>.from(json['page_urls'] ?? []),
    );
  }
}
```

---

### TASK 2.4 – Tạo services/chapter_service.dart

**File mới:** `lib/services/chapter_service.dart`

```dart
class ChapterService {
  static final _dio = DioClient.instance;

  // GET /manga/{id}/chapters?lang=&sort=asc
  // Trả về List<Chapter>
  static Future<List<Chapter>> getChapters(
    String mangaId, {
    String? lang,
    String sort = 'asc',
  }) async { ... }

  // GET /manga/{id}/languages  → List<String>
  static Future<List<String>> getLanguages(String mangaId) async { ... }

  // GET /manga/{id}/chapters/{chapterId}
  // Trả về ChapterNav (current + prev/next + page_urls)
  // Backend tự xử lý: MinIO pages → fallback MangaDex at-home
  static Future<ChapterNav?> getChapterDetail(
    String mangaId,
    String chapterId,
  ) async { ... }

  // Fallback: dùng MangaDex trực tiếp nếu backend fail
  static Future<List<String>> getMangaDexPages(String chapterId, {bool dataSaver = false}) async {
    // Gọi MangaDexApi().getChapterPages(chapterId) hoặc getChapterPagesSaver
    ...
  }
}
```

---

### TASK 2.5 – Nâng cấp screens/explore/explore_screen.dart

**File cần sửa:** `lib/screens/explore/explore_screen.dart`

**Hiện tại:** Gọi `MangaDexApi().searchManga(...)` trực tiếp

**Mục tiêu:**
1. Gọi `MangaService.listMangas()` từ backend làm primary
2. Hiển thị cover qua `cover_url` từ backend (đã resolve MinIO → MangaDex fallback)
3. Nếu backend không available → fallback `MangaDexApi().searchManga(...)`

**Thêm filter UI:**
- Sort by: `updated_desc`, `updated_asc`, `rating_desc`, `follows_desc`, `year_desc`
- Status: `ongoing`, `completed`, `hiatus`, `cancelled`
- Content rating: `safe`, `suggestive`, `erotica`
- Demographic: `shounen`, `shoujo`, `josei`, `seinen`

---

### TASK 2.6 – Nâng cấp screens/explore/search_screen.dart

**File cần sửa:** `lib/screens/explore/search_screen.dart`

**Hiện tại:** Gọi `MangaDexApi().searchManga(query: query, ...)`

**Mục tiêu:**
1. PRIMARY: `MangaService.searchMangas(query: query, ...)` qua backend
2. Backend search params: `q, include_tags, exclude_tags, status, content_rating, year_from, year_to, original_lang, demographic`
3. Tải tags từ `TagService.getTags()` → dùng cho advanced search filter

---

### TASK 2.7 – Nâng cấp screens/detail/detail_screen.dart

**File cần sửa:** `lib/screens/detail/detail_screen.dart`

**Hiện tại:**
- Load manga detail từ `MangaDexApi().getMangaDetail(id)`
- Load chapters từ `MangaDexApi().getMangaChapters(id)`
- Add to list qua `AppProvider.addMangaToList(...)`

**Mục tiêu Phase 2:**
1. Load manga detail từ `MangaService.getMangaDetail(id)` (backend) → giàu dữ liệu hơn
2. Load chapters từ `ChapterService.getChapters(id)` (backend) với language filter
3. Giữ "Add to List" flow (đã refactor ở Phase 1)
4. Thêm "Continue Reading" button dùng `HistoryService.getContinueReading(id)`
5. Thêm tab/section cho **Ratings** và **Comments** (Phase 3)

**Bổ sung Section "Creators" từ backend:**
- `manga.creators` → hiển thị list author/artist với link đến creator detail

---

### TASK 2.8 – Nâng cấp screens/reader/reader_screen.dart

**File cần sửa:** `lib/screens/reader/reader_screen.dart`

**Hiện tại:**
- Load pages từ `MangaDexApi().getChapterPages(chapterId)` trực tiếp
- Lưu history vào Supabase

**Mục tiêu:**
1. Load pages qua `ChapterService.getChapterDetail(mangaId, chapterId)`:
   - Backend tự xử lý MinIO → MangaDex fallback
   - Response có `page_urls`, `prev_chapter`, `next_chapter` (không cần tự tính)
2. Lưu history vào backend qua `HistoryService.recordHistory(mangaId, chapterId, pageIndex)`
3. Next/Prev chapter: dùng `chapterNav.nextChapter` và `chapterNav.prevChapter`
4. Thêm nút "Rate this chapter/manga" → mở `RatingPanel`

**Logic tải ảnh:**
- `page_urls` từ backend có thể là:
  - URL MinIO presigned (valid 7 ngày)
  - URL `uploads.mangadex.org/...` (MangaDex CDN)
  - URL `*.mangadex.network/...` (at-home server)
- Dùng `CachedNetworkImage` với header `Referer: https://mangadex.org/` để tránh hotlink protection

```dart
CachedNetworkImage(
  imageUrl: pageUrl,
  httpHeaders: const {'Referer': 'https://mangadex.org/'},
  ...
)
```

---

## PHẦN 4 – PHASE 3: MỞ RỘNG (Tính năng đặc trưng Backend)

> **Mục tiêu Phase 3:** Thêm các tính năng mới hoàn toàn chỉ có trong backend: Comments, Ratings, Chat, Friends, Recommendations.

### TASK 3.1 – Comments

#### 3.1.1 – Tạo models/comment.dart

Dựa trên `CommentResponse` của backend:

```dart
class Comment {
  final String commentId;
  final String userId;
  final String mangaId;
  final String? chapterId;
  final String? username;
  final String? avatar;
  final String content;
  final bool isSpoiler;
  final int likeCount;
  final int dislikeCount;
  final bool isDeleted;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory Comment.fromJson(Map<String, dynamic> json) { ... }
}
```

#### 3.1.2 – Tạo services/comment_service.dart

Ánh xạ endpoints `/api/v1/comments`:

```dart
class CommentService {
  // GET /comments/manga/{id}/comments?page=&limit=
  static Future<Map<String, dynamic>> getComments(String mangaId, {int page = 1, int limit = 20}) async { ... }

  // POST /comments/manga/{id}/comments  body: {Content, IsSpoiler, ChapterId?}
  static Future<Comment?> postComment(String mangaId, String content, {bool isSpoiler = false}) async { ... }

  // PUT /comments/{id}  body: {Content}
  static Future<void> editComment(String commentId, String newContent) async { ... }

  // DELETE /comments/{id}
  static Future<void> deleteComment(String commentId) async { ... }

  // POST /comments/{id}/like
  static Future<Map<String, int>> likeComment(String commentId) async { ... }

  // POST /comments/{id}/dislike
  static Future<Map<String, int>> dislikeComment(String commentId) async { ... }

  // POST /comments/{id}/report  body: {Reason}
  static Future<void> reportComment(String commentId, String reason) async { ... }
}
```

#### 3.1.3 – Tạo widgets/comment_tile.dart

Widget hiển thị 1 comment:
- Avatar + username
- Content (có toggle hiển thị nếu `isSpoiler = true`)
- Like/Dislike buttons với counter
- Nút "Report" (long press hoặc more menu)
- Nút "Edit/Delete" nếu là comment của current user

#### 3.1.4 – Thêm Comments Section vào detail_screen.dart

- Đặt dưới chapter list
- Load 20 comments đầu tiên
- Paginated với "Load more"
- Text field để post comment mới (chỉ hiện khi đã login)
- Inline like/dislike interaction

---

### TASK 3.2 – Ratings

#### 3.2.1 – Tạo models/rating.dart

```dart
class Rating {
  final String? ratingId;
  final String? userId;
  final String? mangaId;
  final int? score; // 1-10

  factory Rating.fromJson(Map<String, dynamic> json) { ... }
}
```

#### 3.2.2 – Tạo services/rating_service.dart

```dart
class RatingService {
  // POST /ratings/manga/{id}/rate  body: {Score: 1-10}
  static Future<Rating?> rateManga(String mangaId, int score) async { ... }

  // GET /ratings/manga/{id}/my-rating  → {score: null | int}
  static Future<int?> getMyRating(String mangaId) async { ... }
}
```

#### 3.2.3 – Tạo widgets/rating_panel.dart

Widget star rating (1-10 scale):
- Hiển thị rating trung bình của manga (từ `manga.averageRating`)
- Cho phép user chọn rating cá nhân (1-10 stars)
- Hiển thị "Your rating: X/10" nếu đã rated
- Submit → gọi `RatingService.rateManga(...)`
- Tích hợp vào detail_screen dưới cover image

---

### TASK 3.3 – Recommendations

#### 3.3.1 – Tạo services/recommendation_service.dart

```dart
class RecommendationService {
  // GET /recommendations/for-me?top_n=20
  // Collaborative filtering – cần user đã có lịch sử đọc
  static Future<List<Manga>> getPersonalizedRecommendations({int topN = 20}) async { ... }

  // GET /recommendations/manga/{id}/similar?limit=10
  // Dùng MangaDex recommendation API proxy
  static Future<List<Map<String, dynamic>>> getSimilarManga(String mangaId, {int limit = 10}) async { ... }
}
```

#### 3.3.2 – Thêm "Similar Manga" section vào detail_screen.dart

- Horizontal scrollable list dưới description
- Load từ `RecommendationService.getSimilarManga(mangaId)`
- Response ban đầu chỉ có `manga_id` và `score` – cần enrich metadata
- Enrich bằng cách gọi `MangaService.getMangaDetail(id)` hoặc `MangaDexApi().getMangaDetail(id)` cho từng item
- Giới hạn hiển thị 6-8 items đầu

#### 3.3.3 – Thêm "For You" section vào explore_screen.dart

- Section đầu tiên trong explore page (chỉ hiện khi đã login)
- Load từ `RecommendationService.getPersonalizedRecommendations()`
- Horizontal scrollable card list
- Fallback: nếu chưa có đủ lịch sử đọc → hiển thị "Trending" từ MangaDex

---

### TASK 3.4 – Chat System

#### 3.4.1 – Tạo models/chat_room.dart

Dựa trên types của frontend `src/services/chat.service.ts`:

```dart
class ChatRoom {
  final String roomId;
  final String type; // 'direct' | 'group'
  final String? name;
  final String? avatarUrl;
  final List<ChatRoomMember> members;
  final ChatMessage? lastMessage;
  final int unreadCount;
  final DateTime? updatedAt;

  factory ChatRoom.fromJson(Map<String, dynamic> json) { ... }
}

class ChatMessage {
  final String messageId;
  final String roomId;
  final String senderId;
  final String? senderUsername;
  final String? senderAvatar;
  final String? content;
  final String messageType; // 'text' | 'image'
  final String? mediaUrl;
  final String? replyToId;
  final String status;
  final DateTime? createdAt;
  bool isOwn;  // client-side flag

  factory ChatMessage.fromJson(Map<String, dynamic> json) { ... }
}

class ChatRoomMember {
  final String userId;
  final String username;
  final String? avatar;
  final String? displayName;

  factory ChatRoomMember.fromJson(Map<String, dynamic> json) { ... }
}
```

#### 3.4.2 – Tạo services/chat_service.dart (REST)

Ánh xạ endpoints `/api/v1/chat`:

```dart
class ChatApiService {
  // GET /chat/rooms  → List<ChatRoom>
  static Future<List<ChatRoom>> getRooms() async { ... }

  // POST /chat/rooms  body: {type, user_ids, name?}
  static Future<Map<String, dynamic>> createRoom(String type, List<String> userIds, {String? name}) async { ... }

  // GET /chat/rooms/{id}/messages?page=&limit=  → {messages, page, total}
  static Future<Map<String, dynamic>> getMessages(String roomId, {int page = 1, int limit = 50}) async { ... }

  // POST /chat/rooms/{id}/messages  body: {content, reply_to_id?}
  static Future<Map<String, dynamic>> sendMessage(String roomId, String content, {String? replyToId}) async { ... }

  // POST /chat/rooms/{id}/media  multipart
  static Future<Map<String, dynamic>> uploadMedia(String roomId, String filePath) async { ... }

  // PUT /chat/messages/{id}/read
  static Future<void> markRead(String messageId) async { ... }
}
```

#### 3.4.3 – Tạo providers/chat_provider.dart (WebSocket)

WebSocket endpoint: `ws://host:8000/ws/chat/{room_id}?token={jwt}`

Protocol messages (same as backend):
- Client → Server: `{"type": "message", "content": "text"}`
- Client → Server: `{"type": "typing", "is_typing": true}`
- Client → Server: `{"type": "read", "message_id": "uuid"}`
- Server → Client: `{"type": "message", "message_id": "...", "sender_id": "...", "content": "...", ...}`
- Server → Client: `{"type": "typing", "user_id": "...", "is_typing": bool}`
- Server → Client: `{"type": "read", "user_id": "...", "message_id": "..."}`

```dart
class ChatProvider with ChangeNotifier {
  WebSocketChannel? _channel;
  String? _currentRoomId;
  List<ChatMessage> _messages = [];
  List<ChatRoom> _rooms = [];
  bool _isConnected = false;
  Map<String, bool> _typingUsers = {}; // userId → isTyping

  List<ChatMessage> get messages => _messages;
  List<ChatRoom> get rooms => _rooms;
  bool get isConnected => _isConnected;
  Map<String, bool> get typingUsers => _typingUsers;

  Future<void> loadRooms() async { ... }

  Future<void> connectToRoom(String roomId) async {
    final token = await TokenStorage.getToken();
    final wsUrl = '${AppConstants.wsBaseUrl}/chat/$roomId?token=$token';
    _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
    _currentRoomId = roomId;
    _isConnected = true;
    // Load message history via REST
    await loadMessages(roomId);
    // Listen to WS events
    _channel!.stream.listen(
      _handleWsMessage,
      onDone: _handleDisconnect,
      onError: _handleError,
    );
    notifyListeners();
  }

  void sendMessage(String content) {
    _channel?.sink.add(jsonEncode({'type': 'message', 'content': content}));
  }

  void sendTyping(bool isTyping) {
    _channel?.sink.add(jsonEncode({'type': 'typing', 'is_typing': isTyping}));
  }

  void disconnect() {
    _channel?.sink.close();
    _channel = null;
    _currentRoomId = null;
    _isConnected = false;
    _messages = [];
    notifyListeners();
  }

  void _handleWsMessage(dynamic data) {
    final msg = jsonDecode(data as String) as Map<String, dynamic>;
    switch (msg['type']) {
      case 'message':
        final newMsg = ChatMessage.fromJson(msg);
        _messages.add(newMsg);
        notifyListeners();
      case 'typing':
        _typingUsers[msg['user_id']] = msg['is_typing'] as bool;
        notifyListeners();
      case 'read':
        // update message status
        notifyListeners();
    }
  }
}
```

#### 3.4.4 – Tạo screens/chat/chat_list_screen.dart

Màn hình danh sách phòng chat:
- Hiển thị `ChatRoom` list với avatar, tên phòng, last message preview
- Badge số tin nhắn chưa đọc
- FAB để tạo phòng mới (direct chat với friend hoặc group)
- Tap → navigate đến `ChatRoomScreen`
- Search rooms

#### 3.4.5 – Tạo screens/chat/chat_room_screen.dart

Giao diện chat:
- AppBar: tên phòng + avatar + online indicator
- ListView.builder với `ChatMessage` tiles
- Input field + send button
- Typing indicator khi có user đang gõ
- Long press message: reply/delete
- Phân biệt message của mình (align right, màu khác) vs người khác (align left)
- Load more khi scroll lên đầu (pagination)

---

### TASK 3.5 – Friends System

#### 3.5.1 – Tạo models/friend.dart

```dart
class FriendInfo {
  final String userId;
  final String username;
  final String? avatar;
  final String? displayName;
  final bool isOnline;
  final DateTime? lastSeen;
  final String? requestedAt; // cho pending requests

  factory FriendInfo.fromJson(Map<String, dynamic> json) { ... }
}
```

#### 3.5.2 – Tạo services/friend_service.dart

Ánh xạ endpoints `/api/v1/friends`:

```dart
class FriendService {
  // GET /friends/  → {friends: [FriendInfo]}
  static Future<List<FriendInfo>> getFriends() async { ... }

  // GET /friends/requests  → {requests: [FriendInfo]}
  static Future<List<FriendInfo>> getRequests() async { ... }

  // POST /friends/request/{user_id}
  static Future<void> sendRequest(String userId) async { ... }

  // POST /friends/accept/{user_id}
  static Future<void> acceptRequest(String userId) async { ... }

  // POST /friends/reject/{user_id}
  static Future<void> rejectRequest(String userId) async { ... }

  // POST /friends/block/{user_id}
  static Future<void> blockUser(String userId) async { ... }

  // GET /friends/search?q={query}  → {users: [FriendInfo]}
  static Future<List<FriendInfo>> searchUsers(String query) async { ... }
}
```

#### 3.5.3 – Tạo screens/friends/friends_screen.dart

Màn hình friends:
- Tab 1: Danh sách friends (với online indicator)
  - Tap friend → mở direct chat hoặc xem profile
- Tab 2: Pending requests (nhận được)
  - Accept/Reject buttons
- Search bar → search users → send friend request
- Nút "Message" bên cạnh mỗi friend → tạo/mở direct chat room

---

### TASK 3.6 – Nâng cấp Navigation (main_tab_screen.dart)

**File cần sửa:** `lib/screens/main_tab_screen.dart`

**Hiện tại (4 tabs):** Explore | Library | History | Profile

**Mục tiêu (5 tabs):**
```
[Explore] [Library] [Chat] [Friends] [Profile]
```

Hoặc nếu muốn giữ 4 tabs, gộp Chat+Friends vào Social tab:
```
[Explore] [Library] [Social] [Profile]
```

**Badge:** Tab Chat hiển thị badge số unread messages từ `ChatProvider.rooms`

---

### TASK 3.7 – Nâng cấp screens/profile/profile_screen.dart

**Thêm vào profile:**
1. **Friends list preview** – 5 friends gần đây với link đến Friends screen
2. **Stats cá nhân:**
   - Số manga đã đọc (từ history)
   - Số list đã tạo
   - Số comment đã đăng
3. **Recent ratings** – manga gần đây đã đánh giá
4. **Avatar upload** – `AuthService.uploadAvatar(file)` → backend lưu vào MinIO

---

## PHẦN 5 – PHASE 4: MỞ RỘNG NÂNG CAO

> **Mục tiêu Phase 4:** Tính năng nâng cao, polish UX, và các chức năng chưa có trong cả web frontend.

### TASK 4.1 – Creator Detail Screen

**File mới:** `lib/screens/creator/creator_screen.dart`

- Load từ `GET /api/v1/creators/{id}` → creator info + manga list
- Hiển thị biography (en/ja)
- Grid manga của creator
- Link từ detail screen (tap author/artist name)

### TASK 4.2 – Tag Service và Tag Filter

**File mới:** `lib/services/tag_service.dart`

```dart
class TagService {
  static List<Map<String, dynamic>>? _cache;

  // GET /tags/  → [{group_name, tags: [{TagId, GroupName, NameEn}]}]
  static Future<List<Map<String, dynamic>>> getTags() async { ... }
}
```

Dùng trong Advanced Search screen để render tag chips.

### TASK 4.3 – Public Lists Discovery

**Thêm vào library_screen.dart hoặc tạo tab mới:**
- `GET /lists/public?page=&q=&sort=` → danh sách lists công khai
- Có thể follow lists của người khác
- Sort by: followers, items, recently updated

### TASK 4.4 – Offline Reading History Cache

Dùng `sqflite` để cache lịch sử đọc locally:
- Khi đọc chương mới → ghi vào SQLite + gọi backend API
- Khi offline → hiển thị từ SQLite
- Sync khi online lại

### TASK 4.5 – Analytics (Personal Stats)

```dart
class AnalyticsService {
  // GET /analytics/...
  // Hiển thị: tổng số manga, chapters đọc, tags yêu thích
}
```

### TASK 4.6 – Settings Screen

Screen mới cho các cài đặt:
- Image quality: `data` (HD) vs `data-saver` (compressed) – ảnh hưởng đến `ChapterService`
- Preferred language: `en`, `vi`, `ja` – ảnh hưởng đến chapter list filter
- Theme: dark/light
- Notification preferences

---

## PHẦN 6 – CHI TIẾT KỸ THUẬT & LƯU Ý QUAN TRỌNG

### 6.1 Xử lý UUID

Backend dùng `UNIQUEIDENTIFIER` (MS SQL Server UUID format). Khi gửi từ Flutter:
- Manga ID, Chapter ID: dùng trực tiếp string UUID từ MangaDex (chúng giống nhau)
- Luôn gửi UUID dưới dạng lowercase string: `"3a1f5e2b-0000-0000-0000-000000000000"`

### 6.2 Cover Images

Backend `cover_url` có thể là:
- `https://uploads.mangadex.org/covers/{manga_id}/{fileName}` → thêm `.256.jpg` cho thumbnail
- `https://localhost:9000/manga-media/covers/...` → presigned MinIO URL (có expiry)
- `null` → dùng placeholder

Trong `CachedNetworkImage`, cần set `httpHeaders: {'Referer': 'https://mangadex.org/'}` cho MangaDex CDN URLs.

### 6.3 Chapter Pages Loading

Backend endpoint `/api/v1/proxy/chapter-pages/{chapter_id}` trả về:
```json
{"pages": ["url1", "url2", ...], "hash": "...", "quality": "data-saver"}
```

Dùng `quality=data` cho WiFi, `quality=data-saver` cho mobile data. Detect via `Connectivity` package.

Nếu backend không available → fallback về `MangaDexApi().getChapterPages(chapterId)`.

### 6.4 Auth Token Lifecycle

- Token type: `Bearer JWT` (không phải Supabase JWT)
- Không có refresh token – token expire = `ACCESS_TOKEN_EXPIRE_MINUTES=10080` (7 ngày)
- Khi 401 response → clear token + navigate đến login
- Token saved trong `SharedPreferences` (key: `backend_jwt_token`)

### 6.5 Error Handling Pattern

Tất cả service calls cần wrap trong try/catch:
```dart
try {
  final response = await DioClient.instance.get('/endpoint');
  return response.data;
} on DioException catch (e) {
  if (e.response?.statusCode == 401) {
    throw UnauthorizedException();
  }
  if (e.response?.statusCode == 404) {
    return null;
  }
  final detail = e.response?.data?['detail'] ?? e.message;
  throw ApiException(detail ?? 'Unknown error');
} catch (e) {
  throw ApiException('Network error: $e');
}
```

### 6.6 Backend List vs Supabase List – Mapping

| Supabase list_items field | Backend ListManga field | Ghi chú |
|--------------------------|------------------------|---------|
| `manga_id` | `MangaId` (UUID) | Giống nhau |
| `title` | Lấy từ `Manga.TitleEn` khi join | Backend không store inline |
| `cover_url` | Resolve từ Cover table | Backend tự resolve |
| `status` | Không có (backend không track reading status per-list-item) | **Thiếu!** Cần thêm field hoặc bỏ |
| `genres` | Không có inline | Backend link qua MangaTag |

**Giải pháp thiếu `status`:** Có thể tạo bảng mới trong backend hoặc lưu locally trong SharedPreferences mapping `{listId}_{mangaId}` → status.

### 6.7 WebSocket trong Flutter

Dùng package `web_socket_channel`:
```dart
import 'package:web_socket_channel/web_socket_channel.dart';

final channel = WebSocketChannel.connect(
  Uri.parse('ws://10.0.2.2:8000/ws/chat/$roomId?token=$token'),
);

// Listen
channel.stream.listen((data) {
  final msg = jsonDecode(data);
  // handle message
});

// Send
channel.sink.add(jsonEncode({'type': 'message', 'content': 'Hello'}));

// Close
channel.sink.close();
```

### 6.8 CORS Backend – Cần sửa cho Mobile

**File backend cần sửa:** `main.py`

Hiện tại CORS chỉ allow `localhost:3000`. Cần thêm cho mobile:
```python
allow_origins=[
    "http://localhost:3000",
    "http://127.0.0.1:3000",
    "*",  # Cho development mobile
    # Production: thêm domain cụ thể
],
```

Hoặc tốt hơn là set `allow_origins=["*"]` trong development.

### 6.9 Image Proxy Backend

Khi cần proxy ảnh MangaDex từ Flutter qua backend:
```
GET /api/v1/proxy/image?url={encoded_mangadex_url}
```

Backend sẽ fetch ảnh từ MangaDex với đúng headers (Referer, User-Agent) và stream về Flutter. Dùng khi CDN URL bị block trực tiếp.

---

## PHẦN 7 – THỨ TỰ THỰC HIỆN (EXECUTION ORDER)

```
PHASE 1 – MIGRATION (Ưu tiên cao nhất)
├── TASK 1.1  pubspec.yaml – thêm dependencies
├── TASK 1.2  core/constants.dart
├── TASK 1.3  core/token_storage.dart
├── TASK 1.4  core/dio_client.dart
├── TASK 1.5  models/user.dart
├── TASK 1.6  services/auth_service.dart
├── TASK 1.7  providers/auth_provider.dart
├── TASK 1.8  main.dart – refactor
├── TASK 1.9  auth_screen.dart – refactor
├── TASK 1.10 models/manga_list.dart + models/reading_history.dart
├── TASK 1.11 services/list_service.dart
├── TASK 1.12 services/history_service.dart
├── TASK 1.13 providers/app_provider.dart – refactor
└── TASK 1.14 screens dùng data cá nhân – refactor

PHASE 2 – UPGRADE (Kết hợp nội dung)
├── TASK 2.1  services/manga_service.dart
├── TASK 2.2  models/manga.dart – cập nhật
├── TASK 2.3  models/chapter.dart
├── TASK 2.4  services/chapter_service.dart
├── TASK 2.5  explore_screen.dart – nâng cấp
├── TASK 2.6  search_screen.dart – nâng cấp
├── TASK 2.7  detail_screen.dart – nâng cấp
└── TASK 2.8  reader_screen.dart – nâng cấp

PHASE 3 – EXPAND (Tính năng mới)
├── TASK 3.1  Comments (model + service + widget + UI)
├── TASK 3.2  Ratings (model + service + widget + UI)
├── TASK 3.3  Recommendations (service + UI sections)
├── TASK 3.4  Chat (model + service + provider + screens)
├── TASK 3.5  Friends (model + service + screen)
├── TASK 3.6  Navigation update (main_tab_screen)
└── TASK 3.7  Profile upgrades

PHASE 4 – ADVANCED (Tùy chọn)
├── TASK 4.1  Creator Detail Screen
├── TASK 4.2  Tag Service + Advanced Filter
├── TASK 4.3  Public Lists Discovery
├── TASK 4.4  Offline Cache
├── TASK 4.5  Analytics
└── TASK 4.6  Settings Screen
```

---

## PHẦN 8 – BACKEND ENDPOINT REFERENCE (Quick Lookup)

> Danh sách đầy đủ các endpoint backend để AI agent tra cứu nhanh.

### Auth
```
POST   /api/v1/auth/register          body: {username, email, password}
POST   /api/v1/auth/login             form: username, password → {access_token, token_type}
GET    /api/v1/auth/me                → UserResponse
PUT    /api/v1/auth/me                body: {username?, email?, bio?, display_name?, new_password?, current_password?}
POST   /api/v1/auth/me/avatar         multipart: file → {success, avatar_url}
```

### Manga
```
GET    /api/v1/mangas/                ?page, limit, sort, status, content_rating, demographic, year
GET    /api/v1/mangas/search          ?q, include_tags, exclude_tags, status, content_rating, year_from, year_to, original_lang, demographic, page, limit
GET    /api/v1/mangas/{id}            → MangaDetail
GET    /api/v1/mangas/{id}/related    → [RelatedManga]
GET    /api/v1/mangas/random          → MangaDetail
GET    /api/v1/mangas/latest          → paginated list
```

### Chapters
```
GET    /api/v1/manga/{id}/chapters    ?lang, sort
GET    /api/v1/manga/{id}/languages   → [string]
GET    /api/v1/manga/{id}/chapters/{cid}  → ChapterNav{current, prev, next, page_urls}
```

### Comments
```
GET    /api/v1/comments/manga/{id}/comments   ?page, limit
POST   /api/v1/comments/manga/{id}/comments   body: {Content, IsSpoiler, ChapterId?}
PUT    /api/v1/comments/{id}                  body: {Content}
DELETE /api/v1/comments/{id}
POST   /api/v1/comments/{id}/like
POST   /api/v1/comments/{id}/dislike
POST   /api/v1/comments/{id}/report          body: {Reason}
```

### Ratings
```
POST   /api/v1/ratings/manga/{id}/rate         body: {Score: 1-10}
GET    /api/v1/ratings/manga/{id}/my-rating    → {score: null|int}
```

### History
```
POST   /api/v1/history/                body: {MangaId, ChapterId, LastPageRead}
GET    /api/v1/history/                ?page, limit
GET    /api/v1/history/grouped         ?limit
GET    /api/v1/history/manga/{id}/continue  → {chapter_id, last_page}
```

### Lists
```
GET    /api/v1/lists/                  ?manga_id
POST   /api/v1/lists/                  body: {Name, Description?, Visibility}
GET    /api/v1/lists/public            ?page, limit, sort, q
GET    /api/v1/lists/{id}
PUT    /api/v1/lists/{id}              body: {Name?, Description?, Visibility?}
DELETE /api/v1/lists/{id}
POST   /api/v1/lists/{id}/items        ?manga_id={uuid}
DELETE /api/v1/lists/{id}/items/{manga_id}
POST   /api/v1/lists/{id}/follow
DELETE /api/v1/lists/{id}/follow
```

### Chat
```
GET    /api/v1/chat/rooms
POST   /api/v1/chat/rooms              body: {type, user_ids, name?}
GET    /api/v1/chat/rooms/{id}/messages  ?page, limit
POST   /api/v1/chat/rooms/{id}/messages  body: {content, reply_to_id?}
POST   /api/v1/chat/rooms/{id}/media   multipart: file
PUT    /api/v1/chat/messages/{id}/read
WS     /ws/chat/{room_id}?token={jwt}
```

### Friends
```
GET    /api/v1/friends/
GET    /api/v1/friends/requests
POST   /api/v1/friends/request/{user_id}
POST   /api/v1/friends/accept/{user_id}
POST   /api/v1/friends/reject/{user_id}
POST   /api/v1/friends/block/{user_id}
GET    /api/v1/friends/search          ?q={query}
```

### Others
```
GET    /api/v1/covers/manga/{id}       → primary cover
GET    /api/v1/covers/manga/{id}/all   → all covers
GET    /api/v1/tags/                   → grouped tags
GET    /api/v1/creators/{id}           → creator + manga list
GET    /api/v1/recommendations/for-me  ?top_n
GET    /api/v1/recommendations/manga/{id}/similar  ?limit
GET    /api/v1/proxy/chapter-pages/{chapter_id}  ?quality=data|data-saver
GET    /api/v1/proxy/image             ?url={encoded_url}
GET    /api/v1/analytics/...
```

---

## PHẦN 9 – COMPATIBILITY MATRIX

| Feature | Flutter (hiện tại) | Flutter (mục tiêu) | Backend Endpoint |
|---------|-------------------|-------------------|-----------------|
| Login/Register | Supabase Auth | Backend JWT | `/auth/login`, `/auth/register` |
| Browse Manga | MangaDex API | Backend API + MangaDex fallback | `/mangas/` |
| Search Manga | MangaDex API | Backend API + MangaDex fallback | `/mangas/search` |
| Manga Detail | MangaDex API | Backend API (richer data) | `/mangas/{id}` |
| Chapter List | MangaDex API | Backend API | `/manga/{id}/chapters` |
| Read Chapter | MangaDex API | Backend proxy → MangaDex fallback | `/manga/{id}/chapters/{cid}` |
| My Lists | Supabase `custom_lists` | Backend API | `/lists/` |
| List Items | Supabase `list_items` | Backend API | `/lists/{id}/items` |
| Reading History | Supabase `reading_history` | Backend API | `/history/` |
| Profile | Supabase `profiles` | Backend API | `/auth/me` |
| Comments | ❌ Không có | ✅ Mới | `/comments/manga/{id}/comments` |
| Ratings | ❌ Không có | ✅ Mới | `/ratings/manga/{id}/rate` |
| Chat | ❌ Không có | ✅ Mới | `/chat/` + WebSocket |
| Friends | ❌ Không có | ✅ Mới | `/friends/` |
| Recommendations | ❌ Không có | ✅ Mới | `/recommendations/` |
| Public Lists | ❌ Không có | ✅ Mới | `/lists/public` |
| Creator Detail | ❌ Không có | ✅ Mới | `/creators/{id}` |
| Avatar Upload | Supabase Storage | MinIO via Backend | `/auth/me/avatar` |
| Tags/Filter | MangaDex tags API | Backend tags API | `/tags/` |

---

## PHẦN 10 – KIỂM TRA & TEST CHECKLIST

### Phase 1 – Completion Criteria
- [ ] App khởi động không crash
- [ ] Login với username/password backend thành công
- [ ] Register tài khoản mới thành công
- [ ] JWT token được lưu và tự động đính vào requests
- [ ] Logout xóa token và redirect đến login
- [ ] Library screen hiển thị lists từ backend
- [ ] Add/Remove manga trong list hoạt động
- [ ] History screen hiển thị lịch sử từ backend
- [ ] Profile screen hiển thị user info từ backend

### Phase 2 – Completion Criteria
- [ ] Explore screen hiển thị manga từ backend
- [ ] Search hoạt động với backend
- [ ] Manga detail hiển thị đầy đủ thông tin từ backend
- [ ] Chapter list hiển thị từ backend
- [ ] Đọc truyện hoạt động (page_urls load được)
- [ ] History được ghi vào backend khi đọc
- [ ] Continue Reading hoạt động

### Phase 3 – Completion Criteria
- [ ] Hiển thị comments trong detail screen
- [ ] Post comment thành công
- [ ] Like/dislike comment hoạt động
- [ ] Rate manga 1-10 và hiển thị rating
- [ ] Similar manga section hiển thị
- [ ] Chat list hiển thị rooms
- [ ] Gửi/nhận tin nhắn real-time qua WebSocket
- [ ] Friends list hiển thị
- [ ] Send/accept friend requests
- [ ] Navigate đến chat từ friends list

---

*Tài liệu này được tạo để AI agent đọc và thực thi. Mỗi TASK có đủ context, file path, và chi tiết kỹ thuật để implement độc lập. Thực hiện theo đúng thứ tự Phase để tránh dependency issues.*
