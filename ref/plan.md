Đã đọc đủ cả 3 file. Bây giờ tôi có bức tranh toàn cảnh. Để bắt đầu tạo code:Tôi đã có đủ thông tin để bắt đầu. Đây là kế hoạch triển khai:
- **7 file mới** + **2 file cập nhật**
- Fallback ảnh 3 tầng: Backend MinIO → MangaDex CDN → Placeholder
- Admin panel đầy đủ
- Stats screen với biểu đồ tự vẽ (không cần thêm package)
- Edit account hoàn chỉnhĐây là tất cả **10 file** được tạo/cập nhật. Dưới đây là tóm tắt những gì đã làm và cách tích hợp:

---

## 📦 Tổng kết

### Vấn đề 1 – Fallback ảnh 3 tầng

**`MangaCoverImage`** (widget mới):
- Tầng 1: URL từ backend (MinIO presigned → MangaDex CDN – backend đã xử lý sẵn)
- Tầng 2: Nếu load lỗi → tự ghép `uploads.mangadex.org/covers/{mangaId}/{fileName}.256.jpg`
- Tầng 3: Nếu MangaDex chặn IP → placeholder icon 📖 (không crash app)

**`ChapterPageImage`** (widget mới dùng trong reader):
- Tầng 1: URL từ backend (MinIO/MangaDex at-home)
- Tầng 2: Nếu lỗi → gọi `GET /proxy/image?url=...` (backend server-side proxy, tránh bị chặn phía client)
- Tầng 3: Placeholder "Không tải được trang X"

### Vấn đề 2 – Tính năng còn thiếu

| Tính năng | File |
|---|---|
| Đổi username/email/mật khẩu | `edit_account_screen.dart` |
| Biểu đồ đọc truyện cá nhân | `stats_screen.dart` (bar chart + distribution list, dùng CustomPainter, không cần thêm package) |
| Thống kê gọi backend | `user_stats_service.dart` → `GET /analytics/user-stats` |

### Vấn đề 3 – Admin panel

`admin_screen.dart` có 2 tab:
- **Tab Người dùng**: danh sách phân trang + tìm kiếm + nút khoá/mở khoá
- **Tab Báo cáo**: bình luận bị report, lọc theo status, nút Xoá/Bỏ qua

Nút Admin **tự hiện** trên ProfileScreen khi `user.role == 'admin'`, không cần config thêm.

### Bước tích hợp quan trọng nhất

1. **Replace** `CachedNetworkImage` cover bằng `MangaCoverImage` trong toàn app
2. **Replace** page image trong `reader_screen.dart` bằng `ChapterPageImage`
3. **Replace** `auth_provider.dart` bằng file mới (thêm params username/email/password)
4. Đọc `INTEGRATION_GUIDE.md` để biết chi tiết từng bước