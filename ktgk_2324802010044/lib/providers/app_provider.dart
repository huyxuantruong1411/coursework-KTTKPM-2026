// lib/providers/app_provider.dart
import 'package:flutter/foundation.dart';
import '../models/manga.dart';
import '../models/manga_list.dart';
import '../models/reading_history.dart';
import '../services/history_service.dart';
import '../services/list_service.dart';

class AppProvider with ChangeNotifier {
  // ─── Custom lists ───────────────────────────────────────────────────
  List<Map<String, dynamic>> _customLists = [];
  List<Map<String, dynamic>> get customLists => _customLists;

  // ─── State reset (on logout) ─────────────────────────────────────────

  void clearState() {
    _customLists = [];
    notifyListeners();
  }

  // ─── READING HISTORY ─────────────────────────────────────────────────

  void saveReadingHistory({
    required String mangaId,
    required String mangaTitle,
    String? mangaCoverUrl,
    required String chapterId,
    required String chapterNumber,
    String? chapterTitle,
    int pageIndex = 0,
  }) {
    HistoryService.recordHistory(
      mangaId: mangaId,
      chapterId: chapterId,
      lastPageRead: pageIndex,
    );
  }

  Future<List<Map<String, dynamic>>> fetchReadingHistory({
    int limit = 100,
  }) async {
    final groups = await HistoryService.getGroupedHistory(limit: limit);
    final result = <Map<String, dynamic>>[];
    for (final group in groups) {
      final items = group['items'];
      if (items == null) continue;
      final itemList = items is List ? items : <dynamic>[];
      for (final raw in itemList) {
        if (raw == null) continue;
        final ReadingHistoryItem item;
        if (raw is ReadingHistoryItem) {
          item = raw;
        } else if (raw is Map<String, dynamic>) {
          item = ReadingHistoryItem.fromJson(raw);
        } else {
          continue;
        }
        result.add({
          'id': item.historyId,
          'manga_id': item.mangaId,
          'chapter_id': item.chapterId,
          'manga_title': item.mangaTitle ?? '',
          'manga_cover_url': item.coverUrl ?? '',
          'chapter_number': item.chapterNumber ?? '',
          'chapter_title': null,
          'read_at': item.readAt?.toIso8601String() ?? '',
          'last_page_read': item.lastPageRead,
        });
      }
    }
    return result;
  }

  Future<void> clearReadingHistory() async {
    debugPrint('AppProvider.clearReadingHistory: not supported by backend');
  }

  Future<void> deleteHistoryItem(String id) async {
    debugPrint('AppProvider.deleteHistoryItem($id): not supported by backend');
  }

  Future<Map<String, dynamic>?> getLastReadChapter(String mangaId) async {
    return HistoryService.getContinueReading(mangaId);
  }

  // ─── MANGA LISTS ─────────────────────────────────────────────────────

  Future<void> fetchLists({String? mangaId}) async {
    final result = await ListService.getMyLists(mangaId: mangaId);
    final myLists = result['my_lists'] ?? <MangaListBrief>[];
    _customLists = myLists.map<Map<String, dynamic>>(_briefToMap).toList();
    notifyListeners();
  }

  Future<void> createList(
    String name, {
    String? description,
    String visibility = 'private',
  }) async {
    await ListService.createList(
      name,
      description: description,
      visibility: visibility,
    );
    await fetchLists();
  }

  Future<void> deleteList(String listId) async {
    await ListService.deleteList(listId);
    _customLists.removeWhere((l) => l['id'].toString() == listId);
    notifyListeners();
  }

  Future<void> addMangaToList(String listId, Manga manga) async {
    await ListService.addItem(listId, manga.id);
    await fetchLists();
  }

  Future<void> removeMangaFromListByMangaId(
    String listId,
    String mangaId,
  ) async {
    await ListService.removeItem(listId, mangaId);
    await fetchLists();
  }

  Future<void> removeMangaFromList(String itemId) async {
    debugPrint(
      'AppProvider.removeMangaFromList: itemId=$itemId. '
      'Use removeMangaFromListByMangaId when listId is available.',
    );
  }

  Future<void> bulkRemoveMangaFromList(List<String> itemIds) async {
    debugPrint('AppProvider.bulkRemoveMangaFromList: ${itemIds.length} items.');
  }

  Future<void> updateMangaStatus(String itemId, String status) async {
    debugPrint('AppProvider.updateMangaStatus: itemId=$itemId status=$status');
  }

  /// Lấy danh sách items trong 1 list
  Future<List<Map<String, dynamic>>> fetchItemsInList(String listId) async {
    try {
      final detail = await ListService.getListDetail(listId);
      return detail.items
          .map<Map<String, dynamic>>(
            (item) => {
              'id': item.mangaId,
              'manga_id': item.mangaId,
              'title': item.title ?? '',
              // FIX: was 'cover' → must be 'cover_url' to match
              // what list_detail_screen.dart reads via item['cover_url']
              'cover_url': item.coverUrl ?? '',
              'status': item.status ?? '',
              'genres': <String>[],
              'created_at': null,
            },
          )
          .toList();
    } catch (e) {
      debugPrint('AppProvider.fetchItemsInList error: $e');
      return [];
    }
  }

  Future<String?> fetchListCover(String listId) async {
    try {
      final detail = await ListService.getListDetail(listId);
      if (detail.coverUrl != null && detail.coverUrl!.isNotEmpty) {
        return detail.coverUrl;
      }
      if (detail.items.isNotEmpty) {
        return detail.items.first.coverUrl;
      }
      return null;
    } catch (e) {
      debugPrint('AppProvider.fetchListCover($listId) error: $e');
      return null;
    }
  }

  Future<(int, int)> importMangaFromList(
    String sourceListId,
    String destListId,
  ) async {
    try {
      final source = await ListService.getListDetail(sourceListId);
      final dest = await ListService.getListDetail(destListId);
      final existingIds = dest.items.map((i) => i.mangaId).toSet();
      int imported = 0;
      int skipped = 0;
      for (final item in source.items) {
        if (existingIds.contains(item.mangaId)) {
          skipped++;
        } else {
          try {
            await ListService.addItem(destListId, item.mangaId);
            imported++;
          } catch (_) {
            skipped++;
          }
        }
      }
      if (imported > 0) await fetchLists();
      return (imported, skipped);
    } catch (e) {
      debugPrint('AppProvider.importMangaFromList error: $e');
      return (0, 0);
    }
  }

  Future<Set<String>> getListsContainingManga(String mangaId) async {
    final result = await ListService.getMyLists(mangaId: mangaId);
    final allLists = [
      ...(result['my_lists'] ?? <MangaListBrief>[]),
      ...(result['followed_lists'] ?? <MangaListBrief>[]),
    ];
    return allLists
        .where((l) => l.containsManga == true)
        .map((l) => l.listId)
        .toSet();
  }

  // ─── Helpers ──────────────────────────────────────────────────────────

  Map<String, dynamic> _briefToMap(MangaListBrief l) => {
    'id': l.listId,
    'name': l.name,
    'description': l.description,
    'visibility': l.visibility,
    'item_count': l.itemCount,
    'cover_url': l.coverUrl,
  };
}
