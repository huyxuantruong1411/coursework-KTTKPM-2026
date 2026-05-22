import 'package:flutter/material.dart';
import '../../widgets/manga_cover_image.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../../models/manga.dart';
import '../detail/detail_screen.dart';

const _kOrange = Color(0xFFFF6740);
const _kBg = Color(0xFF121212);
const _kCard = Color(0xFF2C2C2C);

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});
  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<Map<String, dynamic>> _history = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    final data = await context.read<AppProvider>().fetchReadingHistory(
      limit: 100,
    );
    if (mounted) {
      setState(() {
        _history = data;
        _isLoading = false;
      });
    }
  }

  /// Group history by date label (Hôm nay, Hôm qua, dd/MM/yyyy)
  Map<String, List<Map<String, dynamic>>> get _grouped {
    final map = <String, List<Map<String, dynamic>>>{};
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    for (final item in _history) {
      final readAt = DateTime.tryParse(item['read_at'] ?? '') ?? now;
      final readDate = DateTime(readAt.year, readAt.month, readAt.day);
      String label;
      final diff = today.difference(readDate).inDays;
      if (diff == 0) {
        label = 'Hôm nay';
      } else if (diff == 1) {
        label = 'Hôm qua';
      } else if (diff < 7) {
        label = '$diff ngày trước';
      } else {
        label =
            '${readAt.day.toString().padLeft(2, '0')}/${readAt.month.toString().padLeft(2, '0')}/${readAt.year}';
      }
      (map[label] ??= []).add(item);
    }
    return map;
  }

  Future<void> _clearAll() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _kCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Xóa lịch sử', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Bạn có chắc muốn xóa toàn bộ lịch sử đọc?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Xóa tất cả'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    if (!mounted) return;
    await context.read<AppProvider>().clearReadingHistory();
    await _loadHistory();
  }

  @override
  Widget build(BuildContext context) {
    final grouped = _grouped;
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kBg,
        title: const Text(
          'Lịch sử đọc',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          if (_history.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep, color: Colors.white54),
              onPressed: _clearAll,
              tooltip: 'Xóa tất cả',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _kOrange))
          : _history.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.history,
                    size: 64,
                    color: Colors.white.withValues(alpha: 0.15),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Chưa có lịch sử đọc',
                    style: TextStyle(color: Colors.white38, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Bắt đầu đọc manga để xem lịch sử ở đây!',
                    style: TextStyle(color: Colors.white24, fontSize: 13),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadHistory,
              color: _kOrange,
              child: ListView.builder(
                padding: const EdgeInsets.only(bottom: 24),
                itemCount: grouped.length,
                itemBuilder: (ctx, sectionIndex) {
                  final label = grouped.keys.elementAt(sectionIndex);
                  final items = grouped[label]!;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    // FIX: assign unique keys to each child to avoid duplicate key error
                    children: [
                      // Section header
                      Padding(
                        key: ValueKey('header_$label'),
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: Text(
                          label,
                          style: const TextStyle(
                            color: _kOrange,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      ...items.mapIndexed(
                        (index, item) => _buildHistoryTile(
                          item,
                          key: ValueKey(
                            'tile_${item['id'] ?? '${label}_$index'}',
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
    );
  }

  Widget _buildHistoryTile(Map<String, dynamic> item, {Key? key}) {
    final readAt = DateTime.tryParse(item['read_at'] ?? '');
    final timeStr = readAt != null
        ? '${readAt.hour.toString().padLeft(2, '0')}:${readAt.minute.toString().padLeft(2, '0')}'
        : '';

    final coverUrl = item['manga_cover_url'] as String? ?? '';

    return Dismissible(
      key: key ?? Key(item['id'].toString()),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.redAccent,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (direction) async {
        await context.read<AppProvider>().deleteHistoryItem(
          item['id'].toString(),
        );
        setState(() => _history.removeWhere((h) => h['id'] == item['id']));
      },
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: MangaCoverImage(
                  coverUrl: coverUrl,
                  mangaId: item['manga_id']?.toString(),
                  width: 42,
                  height: 60,
                  fit: BoxFit.cover,
                  borderRadius: BorderRadius.circular(4),
                ),
        ),
        title: Text(
          item['manga_title'] ?? '',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          'Ch. ${item['chapter_number']}'
          '${item['chapter_title'] != null && item['chapter_title'].toString().isNotEmpty ? " — ${item['chapter_title']}" : ""}',
          style: const TextStyle(color: Colors.white54, fontSize: 12),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Text(
          timeStr,
          style: const TextStyle(color: Colors.white24, fontSize: 11),
        ),
        onTap: () {
          final manga = Manga(
            id: item['manga_id'] ?? '',
            title: item['manga_title'] ?? '',
            coverUrl: coverUrl,
          );
          Navigator.push(
            context,
            MaterialPageRoute(builder: (ctx) => DetailScreen(manga: manga)),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Helper extension – mapIndexed (nếu chưa có trong project)
// Nếu project đã có iterable_extensions hoặc collection package thì xóa phần này
// ---------------------------------------------------------------------------
extension _IterableMapIndexed<T> on Iterable<T> {
  Iterable<R> mapIndexed<R>(R Function(int index, T item) f) sync* {
    var i = 0;
    for (final item in this) {
      yield f(i++, item);
    }
  }
}
