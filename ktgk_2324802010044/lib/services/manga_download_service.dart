// lib/services/manga_download_service.dart
import 'package:archive/archive.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'chapter_service.dart';

// Conditional import: native uses file system + Share, web uses Blob download
import 'download_helper_native.dart'
    if (dart.library.html) 'download_helper_web.dart';

// ─────────────────────────────────────────────────────────────
// ENUMS
// ─────────────────────────────────────────────────────────────

enum DownloadLanguage { english, vietnamese, all }

enum DownloadFormat { folderPerChapter, chapterPdf, fullMangaPdf }

enum DownloadQuality { standard, dataSaver }

// ─────────────────────────────────────────────────────────────
// OPTIONS
// ─────────────────────────────────────────────────────────────

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

// ─────────────────────────────────────────────────────────────
// SERVICE
// ─────────────────────────────────────────────────────────────

class MangaDownloadService {
  static final _dio = Dio();

  /// Download manga chapters and trigger a save/share dialog.
  ///
  /// [onProgress] receives (0.0–1.0 progress, status message).
  /// Returns the saved zip file path on native platforms, or '' on web
  /// (web triggers the browser's Save-As dialog via [triggerDownload]).
  static Future<String> downloadManga(
    MangaDownloadOptions options, {
    void Function(double progress, String status)? onProgress,
  }) async {
    final chapters = options.selectedChapters;
    final safeTitle = options.mangaTitle.replaceAll(
      RegExp(r'[\\/:*?"<>|]'),
      '_',
    );

    final archive = Archive();
    int totalPages = 0;
    int downloadedPages = 0;

    // Estimate total pages
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
        chIdx / (chapters.isNotEmpty ? chapters.length : 1),
        'Đang tải $displayName...',
      );

      List<String> pageUrls;
      try {
        pageUrls = await ChapterService.getChapterPages(
          chapterId,
          dataSaver: options.quality == DownloadQuality.dataSaver,
        );
      } catch (e) {
        debugPrint('MangaDownloadService: cannot get pages for $chapterId: $e');
        downloadedPages += 10;
        continue;
      }

      for (int pageIdx = 0; pageIdx < pageUrls.length; pageIdx++) {
        final pageUrl = pageUrls[pageIdx];
        try {
          final resp = await _dio.get<List<int>>(
            pageUrl,
            options: Options(responseType: ResponseType.bytes),
          );
          final bytes = Uint8List.fromList(resp.data ?? []);
          final ext = pageUrl.split('.').last.split('?').first;
          final pageName =
              'page_${(pageIdx + 1).toString().padLeft(3, '0')}.$ext';

          switch (options.format) {
            case DownloadFormat.folderPerChapter:
            case DownloadFormat.chapterPdf:
              archive.addFile(
                ArchiveFile('$displayName/$pageName', bytes.length, bytes),
              );
              break;
            case DownloadFormat.fullMangaPdf:
              archive.addFile(
                ArchiveFile(
                  'all_pages/${displayName}_$pageName',
                  bytes.length,
                  bytes,
                ),
              );
              break;
          }
        } catch (e) {
          debugPrint('MangaDownloadService: failed page ${pageIdx + 1}: $e');
        }

        downloadedPages++;
        onProgress?.call(
          downloadedPages / (totalPages > 0 ? totalPages : 1),
          'Trang ${pageIdx + 1}/${pageUrls.length} – $displayName',
        );
      }
    }

    onProgress?.call(1.0, 'Hoàn thành!');

    final zipBytes = ZipEncoder().encode(archive);
    if (zipBytes == null || zipBytes.isEmpty) return '';

    final filename = '$safeTitle.zip';
    await triggerDownload(zipBytes, filename);

    // On web  → browser Save-As dialog (no local path).
    // On native → file saved + share sheet opened inside triggerDownload.
    return '';
  }
}
