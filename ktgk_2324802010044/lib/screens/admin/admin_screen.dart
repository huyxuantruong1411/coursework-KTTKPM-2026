// lib/screens/admin/admin_screen.dart
//
// ═══════════════════════════════════════════════════════════════════
//  Giao diện quản trị viên – phiên bản đầy đủ
//
//  Tab 1 – Tổng quan  : KPI cards, biểu đồ người dùng & lượt đọc,
//                        top manga đang đọc nhiều nhất
//  Tab 2 – Người dùng : list / card layout, xem chi tiết từng user
//  Tab 3 – Manga       : grid / list layout, tìm kiếm, phân trang
//  Tab 4 – Báo cáo     : quản lý bình luận bị báo cáo
//
//  AppBar              : nút Đăng xuất (xác nhận trước khi thoát)
// ═══════════════════════════════════════════════════════════════════

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/admin_service.dart';
import '../../services/manga_service.dart';
import '../../widgets/manga_cover_image.dart';

// ─── Màu sắc ────────────────────────────────────────────────────────
const _kOrange = Color(0xFFFF6740);
const _kBg = Color(0xFF121212);
const _kCard = Color(0xFF1E1E1E);
const _kCard2 = Color(0xFF2A2A2A);
const _kCard3 = Color(0xFF333333);
const _kGreen = Color(0xFF4CAF50);
const _kBlue = Color(0xFF2196F3);

// ─── Layout Enums ────────────────────────────────────────────────────
enum _UserLayout { list, card }

enum _MangaLayout { grid, list }

// ═══════════════════════════════════════════════════════════════════
//  ROOT WIDGET
// ═══════════════════════════════════════════════════════════════════

class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: _kBg,
        appBar: AppBar(
          backgroundColor: _kCard,
          elevation: 0,
          title: const Row(
            children: [
              Icon(
                Icons.admin_panel_settings_rounded,
                color: _kOrange,
                size: 22,
              ),
              SizedBox(width: 8),
              Text(
                'Quản trị hệ thống',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                ),
              ),
            ],
          ),
          iconTheme: const IconThemeData(color: Colors.white),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout_rounded, color: Colors.white70),
              tooltip: 'Đăng xuất',
              onPressed: () => _confirmLogout(context),
            ),
            const SizedBox(width: 4),
          ],
          bottom: const TabBar(
            indicatorColor: _kOrange,
            labelColor: _kOrange,
            unselectedLabelColor: Colors.white38,
            labelStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
            unselectedLabelStyle: TextStyle(fontSize: 11),
            tabs: [
              Tab(
                icon: Icon(Icons.dashboard_rounded, size: 18),
                text: 'Tổng quan',
              ),
              Tab(
                icon: Icon(Icons.people_alt_outlined, size: 18),
                text: 'Người dùng',
              ),
              Tab(icon: Icon(Icons.menu_book_rounded, size: 18), text: 'Manga'),
              Tab(icon: Icon(Icons.flag_outlined, size: 18), text: 'Báo cáo'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [_DashboardTab(), _UsersTab(), _MangaTab(), _CommentsTab()],
        ),
      ),
    );
  }

  void _confirmLogout(BuildContext context) {
    showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _kCard2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Đăng xuất?',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Bạn sẽ được chuyển về màn hình đăng nhập.',
          style: TextStyle(color: Colors.white60),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Huỷ', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _kOrange,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    ).then((ok) {
      if (ok == true && context.mounted) {
        context.read<AuthProvider>().logout();
      }
    });
  }
}

// ═══════════════════════════════════════════════════════════════════
//  TAB 1 – DASHBOARD / TỔNG QUAN HỆ THỐNG
// ═══════════════════════════════════════════════════════════════════

