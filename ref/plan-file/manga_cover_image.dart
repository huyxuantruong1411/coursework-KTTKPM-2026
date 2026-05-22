// lib/widgets/manga_cover_image.dart
//
// Widget hiển thị ảnh bìa manga với 3 tầng fallback:
//   Tầng 1: URL từ backend (MinIO presigned / MangaDex CDN – backend đã xử lý)
//   Tầng 2: Nếu lỗi load → thử trực tiếp MangaDex CDN bằng mangaId + fileName
//   Tầng 3: Nếu vẫn lỗi (MangaDex chặn IP) → ảnh placeholder mặc định
//
// Cách dùng:
//   MangaCoverImage(
//     coverUrl: manga.coverUrl,        // URL từ backend (có thể null)
//     mangaId: manga.id,               // UUID của manga (để fallback MangaDex)
//     fileName: manga.coverFileName,   // fileName trong DB Covers (có thể null)
//     width: 120, height: 170,
//   )

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

const _kMangaDexCdn = 'https://uploads.mangadex.org/covers';

class MangaCoverImage extends StatefulWidget {
  final String? coverUrl;
  final String? mangaId;
  final String? fileName;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final Widget? loadingWidget;

  const MangaCoverImage({
    super.key,
    this.coverUrl,
    this.mangaId,
    this.fileName,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.loadingWidget,
  });

  @override
  State<MangaCoverImage> createState() => _MangaCoverImageState();
}

class _MangaCoverImageState extends State<MangaCoverImage> {
  int _fallbackLevel = 0; // 0 = backend url, 1 = mangadex cdn, 2 = placeholder

  String? _currentUrl;

  @override
  void initState() {
    super.initState();
    _currentUrl = _urlForLevel(0);
  }

  @override
  void didUpdateWidget(MangaCoverImage old) {
    super.didUpdateWidget(old);
    if (old.coverUrl != widget.coverUrl || old.mangaId != widget.mangaId) {
      setState(() {
        _fallbackLevel = 0;
        _currentUrl = _urlForLevel(0);
      });
    }
  }

  String? _urlForLevel(int level) {
    switch (level) {
      case 0:
        final url = widget.coverUrl;
        if (url != null && url.isNotEmpty) return url;
        return _urlForLevel(1); // skip directly to level 1

      case 1:
        final mid = widget.mangaId;
        final fn = widget.fileName;
        if (mid != null && mid.isNotEmpty && fn != null && fn.isNotEmpty) {
          return '$_kMangaDexCdn/$mid/$fn.256.jpg';
        }
        return null; // no fileName → go to placeholder

      default:
        return null; // placeholder rendered separately
    }
  }

  void _onError() {
    if (!mounted) return;
    final next = _fallbackLevel + 1;
    final nextUrl = _urlForLevel(next);
    setState(() {
      _fallbackLevel = next;
      _currentUrl = nextUrl;
    });
  }

  @override
  Widget build(BuildContext context) {
    final url = _currentUrl;
    final placeholder = _buildPlaceholder();

    Widget image;
    if (url == null || url.isEmpty) {
      image = placeholder;
    } else {
      image = CachedNetworkImage(
        imageUrl: url,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        placeholder: (_, __) =>
            widget.loadingWidget ??
            Container(
              color: const Color(0xFF2C2C2C),
              child: const Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFFFF6740),
                  ),
                ),
              ),
            ),
        errorWidget: (_, __, ___) {
          // Schedule fallback after build
          WidgetsBinding.instance.addPostFrameCallback((_) => _onError());
          return placeholder;
        },
      );
    }

    if (widget.borderRadius != null) {
      return ClipRRect(
        borderRadius: widget.borderRadius!,
        child: SizedBox(
          width: widget.width,
          height: widget.height,
          child: image,
        ),
      );
    }
    return SizedBox(width: widget.width, height: widget.height, child: image);
  }

  Widget _buildPlaceholder() {
    return Container(
      width: widget.width,
      height: widget.height,
      color: const Color(0xFF2A2A2A),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.menu_book_rounded,
            color: Colors.white24,
            size: (widget.width ?? 80) * 0.35,
          ),
          const SizedBox(height: 4),
          Text(
            'No Cover',
            style: TextStyle(
              color: Colors.white24,
              fontSize: ((widget.width ?? 80) * 0.09).clamp(8.0, 12.0),
            ),
          ),
        ],
      ),
    );
  }
}
