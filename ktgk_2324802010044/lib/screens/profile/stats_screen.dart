// lib/screens/profile/stats_screen.dart
//
// Màn hình thống kê đọc truyện cá nhân – gọi GET /analytics/user-stats
// Vẽ biểu đồ bằng CustomPainter (không cần thêm package).

import 'dart:math';
import 'package:flutter/material.dart';
import '../../services/user_stats_service.dart';

const _kOrange = Color(0xFFFF6740);
const _kBg = Color(0xFF121212);
const _kCard = Color(0xFF1E1E1E);
const _kCard2 = Color(0xFF2A2A2A);

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  Map<String, dynamic>? _stats;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final data = await UserStatsService.getUserStats();
      if (!mounted) return;
      if (data == null) {
        setState(() { _error = 'Không thể tải dữ liệu thống kê.'; _isLoading = false; });
      } else {
        setState(() { _stats = data; _isLoading = false; });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kCard,
        title: const Text('Thống kê đọc truyện', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(icon: const Icon(Icons.refresh, color: Colors.white70), onPressed: _load),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _kOrange))
          : _error != null ? _buildError() : _buildContent(),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: Colors.white54), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _load,
              style: ElevatedButton.styleFrom(backgroundColor: _kOrange),
              child: const Text('Thử lại', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    final s = _stats!;
    final totalManga = s['total_manga'] ?? 0;
    final totalChapters = s['total_chapters'] ?? 0;
    final totalPages = s['total_pages'] ?? 0;
    final totalRatings = s['total_ratings'] ?? 0;
    final avgRating = s['avg_rating'];
    final dailyActivity = (s['daily_activity'] as List? ?? []).cast<Map<String, dynamic>>();
    final genreDistribution = (s['genre_distribution'] as List? ?? []).cast<Map<String, dynamic>>();
    final themeDistribution = (s['theme_distribution'] as List? ?? []).cast<Map<String, dynamic>>();
    final recentManga = (s['recent_manga'] as List? ?? []).cast<Map<String, dynamic>>();

    return RefreshIndicator(
      onRefresh: _load,
      color: _kOrange,
      backgroundColor: _kCard2,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _sectionTitle('Tổng quan'),
          const SizedBox(height: 10),
          GridView.count(
            crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 2.0,
            children: [
              _kpiCard('Manga đã đọc', totalManga.toString(), Icons.menu_book_rounded, _kOrange),
              _kpiCard('Chapter đã đọc', totalChapters.toString(), Icons.bookmark_rounded, const Color(0xFF4CAF50)),
              _kpiCard('Trang đã đọc', _formatNum(totalPages), Icons.article_outlined, const Color(0xFF2196F3)),
              _kpiCard('Đánh giá đã cho', totalRatings.toString(), Icons.star_rounded, const Color(0xFFFFC107)),
            ],
          ),
          if (avgRating != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: _kCard2, borderRadius: BorderRadius.circular(12)),
              child: Row(children: [
                const Icon(Icons.star, color: Color(0xFFFFC107), size: 22),
                const SizedBox(width: 10),
                const Text('Điểm đánh giá trung bình', style: TextStyle(color: Colors.white70, fontSize: 14)),
                const Spacer(),
                Text(avgRating.toString(), style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                const Text(' / 10', style: TextStyle(color: Colors.white38, fontSize: 14)),
              ]),
            ),
          ],
          if (dailyActivity.isNotEmpty) ...[
            const SizedBox(height: 24),
            _sectionTitle('Hoạt động 30 ngày qua'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
              decoration: BoxDecoration(color: _kCard2, borderRadius: BorderRadius.circular(12)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SizedBox(height: 120, child: _ActivityBarChart(data: dailyActivity)),
                const SizedBox(height: 8),
                Text(
                  'Tổng: ${dailyActivity.fold<int>(0, (s, e) => s + (e['count'] as int? ?? 0))} sessions',
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                ),
              ]),
            ),
          ],
          if (genreDistribution.isNotEmpty) ...[
            const SizedBox(height: 24),
            _sectionTitle('Thể loại yêu thích (Top 10)'),
            const SizedBox(height: 12),
            _DistributionList(items: genreDistribution, color: _kOrange),
          ],
          if (themeDistribution.isNotEmpty) ...[
            const SizedBox(height: 24),
            _sectionTitle('Chủ đề yêu thích (Top 10)'),
            const SizedBox(height: 12),
            _DistributionList(items: themeDistribution, color: const Color(0xFF2196F3)),
          ],
          if (recentManga.isNotEmpty) ...[
            const SizedBox(height: 24),
            _sectionTitle('Đọc gần đây'),
            const SizedBox(height: 10),
            ...recentManga.map((m) => _recentMangaTile(m)),
          ],
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) => Text(text, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold));

  Widget _kpiCard(String label, String value, IconData icon, Color iconColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(color: _kCard2, borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        const SizedBox(width: 10),
        Expanded(child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11), overflow: TextOverflow.ellipsis),
          ],
        )),
      ]),
    );
  }

  Widget _recentMangaTile(Map<String, dynamic> m) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(color: _kCard2, borderRadius: BorderRadius.circular(10)),
      child: Row(children: [
        const Icon(Icons.menu_book_outlined, color: Colors.white38, size: 18),
        const SizedBox(width: 10),
        Expanded(child: Text(m['title'] ?? m['manga_id'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 14), overflow: TextOverflow.ellipsis)),
      ]),
    );
  }

  String _formatNum(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }
}