class _DashboardTab extends StatefulWidget {
  const _DashboardTab();
  @override
  State<_DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<_DashboardTab>
    with AutomaticKeepAliveClientMixin {
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final d = await AdminService.getDashboard();
    if (!mounted) return;
    if (d.isEmpty) {
      setState(() {
        _error = 'Không thể tải dữ liệu dashboard.';
        _loading = false;
      });
    } else {
      setState(() {
        _data = d;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: _kOrange));
    }
    if (_error != null || _data == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              color: Colors.white24,
              size: 56,
            ),
            const SizedBox(height: 14),
            Text(
              _error ?? 'Không có dữ liệu',
              style: const TextStyle(color: Colors.white38, fontSize: 14),
            ),
            const SizedBox(height: 14),
            TextButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Thử lại'),
              style: TextButton.styleFrom(foregroundColor: _kOrange),
            ),
          ],
        ),
      );
    }

    final totals = _data!['totals'] as Map<String, dynamic>? ?? {};
    final newUsersByDate =
        ((_data!['new_users_by_date'] as Map?)?.cast<String, dynamic>() ?? {})
            .map((k, v) => MapEntry(k, (v as num).toInt()));
    final readingByDate =
        ((_data!['reading_activity_by_date'] as Map?)
                    ?.cast<String, dynamic>() ??
                {})
            .map((k, v) => MapEntry(k, (v as num).toInt()));
    final topManga =
        (_data!['top_manga'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final dateRange = _data!['date_range'] as Map<String, dynamic>? ?? {};

    return RefreshIndicator(
      onRefresh: _load,
      color: _kOrange,
      child: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          // ── KPI Row ─────────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: _KpiCard(
                  label: 'Người dùng',
                  value: '${totals['users'] ?? 0}',
                  icon: Icons.people_alt_rounded,
                  color: _kBlue,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _KpiCard(
                  label: 'Manga',
                  value: '${totals['manga'] ?? 0}',
                  icon: Icons.menu_book_rounded,
                  color: _kGreen,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _KpiCard(
                  label: 'Báo cáo\nchờ xử lý',
                  value: '${totals['pending_reports'] ?? 0}',
                  icon: Icons.flag_rounded,
                  color: Colors.redAccent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── New Users Chart ─────────────────────────────────────
          _SectionCard(
            title: '👤  Người dùng mới (30 ngày gần nhất)',
            subtitle:
                'Từ ${dateRange['start'] ?? '—'} đến ${dateRange['end'] ?? '—'}',
            child: newUsersByDate.isEmpty
                ? const _EmptyChart()
                : _LineChartWidget(data: newUsersByDate, color: _kBlue),
          ),
          const SizedBox(height: 12),

          // ── Reading Activity Chart ──────────────────────────────
          _SectionCard(
            title: '📖  Lượt đọc theo ngày (30 ngày gần nhất)',
            subtitle: 'Số lượt đọc chapter mỗi ngày trên toàn hệ thống',
            child: readingByDate.isEmpty
                ? const _EmptyChart()
                : _BarChartWidget(data: readingByDate, color: _kOrange),
          ),
          const SizedBox(height: 12),

          // ── Top Manga ───────────────────────────────────────────
          _SectionCard(
            title: '🔥  Top manga đang đọc nhiều nhất',
            subtitle:
                'Sắp xếp theo số người đọc duy nhất trong khoảng thời gian đã chọn',
            child: topManga.isEmpty
                ? const _EmptyChart()
                : Column(
                    children: [
                      for (int i = 0; i < topManga.length; i++)
                        _TopMangaRow(rank: i + 1, item: topManga[i]),
                    ],
                  ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ── KPI Card ─────────────────────────────────────────────────────────

class _KpiCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;

  const _KpiCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(color: Colors.white54, fontSize: 10),
          ),
        ],
      ),
    );
  }
}

// ── Section Card ──────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;

  const _SectionCard({required this.title, this.subtitle, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 3),
            Text(
              subtitle!,
              style: const TextStyle(color: Colors.white38, fontSize: 11),
            ),
          ],
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _EmptyChart extends StatelessWidget {
  const _EmptyChart();
  @override
  Widget build(BuildContext context) => const SizedBox(
    height: 60,
    child: Center(
      child: Text(
        'Không có dữ liệu trong khoảng thời gian này',
        style: TextStyle(color: Colors.white24, fontSize: 12),
      ),
    ),
  );
}

// ── Top Manga Row ─────────────────────────────────────────────────────

class _TopMangaRow extends StatelessWidget {
  final int rank;
  final Map<String, dynamic> item;

  const _TopMangaRow({required this.rank, required this.item});

  @override
  Widget build(BuildContext context) {
    final readers = item['readers'] as int? ?? 0;
    final title = item['title']?.toString() ?? 'Không có tên';
    final medalColor = rank == 1
        ? const Color(0xFFFFD700)
        : rank == 2
        ? const Color(0xFFC0C0C0)
        : rank == 3
        ? const Color(0xFFCD7F32)
        : Colors.white24;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          // rank medal / number
          SizedBox(
            width: 30,
            child: rank <= 3
                ? Icon(Icons.emoji_events_rounded, color: medalColor, size: 18)
                : Text(
                    '#$rank',
                    style: const TextStyle(
                      color: Colors.white38,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: _kOrange.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.visibility_outlined,
                  size: 11,
                  color: _kOrange,
                ),
                const SizedBox(width: 4),
                Text(
                  '$readers',
                  style: const TextStyle(
                    color: _kOrange,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
//  CHART WIDGETS  (CustomPainter – không cần thư viện ngoài)
// ═══════════════════════════════════════════════════════════════════

// ── Line Chart ────────────────────────────────────────────────────────

class _LineChartWidget extends StatelessWidget {
  final Map<String, int> data;
  final Color color;

  const _LineChartWidget({required this.data, this.color = _kOrange});

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 140,
    child: CustomPaint(
      size: const Size(double.infinity, 140),
      painter: _LineChartPainter(data: data, color: color),
    ),
  );
}

class _LineChartPainter extends CustomPainter {
  final Map<String, int> data;
  final Color color;

  _LineChartPainter({required this.data, required this.color});

  static const _lp = 38.0, _rp = 8.0, _tp = 8.0, _bp = 26.0;

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;
    final sorted = data.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final vals = sorted.map((e) => e.value.toDouble()).toList();
    final maxVal = vals.reduce(math.max).clamp(1.0, double.maxFinite);
    final n = vals.length;

    final cw = size.width - _lp - _rp;
    final ch = size.height - _tp - _bp;

    // Grid lines
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.06)
      ..strokeWidth = 1;
    for (int i = 0; i <= 4; i++) {
      final y = _tp + i * ch / 4;
      canvas.drawLine(Offset(_lp, y), Offset(size.width - _rp, y), gridPaint);
    }

    Offset ptAt(int i) => Offset(
      _lp + (n <= 1 ? cw / 2 : i / (n - 1) * cw),
      _tp + ch - (vals[i] / maxVal) * ch,
    );
    final pts = List.generate(n, ptAt);

    // Gradient fill
    final fillPath = Path()..moveTo(pts.first.dx, _tp + ch);
    for (final p in pts) {
      fillPath.lineTo(p.dx, p.dy);
    }
    fillPath.lineTo(pts.last.dx, _tp + ch);
    fillPath.close();
    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: 0.35), color.withValues(alpha: 0.0)],
        ).createShader(Rect.fromLTWH(_lp, _tp, cw, ch)),
    );

    // Line
    final linePath = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (final p in pts.skip(1)) {
      linePath.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(
      linePath,
      Paint()
        ..color = color
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // Dots (only when sparse)
    if (n <= 16) {
      for (final p in pts) {
        canvas.drawCircle(p, 4, Paint()..color = color);
        canvas.drawCircle(
          p,
          4,
          Paint()
            ..color = _kCard
            ..strokeWidth = 2
            ..style = PaintingStyle.stroke,
        );
      }
    }

    // Y labels
    final tp2 = TextPainter(textDirection: TextDirection.ltr);
    for (int i = 0; i <= 4; i++) {
      final val = (maxVal * (4 - i) / 4).round();
      final y = _tp + i * ch / 4;
      tp2.text = TextSpan(
        text: val.toString(),
        style: const TextStyle(color: Colors.white38, fontSize: 9),
      );
      tp2.layout(maxWidth: _lp - 4);
      tp2.paint(canvas, Offset(_lp - tp2.width - 4, y - tp2.height / 2));
    }

    // X labels (≤5 evenly spaced)
    final step = (n / 4).ceil().clamp(1, n);
    final shown = <int>{};
    for (int i = 0; i < n; i += step) {
      shown.add(i);
    }
    shown.add(n - 1);
    for (final idx in shown) {
      final key = sorted[idx].key;
      final label = key.length >= 10 ? key.substring(5) : key;
      tp2.text = TextSpan(
        text: label,
        style: const TextStyle(color: Colors.white38, fontSize: 9),
      );
      tp2.layout();
      tp2.paint(
        canvas,
        Offset(pts[idx].dx - tp2.width / 2, size.height - _bp + 4),
      );
    }
  }

  @override
  bool shouldRepaint(_LineChartPainter old) =>
      old.data != data || old.color != color;
}

// ── Bar Chart ─────────────────────────────────────────────────────────

class _BarChartWidget extends StatelessWidget {
  final Map<String, int> data;
  final Color color;

  const _BarChartWidget({required this.data, this.color = _kOrange});

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 140,
    child: CustomPaint(
      size: const Size(double.infinity, 140),
      painter: _BarChartPainter(data: data, color: color),
    ),
  );
}

class _BarChartPainter extends CustomPainter {
  final Map<String, int> data;
  final Color color;

  _BarChartPainter({required this.data, required this.color});

  static const _lp = 38.0, _rp = 8.0, _tp = 8.0, _bp = 26.0;

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;
    final sorted = data.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final vals = sorted.map((e) => e.value.toDouble()).toList();
    final maxVal = vals.reduce(math.max).clamp(1.0, double.maxFinite);
    final n = vals.length;

    final cw = size.width - _lp - _rp;
    final ch = size.height - _tp - _bp;
    final gap = cw / n;
    final barW = (gap * 0.6).clamp(2.0, 12.0);
    final rr = Radius.circular(barW / 2);

    // Grid
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.06)
      ..strokeWidth = 1;
    for (int i = 1; i <= 4; i++) {
      final y = _tp + i * ch / 4;
      canvas.drawLine(Offset(_lp, y), Offset(size.width - _rp, y), gridPaint);
    }

    for (int i = 0; i < n; i++) {
      final barH = (vals[i] / maxVal) * ch;
      final x = _lp + i * gap + gap / 2 - barW / 2;
      final y = _tp + ch - barH;
      if (barH < 1) continue;
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTWH(x, y, barW, barH),
          topLeft: rr,
          topRight: rr,
        ),
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [color, color.withValues(alpha: 0.5)],
          ).createShader(Rect.fromLTWH(x, y, barW, barH)),
      );
    }

    // Y labels
    final tp2 = TextPainter(textDirection: TextDirection.ltr);
    for (int i = 0; i <= 4; i++) {
      final val = (maxVal * (4 - i) / 4).round();
      final y = _tp + i * ch / 4;
      tp2.text = TextSpan(
        text: val.toString(),
        style: const TextStyle(color: Colors.white38, fontSize: 9),
      );
      tp2.layout(maxWidth: _lp - 4);
      tp2.paint(canvas, Offset(_lp - tp2.width - 4, y - tp2.height / 2));
    }

    // X labels (first / mid / last)
    for (final idx in {0, n ~/ 2, n - 1}) {
      if (idx >= n) continue;
      final key = sorted[idx].key;
      final label = key.length >= 10 ? key.substring(5) : key;
      tp2.text = TextSpan(
        text: label,
        style: const TextStyle(color: Colors.white38, fontSize: 9),
      );
      tp2.layout();
      final cx = _lp + idx * gap + gap / 2;
      tp2.paint(canvas, Offset(cx - tp2.width / 2, size.height - _bp + 4));
    }
  }

  @override
  bool shouldRepaint(_BarChartPainter old) =>
      old.data != data || old.color != color;
}

