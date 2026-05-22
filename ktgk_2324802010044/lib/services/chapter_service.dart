import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../core/dio_client.dart';

class ChapterService {
  static final _dio = DioClient.instance;

  /// GET /manga/{manga_id}/chapters?lang=&sort=
  static Future<List<Map<String, dynamic>>> getChapters(
    String mangaId, {
    String? lang,
    String sort = 'asc',
  }) async {
    try {
      final params = <String, dynamic>{'sort': sort};
      if (lang != null) params['lang'] = lang;

      final response = await _dio.get(
        '/manga/$mangaId/chapters',
        queryParameters: params,
      );
      final data = response.data;
      if (data is List) return data.cast<Map<String, dynamic>>();
      if (data is Map && data['chapters'] is List) {
        return (data['chapters'] as List).cast<Map<String, dynamic>>();
      }
      return [];
    } on DioException catch (e) {
      debugPrint('ChapterService.getChapters error: ${e.response?.data}');
      return [];
    }
  }

  /// GET /manga/{manga_id}/chapters/{chapter_id}
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

  /// GET /proxy/chapter-pages/{chapter_id}?quality=data|data-saver
  static Future<List<String>> getChapterPages(
    String chapterId, {
    bool dataSaver = true,
  }) async {
    try {
      final quality = dataSaver ? 'data-saver' : 'data';
      final response = await _dio.get(
        '/proxy/chapter-pages/$chapterId',
        queryParameters: {'quality': quality},
      );
      final data = response.data;
      if (data is List) return data.cast<String>();
      if (data is Map && data['pages'] is List) {
        return (data['pages'] as List).cast<String>();
      }
      return [];
    } on DioException catch (e) {
      debugPrint('ChapterService.getChapterPages error: ${e.response?.data}');
      return _fetchMangaDexPages(chapterId, dataSaver: dataSaver);
    }
  }

  static Future<List<String>> _fetchMangaDexPages(
    String chapterId, {
    bool dataSaver = true,
  }) async {
    try {
      final response = await DioClient.mangadex.get(
        '/at-home/server/$chapterId',
      );
      final data = response.data as Map<String, dynamic>;
      final baseUrl = data['baseUrl']?.toString() ?? '';
      final chapter = data['chapter'] as Map<String, dynamic>? ?? {};
      final hash = chapter['hash']?.toString() ?? '';
      final qualityKey = dataSaver ? 'dataSaver' : 'data';
      final prefix = dataSaver ? 'data-saver' : 'data';
      final pages = chapter[qualityKey] as List? ?? [];
      if (baseUrl.isEmpty || hash.isEmpty) return [];
      return pages.map((page) => '$baseUrl/$prefix/$hash/$page').toList();
    } catch (e) {
      debugPrint('ChapterService MangaDex fallback error: $e');
      return [];
    }
  }

  /// POST /translate/page
  ///
  /// Sends [imageUrl] to the backend OCR+translation pipeline.
  /// Returns the presigned URL of the translated image, or null on failure.
  ///
  /// [targetLang]  BCP-47 / ISO 639-1 code (e.g. "vi", "en", "zh-CN")
  /// [sourceLang]  "auto" for auto-detect (default), or explicit code
  ///
  /// Note: first call per image can take 10–20 s (OCR + translation).
  /// Subsequent calls for the same image+language are cached in MinIO and
  /// return almost immediately.
  static Future<String?> translatePage(
    String imageUrl, {
    String targetLang = 'vi',
    String sourceLang = 'auto',
  }) async {
    try {
      final response = await _dio.post(
        '/translate/page',
        data: {
          'image_url': imageUrl,
          'target_lang': targetLang,
          'source_lang': sourceLang,
        },
        // MangaTranslator AI pipeline: first call per page can take 30-120s
        // (model loading + YOLO detection + LLM OCR/translation + Skia rendering)
        // Subsequent calls for the same image+language are cached and return quickly.
        options: Options(receiveTimeout: const Duration(seconds: 180)),
      );
      final data = response.data;
      if (data is Map && data['translated_url'] is String) {
        return data['translated_url'] as String;
      }
      return null;
    } on DioException catch (e) {
      debugPrint('ChapterService.translatePage error: ${e.response?.data}');
      return null;
    } catch (e) {
      debugPrint('ChapterService.translatePage unexpected error: $e');
      return null;
    }
  }
}

/// Supported output languages for the translation feature.
const kTranslateLangs = <Map<String, String>>[
  {'code': 'vi', 'label': 'Tiếng Việt'},
  {'code': 'en', 'label': 'English'},
  {'code': 'zh-CN', 'label': '中文 (简体)'},
  {'code': 'zh-TW', 'label': '中文 (繁體)'},
  {'code': 'ko', 'label': '한국어'},
  {'code': 'ja', 'label': '日本語'},
  {'code': 'fr', 'label': 'Français'},
  {'code': 'de', 'label': 'Deutsch'},
  {'code': 'es', 'label': 'Español'},
  {'code': 'pt', 'label': 'Português'},
  {'code': 'th', 'label': 'ภาษาไทย'},
  {'code': 'id', 'label': 'Bahasa Indonesia'},
];