// ── ACTIVITY BAR CHART ─────────────────────────────────────────────────────

class _ActivityBarChart extends StatelessWidget {
  final List<Map<String, dynamic>> data;
  const _ActivityBarChart({required this.data});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: const Size(double.infinity, 120), painter: _BarChartPainter(data: data));
  }
}

class _BarChartPainter extends CustomPainter {
  final List<Map<String, dynamic>> data;
  _BarChartPainter({required this.data});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;
    final maxCount = data.map((e) => e['count'] as int? ?? 0).reduce(max).toDouble();
    if (maxCount == 0) return;

    final barPaint = Paint()..color = const Color(0xFFFF6740)..style = PaintingStyle.fill;
    final basePaint = Paint()..color = Colors.white12..strokeWidth = 1..style = PaintingStyle.stroke;

    final n = data.length;
    final totalWidth = size.width;
    final barWidth = (totalWidth / n * 0.6).clamp(2.0, 14.0);
    final gap = totalWidth / n;
    const chartPadTop = 8.0;
    const chartPadBottom = 20.0;
    final chartH = size.height - chartPadTop - chartPadBottom;

    canvas.drawLine(Offset(0, size.height - chartPadBottom), Offset(size.width, size.height - chartPadBottom), basePaint);

    for (var i = 0; i < n; i++) {
      final count = (data[i]['count'] as int? ?? 0).toDouble();
      final barH = (count / maxCount * chartH).clamp(2.0, chartH);
      final x = gap * i + gap / 2 - barWidth / 2;
      final y = size.height - chartPadBottom - barH;
      final rect = RRect.fromRectAndCorners(Rect.fromLTWH(x, y, barWidth, barH), topLeft: const Radius.circular(3), topRight: const Radius.circular(3));
      canvas.drawRRect(rect, barPaint);
    }

    if (n >= 2) {
      final tp = TextPainter(textDirection: TextDirection.ltr, textAlign: TextAlign.center);
      const labelStyle = TextStyle(color: Color(0xFF888888), fontSize: 9);

      String shortDate(String d) {
        final parts = d.split('-');
        if (parts.length >= 3) return '${parts[1]}/${parts[2]}';
        return d;
      }

      tp.text = TextSpan(text: shortDate(data.first['date']?.toString() ?? ''), style: labelStyle);
      tp.layout();
      tp.paint(canvas, Offset(0, size.height - chartPadBottom + 4));

      tp.text = TextSpan(text: shortDate(data.last['date']?.toString() ?? ''), style: labelStyle);
      tp.layout();
      tp.paint(canvas, Offset(size.width - tp.width, size.height - chartPadBottom + 4));
    }
  }

  @override
  bool shouldRepaint(_BarChartPainter old) => old.data != data;
}

// ── DISTRIBUTION LIST ──────────────────────────────────────────────────────

class _DistributionList extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  final Color color;
  const _DistributionList({required this.items, required this.color});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final maxCount = items.map((e) => e['count'] as int? ?? 0).reduce(max).toDouble();

    return Container(
      decoration: BoxDecoration(color: _kCard2, borderRadius: BorderRadius.circular(12)),
      child: Column(children: List.generate(items.length, (i) {
        final item = items[i];
        final name = item['name']?.toString() ?? '';
        final count = (item['count'] as int? ?? 0).toDouble();
        final ratio = maxCount > 0 ? count / maxCount : 0.0;

        return Padding(
          padding: EdgeInsets.fromLTRB(14, i == 0 ? 12 : 6, 14, i == items.length - 1 ? 12 : 6),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(name, style: const TextStyle(color: Colors.white, fontSize: 13), overflow: TextOverflow.ellipsis)),
              Text(count.toInt().toString(), style: const TextStyle(color: Colors.white54, fontSize: 12)),
            ]),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(value: ratio, backgroundColor: Colors.white12, valueColor: AlwaysStoppedAnimation<Color>(color), minHeight: 5),
            ),
          ]),
        );
      })),
    );
  }
}