// ═══════════════════════════════════════════════════════════════════
//  TAB 2 – QUẢN LÝ NGƯỜI DÙNG
// ═══════════════════════════════════════════════════════════════════

class _UsersTab extends StatefulWidget {
  const _UsersTab();
  @override
  State<_UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends State<_UsersTab>
    with AutomaticKeepAliveClientMixin {
  List<Map<String, dynamic>> _users = [];
  bool _isLoading = true;
  int _page = 1, _totalPages = 1, _total = 0;
  final _searchCtrl = TextEditingController();
  String _currentQuery = '';
  _UserLayout _layout = _UserLayout.list;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load({int page = 1, String q = ''}) async {
    setState(() => _isLoading = true);
    final data = await AdminService.listUsers(page: page, limit: 20, q: q);
    if (!mounted) return;
    setState(() {
      _users = (data['items'] as List? ?? []).cast<Map<String, dynamic>>();
      _page = page;
      _total = data['total'] ?? 0;
      _totalPages = data['total_pages'] ?? 1;
      _isLoading = false;
    });
  }

  Future<void> _toggleBan(Map<String, dynamic> user) async {
    final isLocked = user['IsLocked'] as bool? ?? false;
    final userId = user['UserId']?.toString() ?? '';
    final name = user['Username']?.toString() ?? userId;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _kCard2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          isLocked ? 'Mở khoá "$name"?' : 'Khoá "$name"?',
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
        content: Text(
          isLocked
              ? 'Người dùng sẽ có thể đăng nhập lại.'
              : 'Người dùng sẽ bị cấm đăng nhập.',
          style: const TextStyle(color: Colors.white54),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Huỷ', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              isLocked ? 'Mở khoá' : 'Khoá',
              style: TextStyle(
                color: isLocked ? _kGreen : Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    final ok = isLocked
        ? await AdminService.unbanUser(userId)
        : await AdminService.banUser(userId);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? (isLocked ? 'Đã mở khoá $name' : 'Đã khoá $name')
              : 'Thao tác thất bại.',
        ),
        backgroundColor: ok ? (isLocked ? _kGreen : Colors.orange) : Colors.red,
      ),
    );
    if (ok) _load(page: _page, q: _currentQuery);
  }

