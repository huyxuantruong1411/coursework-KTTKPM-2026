// lib/widgets/chapter_page_image.dart
//
// Widget hiển thị 1 trang truyện với 3 tầng fallback:
//   Tầng 1: URL từ backend (MinIO / MangaDex at-home – backend đã xử lý)
//   Tầng 2: Nếu load lỗi → thử qua backend proxy /proxy/image?url={encoded_url}
//             (backend server-side proxy tránh bị MangaDex chặn IP client)
//   Tầng 3: Nếu vẫn lỗi → placeholder "Không tải được trang"
//
// Cách dùng:
//   ChapterPageImage(imageUrl: url, pageIndex: i)

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../core/constants.dart';

class ChapterPageImage extends StatefulWidget {
  final String imageUrl;
  final int pageIndex;
  final BoxFit fit;
  final double? width;

  const ChapterPageImage({
    super.key,
    required this.imageUrl,
    required this.pageIndex,
    this.fit = BoxFit.fitWidth,
    this.width,
  });

  @override
  State<ChapterPageImage> createState() => _ChapterPageImageState();
}

class _ChapterPageImageState extends State<ChapterPageImage> {
  int _level = 0;
  String? _proxyUrl;
  bool _useProxy = false;

  @override
  void initState() {
    super.initState();
    _proxyUrl = _buildProxyUrl(widget.imageUrl);
  }

  @override
  void didUpdateWidget(ChapterPageImage old) {
    super.didUpdateWidget(old);
    if (old.imageUrl != widget.imageUrl) {
      setState(() {
        _level = 0;
        _useProxy = false;
        _proxyUrl = _buildProxyUrl(widget.imageUrl);
      });
    }
  }

  static String _buildProxyUrl(String originalUrl) {
    final encoded = Uri.encodeComponent(originalUrl);
    return '${AppConstants.backendBaseUrl}/proxy/image?url=$encoded';
  }

  void _onError() {
    if (!mounted) return;
    if (_level == 0 && _proxyUrl != null) {
      // Level 0 failed → try backend proxy
      setState(() {
        _level = 1;
        _useProxy = true;
      });
    } else {
      // Level 1 (proxy) also failed → show placeholder
      setState(() => _level = 2);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_level == 2) {
      return _buildPlaceholder();
    }

    final url = _useProxy ? _proxyUrl! : widget.imageUrl;

    return CachedNetworkImage(
      key: ValueKey('$url-$_level'),
      imageUrl: url,
      width: widget.width ?? double.infinity,
      fit: widget.fit,
      httpHeaders: _useProxy
          ? null
          : {
              // Some MangaDex CDN nodes require Referer
              'Referer': 'https://mangadex.org/',
              'User-Agent':
                  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
            },
      placeholder: (context, url) => _buildLoading(),
      errorWidget: (context, url, error) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _onError());
        return _buildLoading();
      },
    );
  }

  Widget _buildLoading() {
    return Container(
      width: double.infinity,
      height: 300,
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Color(0xFFFF6740),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Trang ${widget.pageIndex + 1}',
              style:
                  const TextStyle(color: Colors.white38, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      width: double.infinity,
      height: 300,
      color: const Color(0xFF1A1A1A),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.broken_image_outlined,
                color: Colors.white24, size: 48),
            const SizedBox(height: 8),
            Text(
              'Không tải được trang ${widget.pageIndex + 1}',
              style:
                  const TextStyle(color: Colors.white38, fontSize: 12),
            ),
            const SizedBox(height: 4),
            const Text(
              'Kiểm tra kết nối mạng',
              style: TextStyle(color: Colors.white24, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}
