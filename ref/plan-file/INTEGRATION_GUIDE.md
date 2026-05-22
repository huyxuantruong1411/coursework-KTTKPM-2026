# 📋 Hướng dẫn tích hợp các tính năng mới

## Tổng quan các file được tạo/cập nhật

```
lib/
├── widgets/
│   ├── manga_cover_image.dart      [MỚI] Widget ảnh bìa – 3 tầng fallback
│   └── chapter_page_image.dart     [MỚI] Widget trang đọc – proxy fallback
│
├── services/
│   ├── user_stats_service.dart     [MỚI] Gọi /analytics/user-stats
│   └── admin_service.dart          [MỚI] Gọi /admin/* endpoints
│
├── screens/
│   ├── profile/
│   │   ├── profile_screen.dart     [CẬP NHẬT] Thêm nút stats/edit/admin
│   │   ├── edit_account_screen.dart [MỚI] Đổi username/email/password
│   │   └── stats_screen.dart       [MỚI] Biểu đồ thống kê đọc truyện
│   └── admin/
│       └── admin_screen.dart       [MỚI] Bảng quản trị (user + báo cáo)
│
└── providers/
    └── auth_provider.dart          [CẬP NHẬT] Thêm username/email/password params
```

---

## 1. MangaCoverImage – Cách thay thế ảnh bìa hiện tại

Thay bất kỳ `CachedNetworkImage` nào đang hiển thị cover bằng:

```dart
import '../../widgets/manga_cover_image.dart';

// Thay thế này:
CachedNetworkImage(imageUrl: manga.coverUrl ?? '', ...)

// Bằng cái này:
MangaCoverImage(
  coverUrl: manga.coverUrl,     // URL từ backend (MinIO / MangaDex CDN)
  mangaId: manga.id,            // UUID bộ manga (để fallback MangaDex CDN)
  fileName: manga.coverFileName, // fileName trong DB nếu có
  width: 120,
  height: 170,
  borderRadius: BorderRadius.circular(8),
)
```

**Luồng fallback:**
1. Thử `coverUrl` từ backend (MinIO presigned → MangaDex CDN – backend đã xử lý)
2. Nếu load lỗi → tự ghép URL MangaDex CDN: `uploads.mangadex.org/covers/{mangaId}/{fileName}.256.jpg`
3. Nếu vẫn lỗi (bị chặn IP) → hiện placeholder icon 📖

---

## 2. ChapterPageImage – Thay thế trong ReaderScreen

Mở `lib/screens/reader/reader_screen.dart`, tìm chỗ render trang ảnh và thay:

```dart
import '../../widgets/chapter_page_image.dart';

// Thay:
CachedNetworkImage(imageUrl: _resolveUrl(index), ...)

// Bằng:
ChapterPageImage(
  imageUrl: _resolveUrl(index),
  pageIndex: index,
)
```

**Luồng fallback:**
1. Load URL gốc từ backend (MinIO / MangaDex at-home)
2. Nếu lỗi → gọi backend proxy: `GET /proxy/image?url={encoded_url}` (server-side proxy tránh chặn IP)
3. Nếu proxy cũng lỗi → hiện placeholder "Không tải được trang"

---

## 3. Thêm fileName vào Manga model

Nếu backend trả về `cover_url` và `cover_file_name` trong response manga, thêm vào model:

```dart
// lib/models/manga.dart – thêm field:
final String? coverFileName;

// factory fromJson – thêm:
coverFileName: json['cover_file_name'] as String?,
```

Nếu backend chưa trả về `cover_file_name`, bạn có thể gọi thêm `/covers/manga/{id}` để lấy `fileName` rồi cache lại. Hoặc bỏ qua – widget vẫn hoạt động (chỉ fallback về placeholder).

---

## 4. Tích hợp AdminScreen vào Navigation

`AdminScreen` đã được nhúng vào `ProfileScreen` (hiện tự động khi `user.role == 'admin'`). Không cần thêm route riêng.

---

## 5. Cập nhật auth_provider.dart

File `auth_provider.dart` mới đã thêm đủ params cho `updateProfile()`. **Replace toàn bộ** file cũ bằng file mới.

---

## 6. Kiểm tra backend proxy hoạt động

Test thủ công:
```
GET http://localhost:8000/api/v1/proxy/image?url=https://uploads.mangadex.org/covers/.../...jpg
GET http://localhost:8000/api/v1/proxy/chapter-pages/{chapter_uuid}?quality=data-saver
```

Nếu backend server của bạn đang chạy và có thể reach MangaDex, các URL MangaDex sẽ được proxy thành công.

---

## 7. Placeholder ảnh mặc định (tuỳ chọn)

Nếu muốn dùng ảnh thật thay vì icon placeholder, thêm file vào `assets/images/no_cover.jpg` và sửa `_buildPlaceholder()` trong `manga_cover_image.dart`:

```dart
Widget _buildPlaceholder() {
  return Image.asset(
    'assets/images/no_cover.jpg',
    width: widget.width,
    height: widget.height,
    fit: widget.fit,
  );
}
```

Đừng quên khai báo trong `pubspec.yaml`:
```yaml
flutter:
  assets:
    - assets/images/
```

---

## 8. Tóm tắt API endpoints đã được tận dụng

| Endpoint | Service/Screen |
|----------|---------------|
| `GET /analytics/user-stats` | `UserStatsService` → `StatsScreen` |
| `PUT /auth/me` (username/email/password) | `AuthService.updateMe` → `EditAccountScreen` |
| `GET /admin/users` | `AdminService` → `AdminScreen` Tab 1 |
| `POST /admin/users/{id}/ban` | `AdminService` → `AdminScreen` Tab 1 |
| `POST /admin/users/{id}/unban` | `AdminService` → `AdminScreen` Tab 1 |
| `GET /admin/comments` | `AdminService` → `AdminScreen` Tab 2 |
| `POST /admin/comments/{id}/delete` | `AdminService` → `AdminScreen` Tab 2 |
| `POST /admin/comments/{id}/ignore` | `AdminService` → `AdminScreen` Tab 2 |
| `GET /proxy/image?url=` | `ChapterPageImage` fallback tầng 2 |
| `GET /covers/manga/{id}` | Backend đã có, `MangaCoverImage` dùng qua coverUrl |