  void _showUserDetail(Map<String, dynamic> user) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _UserDetailSheet(
        user: user,
        onToggleBan: () {
          Navigator.pop(context);
          _toggleBan(user);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      children: [
        // ── Search + layout toggle ──────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Tìm theo tên / email...',
                    hintStyle: const TextStyle(color: Colors.white38),
                    prefixIcon: const Icon(
                      Icons.search,
                      color: Colors.white38,
                      size: 20,
                    ),
                    suffixIcon: _searchCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(
                              Icons.clear,
                              color: Colors.white38,
                              size: 18,
                            ),
                            onPressed: () {
                              _searchCtrl.clear();
                              _currentQuery = '';
                              _load(page: 1, q: '');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: _kCard2,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  onSubmitted: (q) {
                    _currentQuery = q;
                    _load(page: 1, q: q);
                  },
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 8),
              _LayoutToggle(
                current: _layout.index,
                icons: const [Icons.view_list_rounded, Icons.grid_view_rounded],
                onChanged: (i) =>
                    setState(() => _layout = _UserLayout.values[i]),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            children: [
              Text(
                'Tổng: $_total người dùng',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
              const Spacer(),
              Text(
                'Trang $_page / $_totalPages',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
          ),
        ),
        // ── Content ────────────────────────────────────────────
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: _kOrange))
              : _users.isEmpty
              ? const Center(
                  child: Text(
                    'Không có người dùng.',
                    style: TextStyle(color: Colors.white38),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () => _load(page: _page, q: _currentQuery),
                  color: _kOrange,
                  child: _layout == _UserLayout.list
                      ? _buildListView()
                      : _buildCardView(),
                ),
        ),
        // ── Pagination ─────────────────────────────────────────
        if (_totalPages > 1)
          _PaginationBar(
            page: _page,
            totalPages: _totalPages,
            onPrev: () => _load(page: _page - 1, q: _currentQuery),
            onNext: () => _load(page: _page + 1, q: _currentQuery),
          ),
      ],
    );
  }

  Widget _buildListView() => ListView.separated(
    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
    itemCount: _users.length,
    separatorBuilder: (_, _) => const SizedBox(height: 6),
    itemBuilder: (_, i) => _UserListTile(
      user: _users[i],
      onTap: () => _showUserDetail(_users[i]),
      onBanToggle: () => _toggleBan(_users[i]),
    ),
  );

  Widget _buildCardView() => GridView.builder(
    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 2,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 0.82,
    ),
    itemCount: _users.length,
    itemBuilder: (_, i) => _UserCard(
      user: _users[i],
      onTap: () => _showUserDetail(_users[i]),
      onBanToggle: () => _toggleBan(_users[i]),
    ),
  );
}

// ── User List Tile ────────────────────────────────────────────────────

class _UserListTile extends StatelessWidget {
  final Map<String, dynamic> user;
  final VoidCallback onTap, onBanToggle;

  const _UserListTile({
    required this.user,
    required this.onTap,
    required this.onBanToggle,
  });

  @override
  Widget build(BuildContext context) {
    final isLocked = user['IsLocked'] as bool? ?? false;
    final username = user['Username']?.toString() ?? '';
    final email = user['Email']?.toString() ?? '';
    final role = user['Role']?.toString() ?? 'user';
    final avatar = user['Avatar']?.toString();
    final createdAt = user['CreatedAt']?.toString();
    final isVerified = user['IsVerified'] as bool? ?? false;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        decoration: BoxDecoration(
          color: _kCard2,
          borderRadius: BorderRadius.circular(10),
          border: isLocked
              ? Border.all(color: Colors.red.withValues(alpha: 0.4), width: 1)
              : null,
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 4,
          ),
          leading: _UserAvatar(username: username, avatar: avatar, size: 20),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  username,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (role == 'admin') _RoleBadge(label: 'ADMIN', color: _kOrange),
              if (isLocked) _RoleBadge(label: 'KHOÁ', color: Colors.red),
              if (isVerified)
                const Padding(
                  padding: EdgeInsets.only(left: 4),
                  child: Icon(Icons.verified, size: 13, color: _kBlue),
                ),
            ],
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                email,
                style: const TextStyle(color: Colors.white38, fontSize: 12),
                overflow: TextOverflow.ellipsis,
              ),
              if (createdAt != null)
                Text(
                  'Tham gia: ${_fmtDate(createdAt)}',
                  style: const TextStyle(color: Colors.white24, fontSize: 11),
                ),
            ],
          ),
          trailing: IconButton(
            icon: Icon(
              isLocked ? Icons.lock_open_rounded : Icons.lock_rounded,
              color: isLocked ? _kGreen : Colors.orange,
              size: 20,
            ),
            tooltip: isLocked ? 'Mở khoá' : 'Khoá',
            onPressed: onBanToggle,
          ),
        ),
      ),
    );
  }
}

