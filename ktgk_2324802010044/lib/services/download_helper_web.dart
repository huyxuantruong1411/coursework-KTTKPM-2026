// lib/services/download_helper_web.dart
//
// Sử dụng package:web + dart:js_interop thay cho dart:html (deprecated).
// Thêm vào pubspec.yaml nếu chưa có:
//   dependencies:
//     web: ^0.5.1
//
import 'dart:async';
import 'dart:typed_data';
import 'package:web/web.dart' as web;
import 'dart:js_interop';

/// Kích hoạt browser "Save As" dialog (Web only).
///
/// Hai fix quan trọng so với phiên bản cũ:
/// 1. [revokeObjectUrl] bị delay 120s — nếu revoke ngay sau click() thì
///    browser không đọc được blob → download đứng 0 B/s.
/// 2. Bytes được convert sang [Uint8List] trước khi tạo Blob —
///    [List`<`int`>`] trong JS dùng 8 bytes/phần tử (JS number), còn
///    [Uint8List] → JS Uint8Array chỉ 1 byte/phần tử, tránh OOM trên
///    file lớn.
Future<void> triggerDownload(List<int> bytes, String filename) async {
  // Chuyển sang Uint8Array để tiết kiệm bộ nhớ
  final data = bytes is Uint8List ? bytes : Uint8List.fromList(bytes);

  final jsArray = data.toJS;
  final blobParts = [jsArray].toJS;
  final options = web.BlobPropertyBag(type: 'application/octet-stream');
  final blob = web.Blob(blobParts, options);

  final url = web.URL.createObjectURL(blob);

  final anchor = web.document.createElement('a') as web.HTMLAnchorElement
    ..href = url
    ..setAttribute('download', filename)
    ..style.display = 'none';

  web.document.body!.append(anchor);
  anchor.click();
  anchor.remove();

  // Thu hồi URL sau 120 giây — đủ thời gian browser đọc hết file lớn.
  Timer(const Duration(seconds: 120), () {
    web.URL.revokeObjectURL(url);
  });
}
