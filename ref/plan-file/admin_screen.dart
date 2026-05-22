// lib/screens/admin/admin_screen.dart
//
// Giao diện quản trị viên (chỉ hiện với role == 'admin').
// Tab 1: Quản lý người dùng (danh sách, khoá/mở khoá, tìm kiếm)
// Tab 2: Quản lý bình luận bị báo cáo (xoá / bỏ qua)

import 'package:flutter/material.dart';
import '../../services/admin_service.dart';

const _kOrange = Color(0xFFFF6740);
const _kBg = Color(0xFF121212);
const _kCard = Color(0xFF1E1E1E);
const _kCard2 = Color(0xFF2A2A2A);

class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: _kBg,
        appBar: AppBar(
          backgroundColor: _kCard,
          title: const Row(
            children: [
              Icon(Icons.admin_panel_settings, color: _kOrange, size: 22),
              SizedBox(width: 8),
              Text(
                'Quản trị',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          iconTheme: const IconThemeData(color: Colors.white),
          bottom: const TabBar(
            indicatorColor: _kOrange,
            labelColor: _kOrange,
            unselectedLabelColor: Colors.white54,
            tabs: [
              Tab(icon: Icon(Icons.people_alt_outlined), text: 'Người dùng'),
              Tab(icon: Icon(Icons.flag_outlined), text: 'Báo cáo'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _UsersTab(),
            _CommentsTab(),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════
//  TAB 1 – QUẢN LÝ NGƯỜI DÙNG
// ════════════════════════════════════════════════════════

class _UsersTab extends StatefulWidget {
  const _UsersTab();

  @override
  State<_UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends State<_UsersTab> {
  List<Map<String, dynamic>> _users = [];
  bool _isLoading = true;
  int _page = 1;
  int _totalPages = 1;
  int _total = 0;
  final _searchCtrl = TextEditingController();
  String _currentQuery = '';

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
            child:
                const Text('Huỷ', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              isLocked ? 'Mở khoá' : 'Khoá',
              style: TextStyle(
                  color: isLocked ? Colors.green : Colors.red,
                  fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    bool ok;
    if (isLocked) {
      ok = await AdminService.unbanUser(userId);
    } else {
      ok = await AdminService.banUser(userId);
    }

    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isLocked ? 'Đã mở khoá $name' : 'Đã khoá $name'),
          backgroundColor: isLocked ? Colors.green : Colors.orange,
        ),
      );
      _load(page: _page, q: _currentQuery);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Thao tác thất bại.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Search bar ──
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: TextField(
            controller: _searchCtrl,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Tìm theo tên / email...',
              hintStyle: const TextStyle(color: Colors.white38),
              prefixIcon:
                  const Icon(Icons.search, color: Colors.white38, size: 20),
              suffixIcon: _searchCtrl.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear,
                          color: Colors.white38, size: 18),
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

        // ── Stats bar ──
        Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            children: [
              Text(
                'Tổng: $_total người dùng',
                style:
                    const TextStyle(color: Colors.white54, fontSize: 12),
              ),
              const Spacer(),
              Text(
                'Trang $_page / $_totalPages',
                style:
                    const TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
          ),
        ),

        // ── List ──
        Expanded(
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: _kOrange))
              : _users.isEmpty
                  ? const Center(
                      child: Text('Không có người dùng.',
                          style: TextStyle(color: Colors.white38)))
                  : RefreshIndicator(
                      onRefresh: () =>
                          _load(page: _page, q: _currentQuery),
                      color: _kOrange,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                        itemCount: _users.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 6),
                        itemBuilder: (_, i) => _userTile(_users[i]),
                      ),
                    ),
        ),

        // ── Pagination ──
        if (_totalPages > 1)
          Container(
            color: _kCard,
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left, color: Colors.white),
                  onPressed: _page > 1
                      ? () =>
                          _load(page: _page - 1, q: _currentQuery)
                      : null,
                ),
                Text(
                  '$_page / $_totalPages',
                  style: const TextStyle(color: Colors.white),
                ),
                IconButton(
                  icon:
                      const Icon(Icons.chevron_right, color: Colors.white),
                  onPressed: _page < _totalPages
                      ? () =>
                          _load(page: _page + 1, q: _currentQuery)
                      : null,
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _userTile(Map<String, dynamic> user) {
    final isLocked = user['IsLocked'] as bool? ?? false;
    final username = user['Username']?.toString() ?? '';
    final email = user['Email']?.toString() ?? '';
    final role = user['Role']?.toString() ?? 'user';
    final avatar = user['Avatar']?.toString();

    return Container(
      decoration: BoxDecoration(
        color: _kCard2,
        borderRadius: BorderRadius.circular(10),
        border: isLocked
            ? Border.all(color: Colors.red.withValues(alpha: 0.4), width: 1)
            : null,
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: CircleAvatar(
          radius: 20,
          backgroundColor: _kCard,
          backgroundImage:
              (avatar != null && avatar.isNotEmpty) ? NetworkImage(avatar) : null,
          child: (avatar == null || avatar.isEmpty)
              ? Text(
                  username.isNotEmpty ? username[0].toUpperCase() : '?',
                  style: const TextStyle(
                      color: _kOrange, fontWeight: FontWeight.bold),
                )
              : null,
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                username,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (role == 'admin')
              Container(
                margin: const EdgeInsets.only(left: 6),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: _kOrange.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'ADMIN',
                  style: TextStyle(
                      color: _kOrange,
                      fontSize: 9,
                      fontWeight: FontWeight.bold),
                ),
              ),
            if (isLocked)
              Container(
                margin: const EdgeInsets.only(left: 6),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'KHOÁ',
                  style: TextStyle(
                      color: Colors.red,
                      fontSize: 9,
                      fontWeight: FontWeight.bold),
                ),
              ),
          ],
        ),
        subtitle: Text(
          email,
          style: const TextStyle(color: Colors.white38, fontSize: 12),
          overflow: TextOverflow.ellipsis,
        ),
        trailing: role == 'admin'
            ? null
            : IconButton(
                icon: Icon(
                  isLocked ? Icons.lock_open_outlined : Icons.lock_outline,
                  color: isLocked ? Colors.green : Colors.red,
                  size: 20,
                ),
                tooltip: isLocked ? 'Mở khoá' : 'Khoá tài khoản',
                onPressed: () => _toggleBan(user),
              ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════
//  TAB 2 – QUẢN LÝ BÌNH LUẬN BÁO CÁO
// ════════════════════════════════════════════════════════

class _CommentsTab extends StatefulWidget {
  const _CommentsTab();

  @override
  State<_CommentsTab> createState() => _CommentsTabState();
}

class _CommentsTabState extends State<_CommentsTab> {
  List<Map<String, dynamic>> _comments = [];
  bool _isLoading = true;
  int _page = 1;
  int _totalPages = 1;
  int _total = 0;
  String? _filterStatus; // null = all, 'pending', 'resolved', 'ignored'

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
      status: _filterStatus,
    );
    if (!mounted) return;
    setState(() {
      _comments =
          (data['items'] as List? ?? []).cast<Map<String, dynamic>>();
      _page = page;
      _total = data['total'] ?? 0;
      _totalPages = data['total_pages'] ?? 1;
      _isLoading = false;
    });
  }

  Future<void> _handleDelete(Map<String, dynamic> comment) async {
    final id = comment['comment_id']?.toString() ?? '';
    final ok = await AdminService.deleteComment(id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'Đã xoá bình luận.' : 'Thao tác thất bại.'),
        backgroundColor: ok ? Colors.orange : Colors.red,
      ),
    );
    if (ok) _load(page: _page);
  }

  Future<void> _handleIgnore(Map<String, dynamic> comment) async {
    final id = comment['comment_id']?.toString() ?? '';
    final ok = await AdminService.ignoreReports(id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content:
            Text(ok ? 'Đã bỏ qua báo cáo.' : 'Thao tác thất bại.'),
        backgroundColor: ok ? Colors.green : Colors.red,
      ),
    );
    if (ok) _load(page: _page);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Filter chips ──
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _filterChip('Tất cả', null),
                const SizedBox(width: 6),
                _filterChip('Chờ xử lý', 'pending'),
                const SizedBox(width: 6),
                _filterChip('Đã giải quyết', 'resolved'),
                const SizedBox(width: 6),
                _filterChip('Đã bỏ qua', 'ignored'),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          child: Row(
            children: [
              Text(
                'Tổng: $_total báo cáo',
                style:
                    const TextStyle(color: Colors.white54, fontSize: 12),
              ),
              const Spacer(),
              Text(
                'Trang $_page / $_totalPages',
                style:
                    const TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
          ),
        ),
        Expanded(
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: _kOrange))
              : _comments.isEmpty
                  ? const Center(
                      child: Text('Không có báo cáo nào.',
                          style: TextStyle(color: Colors.white38)))
                  : RefreshIndicator(
                      onRefresh: () => _load(page: _page),
                      color: _kOrange,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                        itemCount: _comments.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 6),
                        itemBuilder: (_, i) =>
                            _commentTile(_comments[i]),
                      ),
                    ),
        ),
        if (_totalPages > 1)
          Container(
            color: _kCard,
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon:
                      const Icon(Icons.chevron_left, color: Colors.white),
                  onPressed: _page > 1 ? () => _load(page: _page - 1) : null,
                ),
                Text('$_page / $_totalPages',
                    style: const TextStyle(color: Colors.white)),
                IconButton(
                  icon:
                      const Icon(Icons.chevron_right, color: Colors.white),
                  onPressed:
                      _page < _totalPages ? () => _load(page: _page + 1) : null,
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _filterChip(String label, String? value) {
    final selected = _filterStatus == value;
    return GestureDetector(
      onTap: () {
        setState(() => _filterStatus = value);
        _load(page: 1);
      },
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? _kOrange : _kCard2,
          borderRadius: BorderRadius.circular(20),
          border: selected
              ? null
              : Border.all(color: Colors.white12),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Colors.white54,
            fontSize: 12,
            fontWeight:
                selected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _commentTile(Map<String, dynamic> comment) {
    final content = comment['content']?.toString() ?? '';
    final username = comment['username']?.toString() ?? '';
    final mangaTitle = comment['manga_title']?.toString() ?? '';
    final reportCount = comment['report_count'] ?? 0;
    final createdAt = comment['created_at']?.toString() ?? '';

    String dateStr = '';
    if (createdAt.isNotEmpty) {
      try {
        final dt = DateTime.parse(createdAt).toLocal();
        dateStr = '${dt.day}/${dt.month}/${dt.year}';
      } catch (_) {}
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _kCard2,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Colors.red.withValues(alpha: 0.25),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Meta row
          Row(
            children: [
              const Icon(Icons.person_outline,
                  color: Colors.white38, size: 14),
              const SizedBox(width: 4),
              Text(username,
                  style: const TextStyle(
                      color: _kOrange, fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(width: 8),
              const Icon(Icons.menu_book_outlined,
                  color: Colors.white38, size: 14),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  mangaTitle,
                  style: const TextStyle(
                      color: Colors.white54, fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Comment content
          Text(
            content,
            style:
                const TextStyle(color: Colors.white, fontSize: 13),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),

          // Footer row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '🚩 $reportCount báo cáo',
                  style: const TextStyle(
                      color: Colors.redAccent, fontSize: 11),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                dateStr,
                style: const TextStyle(
                    color: Colors.white38, fontSize: 11),
              ),
              const Spacer(),
              // Actions
              TextButton(
                onPressed: () => _handleIgnore(comment),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'Bỏ qua',
                  style: TextStyle(
                      color: Colors.white54, fontSize: 12),
                ),
              ),
              const SizedBox(width: 4),
              TextButton(
                onPressed: () => _handleDelete(comment),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  backgroundColor:
                      Colors.red.withValues(alpha: 0.15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                child: const Text(
                  'Xoá',
                  style: TextStyle(
                      color: Colors.red,
                      fontSize: 12,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