// ── User Card ─────────────────────────────────────────────────────────

class _UserCard extends StatelessWidget {
  final Map<String, dynamic> user;
  final VoidCallback onTap, onBanToggle;

  const _UserCard({
    required this.user,
    required this.onTap,
    required this.onBanToggle,
  });

  @override
  Widget build(BuildContext context) {
    final isLocked = user['IsLocked'] as bool? ?? false;
    final username = user['Username']?.toString() ?? '';
    final email = user['Email']?.toString() ?? '';
    final role = user['Role']?.toString() ?? 'user';
    final avatar = user['Avatar']?.toString();
    final isVerified = user['IsVerified'] as bool? ?? false;
    final createdAt = user['CreatedAt']?.toString();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: _kCard2,
          borderRadius: BorderRadius.circular(14),
          border: isLocked
              ? Border.all(color: Colors.red.withValues(alpha: 0.5))
              : null,
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Avatar + verified badge
            Stack(
              alignment: Alignment.bottomRight,
              children: [
                _UserAvatar(username: username, avatar: avatar, size: 26),
                if (isVerified)
                  Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: _kCard2,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.verified, size: 13, color: _kBlue),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              username,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              textAlign: TextAlign.center,
            ),
            Text(
              email,
              style: const TextStyle(color: Colors.white38, fontSize: 10),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 4,
              alignment: WrapAlignment.center,
              children: [
                if (role == 'admin')
                  _RoleBadge(label: 'ADMIN', color: _kOrange),
                if (isLocked) _RoleBadge(label: 'KHOÁ', color: Colors.red),
                if (!isLocked && role != 'admin')
                  _RoleBadge(label: 'USER', color: Colors.white30),
              ],
            ),
            if (createdAt != null) ...[
              const SizedBox(height: 4),
              Text(
                _fmtDate(createdAt),
                style: const TextStyle(color: Colors.white24, fontSize: 9),
              ),
            ],
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 28,
              child: OutlinedButton.icon(
                onPressed: onBanToggle,
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                    color: isLocked ? _kGreen : Colors.orange,
                    width: 0.8,
                  ),
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                icon: Icon(
                  isLocked ? Icons.lock_open_rounded : Icons.lock_rounded,
                  size: 13,
                  color: isLocked ? _kGreen : Colors.orange,
                ),
                label: Text(
                  isLocked ? 'Mở khoá' : 'Khoá',
                  style: TextStyle(
                    color: isLocked ? _kGreen : Colors.orange,
                    fontSize: 11,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── User Detail Bottom Sheet ──────────────────────────────────────────

class _UserDetailSheet extends StatelessWidget {
  final Map<String, dynamic> user;
  final VoidCallback onToggleBan;

  const _UserDetailSheet({required this.user, required this.onToggleBan});

  @override
  Widget build(BuildContext context) {
    final isLocked = user['IsLocked'] as bool? ?? false;
    final username = user['Username']?.toString() ?? '';
    final email = user['Email']?.toString() ?? '';
    final role = user['Role']?.toString() ?? 'user';
    final avatar = user['Avatar']?.toString();
    final isVerified = user['IsVerified'] as bool? ?? false;
    final createdAt = user['CreatedAt']?.toString();
    final updatedAt = user['UpdatedAt']?.toString();
    final bio = user['Bio']?.toString();
    final displayName = user['DisplayName']?.toString();
    final userId = user['UserId']?.toString() ?? '';

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Drag handle
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Expanded(
              child: ListView(
                controller: ctrl,
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                children: [
                  // ── Header ─────────────────────────────
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _UserAvatar(username: username, avatar: avatar, size: 30),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    username,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                    ),
                                  ),
                                ),
                                if (isVerified)
                                  const Icon(
                                    Icons.verified,
                                    size: 18,
                                    color: _kBlue,
                                  ),
                              ],
                            ),
                            if (displayName != null && displayName.isNotEmpty)
                              Text(
                                displayName,
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 13,
                                ),
                              ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 4,
                              children: [
                                _RoleBadge(
                                  label: role.toUpperCase(),
                                  color: role == 'admin'
                                      ? _kOrange
                                      : Colors.white30,
                                ),
                                _RoleBadge(
                                  label: isLocked ? 'BỊ KHOÁ' : 'HOẠT ĐỘNG',
                                  color: isLocked ? Colors.red : _kGreen,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  const Divider(color: Colors.white12),
                  const SizedBox(height: 10),

                  // ── Fields ──────────────────────────────
                  _InfoRow(
                    icon: Icons.email_outlined,
                    label: 'Email',
                    value: email,
                  ),
                  _InfoRow(
                    icon: Icons.badge_outlined,
                    label: 'User ID',
                    value: userId,
                    mono: true,
                  ),
                  _InfoRow(
                    icon: Icons.calendar_today_outlined,
                    label: 'Tham gia',
                    value: createdAt != null ? _fmtDateLong(createdAt) : '—',
                  ),
                  if (updatedAt != null)
                    _InfoRow(
                      icon: Icons.update_rounded,
                      label: 'Cập nhật',
                      value: _fmtDateLong(updatedAt),
                    ),
                  _InfoRow(
                    icon: Icons.verified_user_outlined,
                    label: 'Xác thực email',
                    value: isVerified ? 'Đã xác thực ✓' : 'Chưa xác thực',
                    valueColor: isVerified ? _kGreen : Colors.orange,
                  ),
                  _InfoRow(
                    icon: Icons.lock_outline,
                    label: 'Trạng thái',
                    value: isLocked
                        ? 'Tài khoản bị khoá'
                        : 'Hoạt động bình thường',
                    valueColor: isLocked ? Colors.red : _kGreen,
                  ),

                  // Bio
                  if (bio != null && bio.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _kCard2,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Tiểu sử',
                            style: TextStyle(
                              color: Colors.white38,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            bio,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // Action button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: onToggleBan,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isLocked
                            ? _kGreen.withValues(alpha: 0.15)
                            : Colors.red.withValues(alpha: 0.15),
                        foregroundColor: isLocked ? _kGreen : Colors.redAccent,
                        side: BorderSide(
                          color: isLocked ? _kGreen : Colors.redAccent,
                          width: 1,
                        ),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: Icon(
                        isLocked ? Icons.lock_open_rounded : Icons.lock_rounded,
                        size: 18,
                      ),
                      label: Text(
                        isLocked ? 'Mở khoá tài khoản' : 'Khoá tài khoản này',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color? valueColor;
  final bool mono;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
    this.mono = false,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(
      children: [
        Icon(icon, size: 14, color: Colors.white38),
        const SizedBox(width: 8),
        SizedBox(
          width: 108,
          child: Text(
            label,
            style: const TextStyle(color: Colors.white38, fontSize: 12),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: valueColor ?? Colors.white,
              fontSize: 12,
              fontFamily: mono ? 'monospace' : null,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    ),
  );
}

// ═══════════════════════════════════════════════════════════════════
//  TAB 3 – DANH SÁCH MANGA
// ═══════════════════════════════════════════════════════════════════

class _MangaTab extends StatefulWidget {
  const _MangaTab();
  @override
  State<_MangaTab> createState() => _MangaTabState();
}

class _MangaTabState extends State<_MangaTab>
    with AutomaticKeepAliveClientMixin {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  int _page = 1, _totalPages = 1, _total = 0;
  final _searchCtrl = TextEditingController();
  String _currentQuery = '';
  _MangaLayout _layout = _MangaLayout.grid;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load({int page = 1, String q = ''}) async {
    setState(() => _loading = true);
    final Map<String, dynamic> data;
    if (q.isEmpty) {
      data = await MangaService.getMangaList(
        page: page,
        limit: 20,
        sort: 'updated_desc',
      );
    } else {
      data = await MangaService.searchManga(query: q, page: page, limit: 20);
    }
    if (!mounted) return;
    final raw = (data['items'] ?? data['manga'] ?? []) as List;
    setState(() {
      _items = raw.cast<Map<String, dynamic>>();
      _page = page;
      _total = data['total'] ?? _items.length;
      _totalPages = data['total_pages'] ?? 1;
      _loading = false;
    });
  }

  String _title(Map m) =>
      m['TitleEn']?.toString() ??
      m['title']?.toString() ??
      m['title_en']?.toString() ??
      'Không có tên';
  String? _cover(Map m) =>
      m['CoverUrl']?.toString() ??
      m['cover_url']?.toString() ??
      m['coverUrl']?.toString();
  String? _mid(Map m) =>
      m['MangaId']?.toString() ??
      m['manga_id']?.toString() ??
      m['id']?.toString();
  String? _fileName(Map m) =>
      m['CoverFileName']?.toString() ?? m['cover_file_name']?.toString();
  String _status(Map m) =>
      m['Status']?.toString() ?? m['status']?.toString() ?? '';

  Color _statusColor(String s) {
    switch (s) {
      case 'ongoing':
        return _kGreen;
      case 'completed':
        return _kBlue;
      case 'hiatus':
        return Colors.orange;
      default:
        return Colors.white38;
    }
  }

  String _statusLabel(String s) {
    switch (s) {
      case 'ongoing':
        return 'Đang ra';
      case 'completed':
        return 'Hoàn thành';
      case 'hiatus':
        return 'Tạm dừng';
      case 'cancelled':
        return 'Đã huỷ';
      default:
        return s;
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      children: [
        // ── Search + layout toggle ──────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Tìm manga theo tên...',
                    hintStyle: const TextStyle(color: Colors.white38),
                    prefixIcon: const Icon(
                      Icons.search,
                      color: Colors.white38,
                      size: 20,
                    ),
                    suffixIcon: _searchCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(
                              Icons.clear,
                              color: Colors.white38,
                              size: 18,
                            ),
                            onPressed: () {
                              _searchCtrl.clear();
                              _currentQuery = '';
                              _load(page: 1, q: '');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: _kCard2,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  onSubmitted: (q) {
                    _currentQuery = q;
                    _load(page: 1, q: q);
                  },
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 8),
              _LayoutToggle(
                current: _layout.index,
                icons: const [Icons.grid_view_rounded, Icons.view_list_rounded],
                onChanged: (i) =>
                    setState(() => _layout = _MangaLayout.values[i]),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            children: [
              Text(
                'Tổng: $_total manga',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
              const Spacer(),
              Text(
                'Trang $_page / $_totalPages',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
          ),
        ),
        // ── Content ────────────────────────────────────────────
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: _kOrange))
              : _items.isEmpty
              ? const Center(
                  child: Text(
                    'Không có manga.',
                    style: TextStyle(color: Colors.white38),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () => _load(page: _page, q: _currentQuery),
                  color: _kOrange,
                  child: _layout == _MangaLayout.grid
                      ? _buildGrid()
                      : _buildList(),
                ),
        ),
        if (_totalPages > 1)
          _PaginationBar(
            page: _page,
            totalPages: _totalPages,
            onPrev: () => _load(page: _page - 1, q: _currentQuery),
            onNext: () => _load(page: _page + 1, q: _currentQuery),
          ),
      ],
    );
  }

  Widget _buildGrid() => GridView.builder(
    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 3,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 0.56,
    ),
    itemCount: _items.length,
    itemBuilder: (_, i) {
      final m = _items[i];
      final st = _status(m);
      return GestureDetector(
        onTap: () {},
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: MangaCoverImage(
                  coverUrl: _cover(m),
                  mangaId: _mid(m),
                  fileName: _fileName(m),
                  width: double.infinity,
                  height: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _title(m),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w600,
                height: 1.2,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
            if (st.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                _statusLabel(st),
                style: TextStyle(color: _statusColor(st), fontSize: 9),
              ),
            ],
          ],
        ),
      );
    },
  );

  Widget _buildList() => ListView.separated(
    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
    itemCount: _items.length,
    separatorBuilder: (_, _) => const SizedBox(height: 6),
    itemBuilder: (_, i) {
      final m = _items[i];
      final st = _status(m);
      final id = _mid(m) ?? '';
      return Container(
        decoration: BoxDecoration(
          color: _kCard2,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(10),
              ),
              child: MangaCoverImage(
                coverUrl: _cover(m),
                mangaId: _mid(m),
                fileName: _fileName(m),
                width: 58,
                height: 78,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _title(m),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                    const SizedBox(height: 4),
                    if (st.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: _statusColor(st).withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _statusLabel(st),
                          style: TextStyle(
                            color: _statusColor(st),
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    const SizedBox(height: 4),
                    if (id.isNotEmpty)
                      Text(
                        id,
                        style: const TextStyle(
                          color: Colors.white24,
                          fontSize: 9,
                          fontFamily: 'monospace',
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
          ],
        ),
      );
    },
  );
}

// ═══════════════════════════════════════════════════════════════════
//  TAB 4 – BÁO CÁO BÌNH LUẬN
// ═══════════════════════════════════════════════════════════════════

class _CommentsTab extends StatefulWidget {
  const _CommentsTab();
  @override
  State<_CommentsTab> createState() => _CommentsTabState();
}

class _CommentsTabState extends State<_CommentsTab>
    with AutomaticKeepAliveClientMixin {
  List<Map<String, dynamic>> _items = [];
  bool _isLoading = true;
  int _page = 1, _totalPages = 1, _total = 0;
  String? _statusFilter;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({int page = 1}) async {
    setState(() => _isLoading = true);
    final data = await AdminService.listReportedComments(
      page: page,
      limit: 20,
      status: _statusFilter,
    );
    if (!mounted) return;
    setState(() {
      _items = (data['items'] as List? ?? []).cast<Map<String, dynamic>>();
      _page = page;
      _total = data['total'] ?? 0;
      _totalPages = data['total_pages'] ?? 1;
      _isLoading = false;
    });
  }

  Future<void> _deleteComment(String commentId) async {
    final ok = await AdminService.deleteComment(commentId);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'Đã xoá bình luận.' : 'Xoá thất bại.'),
        backgroundColor: ok ? Colors.red : Colors.grey,
      ),
    );
    if (ok) _load(page: _page);
  }

  Future<void> _ignoreComment(String commentId) async {
    final ok = await AdminService.ignoreReports(commentId);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'Đã bỏ qua báo cáo.' : 'Thao tác thất bại.'),
        backgroundColor: ok ? _kGreen : Colors.grey,
      ),
    );
    if (ok) _load(page: _page);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      children: [
        // ── Filter Chips ────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
          child: Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _FilterChip(
                        label: 'Tất cả',
                        selected: _statusFilter == null,
                        onTap: () {
                          setState(() => _statusFilter = null);
                          _load(page: 1);
                        },
                      ),
                      const SizedBox(width: 6),
                      _FilterChip(
                        label: 'Chờ xử lý',
                        selected: _statusFilter == 'pending',
                        onTap: () {
                          setState(() => _statusFilter = 'pending');
                          _load(page: 1);
                        },
                      ),
                      const SizedBox(width: 6),
                      _FilterChip(
                        label: 'Đã giải quyết',
                        selected: _statusFilter == 'resolved',
                        onTap: () {
                          setState(() => _statusFilter = 'resolved');
                          _load(page: 1);
                        },
                      ),
                      const SizedBox(width: 6),
                      _FilterChip(
                        label: 'Bỏ qua',
                        selected: _statusFilter == 'ignored',
                        onTap: () {
                          setState(() => _statusFilter = 'ignored');
                          _load(page: 1);
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$_total báo cáo',
                style: const TextStyle(color: Colors.white38, fontSize: 11),
              ),
            ],
          ),
        ),
        // ── Content ─────────────────────────────────────────────
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: _kOrange))
              : _items.isEmpty
              ? const Center(
                  child: Text(
                    'Không có báo cáo.',
                    style: TextStyle(color: Colors.white38),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () => _load(page: _page),
                  color: _kOrange,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
                    itemCount: _items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 6),
                    itemBuilder: (_, i) => _CommentReportTile(
                      item: _items[i],
                      onDelete: () => _deleteComment(
                        _items[i]['comment_id']?.toString() ?? '',
                      ),
                      onIgnore: () => _ignoreComment(
                        _items[i]['comment_id']?.toString() ?? '',
                      ),
                    ),
                  ),
                ),
        ),
        if (_totalPages > 1)
          _PaginationBar(
            page: _page,
            totalPages: _totalPages,
            onPrev: () => _load(page: _page - 1),
            onNext: () => _load(page: _page + 1),
          ),
      ],
    );
  }
}

class _CommentReportTile extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback onDelete, onIgnore;

  const _CommentReportTile({
    required this.item,
    required this.onDelete,
    required this.onIgnore,
  });

  @override
  Widget build(BuildContext context) {
    final username = item['username']?.toString() ?? '?';
    final mangaTitle = item['manga_title']?.toString() ?? 'Không rõ';
    final content = item['content']?.toString() ?? '';
    final reportCount = item['report_count'] as int? ?? 0;
    final createdAt = item['created_at']?.toString();

    return Container(
      decoration: BoxDecoration(
        color: _kCard2,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.2)),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              const Icon(Icons.person_outline, size: 13, color: Colors.white38),
              const SizedBox(width: 4),
              Text(
                username,
                style: const TextStyle(
                  color: _kOrange,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.menu_book_rounded,
                size: 12,
                color: Colors.white24,
              ),
              const SizedBox(width: 3),
              Expanded(
                child: Text(
                  mangaTitle,
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.flag_rounded,
                      size: 11,
                      color: Colors.redAccent,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      '$reportCount',
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Content
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _kCard3,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              content,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (createdAt != null) ...[
            const SizedBox(height: 4),
            Text(
              _fmtDateLong(createdAt),
              style: const TextStyle(color: Colors.white24, fontSize: 10),
            ),
          ],
          const SizedBox(height: 10),
          // Actions
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onIgnore,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.white24),
                    foregroundColor: Colors.white54,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon: const Icon(Icons.visibility_off_outlined, size: 14),
                  label: const Text('Bỏ qua', style: TextStyle(fontSize: 12)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onDelete,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.withValues(alpha: 0.15),
                    foregroundColor: Colors.redAccent,
                    side: const BorderSide(color: Colors.redAccent, width: 0.8),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon: const Icon(Icons.delete_outline, size: 14),
                  label: const Text(
                    'Xoá bình luận',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
//  SHARED WIDGETS
// ═══════════════════════════════════════════════════════════════════

class _UserAvatar extends StatelessWidget {
  final String username;
  final String? avatar;
  final double size;

  const _UserAvatar({required this.username, this.avatar, required this.size});

  @override
  Widget build(BuildContext context) => CircleAvatar(
    radius: size,
    backgroundColor: _kCard3,
    backgroundImage: (avatar != null && avatar!.isNotEmpty)
        ? NetworkImage(avatar!)
        : null,
    child: (avatar == null || avatar!.isEmpty)
        ? Text(
            username.isNotEmpty ? username[0].toUpperCase() : '?',
            style: TextStyle(
              color: _kOrange,
              fontWeight: FontWeight.bold,
              fontSize: size * 0.65,
            ),
          )
        : null,
  );
}

class _RoleBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _RoleBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(right: 2),
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.2),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(
      label,
      style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold),
    ),
  );
}

class _LayoutToggle extends StatelessWidget {
  final int current;
  final List<IconData> icons;
  final ValueChanged<int> onChanged;

  const _LayoutToggle({
    required this.current,
    required this.icons,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: _kCard2,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < icons.length; i++)
          GestureDetector(
            onTap: () => onChanged(i),
            child: Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: current == i
                    ? _kOrange.withValues(alpha: 0.2)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icons[i],
                size: 18,
                color: current == i ? _kOrange : Colors.white38,
              ),
            ),
          ),
      ],
    ),
  );
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: selected ? _kOrange.withValues(alpha: 0.2) : _kCard2,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: selected ? _kOrange : Colors.transparent),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: selected ? _kOrange : Colors.white54,
          fontSize: 12,
          fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
    ),
  );
}

class _PaginationBar extends StatelessWidget {
  final int page, totalPages;
  final VoidCallback onPrev, onNext;

  const _PaginationBar({
    required this.page,
    required this.totalPages,
    required this.onPrev,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) => Container(
    color: _kCard,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left, color: Colors.white),
          onPressed: page > 1 ? onPrev : null,
        ),
        Text(
          '$page / $totalPages',
          style: const TextStyle(color: Colors.white),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right, color: Colors.white),
          onPressed: page < totalPages ? onNext : null,
        ),
      ],
    ),
  );
}

// ═══════════════════════════════════════════════════════════════════
//  UTILITIES
// ═══════════════════════════════════════════════════════════════════

String _fmtDate(String? iso) {
  if (iso == null || iso.isEmpty) return '—';
  try {
    final dt = DateTime.parse(iso).toLocal();
    return '${dt.day.toString().padLeft(2, '0')}'
        '/${dt.month.toString().padLeft(2, '0')}'
        '/${dt.year}';
  } catch (_) {
    return iso.substring(0, math.min(10, iso.length));
  }
}

String _fmtDateLong(String? iso) {
  if (iso == null || iso.isEmpty) return '—';
  try {
    final dt = DateTime.parse(iso).toLocal();
    return '${dt.day.toString().padLeft(2, '0')}'
        '/${dt.month.toString().padLeft(2, '0')}'
        '/${dt.year}  '
        '${dt.hour.toString().padLeft(2, '0')}'
        ':${dt.minute.toString().padLeft(2, '0')}';
  } catch (_) {
    return iso;
  }
}
