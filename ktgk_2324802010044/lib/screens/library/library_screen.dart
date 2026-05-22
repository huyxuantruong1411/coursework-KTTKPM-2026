import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../../services/list_service.dart';
import 'list_detail_screen.dart';

const _kOrange = Color(0xFFFF6740);
const _kCard = Color(0xFF2C2C2C);
const _kBg = Color(0xFF000000);

enum _LibViewMode { list, grid }

enum _LibSortMode { nameAsc, nameDesc, newest, oldest }

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});
  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();
  final _publicSearchController = TextEditingController();
  String _searchQuery = '';
  String _publicSearchQuery = '';
  _LibViewMode _viewMode = _LibViewMode.list;
  _LibSortMode _sortMode = _LibSortMode.newest;
  bool _showCoverPreview = true;
  // Cache covers: listId -> coverUrl
  final Map<String, String?> _coverCache = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<AppProvider>().fetchLists().then((_) => _loadCovers());
        _loadPublicLists();
      }
    });
  }

  List<Map<String, dynamic>> _publicLists = [];
  bool _isLoadingPublic = false;
  int _publicPage = 1;
  int _publicTotalPages = 1;

  Future<void> _loadPublicLists({int page = 1, bool append = false}) async {
    setState(() => _isLoadingPublic = true);
    try {
      final res = await ListService.getPublicLists(
        page: page,
        limit: 12,
        query: _publicSearchQuery,
      );
      if (mounted) {
        final items = ((res['items'] ?? []) as List)
            .cast<Map<String, dynamic>>()
            .map(
              (item) => <String, dynamic>{
                'id':
                    item['ListId']?.toString() ??
                    item['list_id']?.toString() ??
                    '',
                'name': item['Name'] ?? item['name'] ?? '',
                'description': item['Description'] ?? item['description'] ?? '',
                'item_count': item['ItemCount'] ?? item['item_count'] ?? 0,
                'follower_count':
                    item['FollowerCount'] ?? item['follower_count'] ?? 0,
                'owner_username':
                    item['owner_username'] ??
                    item['owner']?['username'] ??
                    'áº¨n danh',
                'owner_id':
                    item['owner_id']?.toString() ??
                    item['OwnerId']?.toString() ??
                    '',
                'cover_url': item['cover_url'] ?? item['CoverUrl'],
                'is_following': item['is_following'] ?? false,
                'updated_at': item['UpdatedAt'] ?? item['updated_at'],
              },
            )
            .where((item) => item['id'].toString().isNotEmpty)
            .toList();
        setState(() {
          _publicLists = append ? [..._publicLists, ...items] : items;
          _publicPage = page;
          _publicTotalPages = res['total_pages'] is int
              ? res['total_pages'] as int
              : int.tryParse((res['total_pages'] ?? '1').toString()) ?? 1;
          _isLoadingPublic = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingPublic = false);
    }
  }

  Future<void> _loadCovers() async {
    final provider = context.read<AppProvider>();
    for (final lst in provider.customLists) {
      final id = lst['id'].toString();
      if (!_coverCache.containsKey(id)) {
        final url = await provider.fetchListCover(id);
        if (mounted) setState(() => _coverCache[id] = url);
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _publicSearchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _applyFilter(List<Map<String, dynamic>> lists) {
    var result = lists.where((l) {
      return l['name'].toString().toLowerCase().contains(
        _searchQuery.toLowerCase(),
      );
    }).toList();

    switch (_sortMode) {
      case _LibSortMode.nameAsc:
        result.sort(
          (a, b) => a['name'].toString().compareTo(b['name'].toString()),
        );
        break;
      case _LibSortMode.nameDesc:
        result.sort(
          (a, b) => b['name'].toString().compareTo(a['name'].toString()),
        );
        break;
      case _LibSortMode.newest:
        result.sort(
          (a, b) => (b['created_at'] ?? '').toString().compareTo(
            (a['created_at'] ?? '').toString(),
          ),
        );
        break;
      case _LibSortMode.oldest:
        result.sort(
          (a, b) => (a['created_at'] ?? '').toString().compareTo(
            (b['created_at'] ?? '').toString(),
          ),
        );
        break;
    }
    return result;
  }

  void _showListDialog({
    String? currentId,
    String? currentName,
    String? currentVisibility,
    String? currentDescription,
  }) {
    final ctrl = TextEditingController(text: currentName ?? '');
    final descCtrl = TextEditingController(text: currentDescription ?? '');
    String visibility = currentVisibility ?? 'private';
    final isEdit = currentId != null;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setDialog) => AlertDialog(
          backgroundColor: _kCard,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: Text(
            isEdit ? 'Đổi tên danh sách' : 'Tạo danh sách mới',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: ctrl,
                  autofocus: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    hintText: 'Nhập tên danh sách...',
                  ),
                  onSubmitted: (_) => _submitListDialog(
                    ctx,
                    ctrl,
                    descCtrl,
                    visibility,
                    isEdit,
                    currentId,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descCtrl,
                  maxLines: 2,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    hintText: 'Mo ta (tuy chon)',
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Quyen truy cap',
                  style: TextStyle(color: Colors.white54, fontSize: 13),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _VisibilityOption(
                      label: 'Rieng tu',
                      icon: Icons.lock_outline,
                      isSelected: visibility == 'private',
                      onTap: () => setDialog(() => visibility = 'private'),
                    ),
                    const SizedBox(width: 10),
                    _VisibilityOption(
                      label: 'Cong khai',
                      icon: Icons.public,
                      isSelected: visibility == 'public',
                      onTap: () => setDialog(() => visibility = 'public'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Hủy', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              onPressed: () => _submitListDialog(
                ctx,
                ctrl,
                descCtrl,
                visibility,
                isEdit,
                currentId,
              ),
              child: Text(isEdit ? 'Lưu' : 'Tạo'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitListDialog(
    BuildContext ctx,
    TextEditingController ctrl,
    TextEditingController descCtrl,
    String visibility,
    bool isEdit,
    String? currentId,
  ) async {
    final name = ctrl.text.trim();
    final description = descCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Tên không được để trống!')));
      return;
    }
    final provider = context.read<AppProvider>();
    final isDuplicate = provider.customLists.any(
      (l) =>
          l['name'].toString().toLowerCase() == name.toLowerCase() &&
          l['id'] != currentId,
    );
    if (isDuplicate) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tên danh sách đã tồn tại!'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    try {
      if (isEdit) {
        await ListService.updateList(
          currentId!,
          name: name,
          description: description,
          visibility: visibility,
        );
        await provider.fetchLists();
      } else {
        await provider.createList(
          name,
          description: description,
          visibility: visibility,
        );
        _loadCovers();
      }
      if (!ctx.mounted) return;
      Navigator.pop(ctx);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isEdit ? 'Đổi tên thành công!' : 'Đã tạo danh sách!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _confirmDeleteList(
    BuildContext context,
    String listId,
    String listName,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _kCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text(
          'Xóa danh sách?',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Danh sách "$listName" và tất cả manga bên trong sẽ bị xóa vĩnh viễn.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await context.read<AppProvider>().deleteList(listId);
              _coverCache.remove(listId);
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
            },
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
  }

  void _showSortMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _kCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Sắp xếp & Hiển thị',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          const Divider(color: Colors.white12),
          ..._LibSortMode.values.map((mode) {
            final labels = {
              _LibSortMode.nameAsc: 'Tên A → Z',
              _LibSortMode.nameDesc: 'Tên Z → A',
              _LibSortMode.newest: 'Mới nhất',
              _LibSortMode.oldest: 'Cũ nhất',
            };
            return ListTile(
              leading: Icon(
                _sortMode == mode
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off,
                color: _sortMode == mode ? _kOrange : Colors.white38,
              ),
              title: Text(
                labels[mode]!,
                style: const TextStyle(color: Colors.white),
              ),
              onTap: () {
                setState(() => _sortMode = mode);
                Navigator.pop(ctx);
              },
            );
          }),
          const Divider(color: Colors.white12),
          SwitchListTile(
            value: _showCoverPreview,
            activeThumbColor: _kOrange,
            title: const Text(
              'Hiển thị cover manga đầu tiên',
              style: TextStyle(color: Colors.white),
            ),
            onChanged: (val) => setState(() => _showCoverPreview = val),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  void _showPublicSearchDialog() {
    _publicSearchController.text = _publicSearchQuery;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _kCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text(
          'Tim list cong dong',
          style: TextStyle(color: Colors.white),
        ),
        content: TextField(
          controller: _publicSearchController,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Ten list hoac mo ta...',
            prefixIcon: Icon(Icons.search, color: Colors.white38),
          ),
          onSubmitted: (_) {
            Navigator.pop(ctx);
            setState(
              () => _publicSearchQuery = _publicSearchController.text.trim(),
            );
            _loadPublicLists();
          },
        ),
        actions: [
          if (_publicSearchQuery.isNotEmpty)
            TextButton(
              onPressed: () {
                _publicSearchController.clear();
                Navigator.pop(ctx);
                setState(() => _publicSearchQuery = '');
                _loadPublicLists();
              },
              child: const Text(
                'Xoa loc',
                style: TextStyle(color: Colors.white54),
              ),
            ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(
                () => _publicSearchQuery = _publicSearchController.text.trim(),
              );
              _loadPublicLists();
            },
            style: ElevatedButton.styleFrom(backgroundColor: _kOrange),
            child: const Text('Tim', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lists = context.watch<AppProvider>().customLists;
    final filtered = _applyFilter(lists);

    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kBg,
        title: const Text(
          'Thư viện',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        actions: [
          // Toggle view mode
          IconButton(
            icon: Icon(
              _viewMode == _LibViewMode.list
                  ? Icons.grid_view_rounded
                  : Icons.view_list_rounded,
              color: Colors.white70,
            ),
            tooltip: _viewMode == _LibViewMode.list
                ? 'Chuyển sang lưới'
                : 'Chuyển sang danh sách',
            onPressed: () => setState(() {
              _viewMode = _viewMode == _LibViewMode.list
                  ? _LibViewMode.grid
                  : _LibViewMode.list;
            }),
          ),
          // Sort menu
          IconButton(
            icon: const Icon(Icons.sort_rounded, color: Colors.white70),
            tooltip: 'Sắp xếp & Cài đặt',
            onPressed: _showSortMenu,
          ),
          IconButton(
            icon: Icon(
              Icons.public,
              color: _publicSearchQuery.isNotEmpty ? _kOrange : Colors.white70,
            ),
            tooltip: 'Tim list cong dong',
            onPressed: _showPublicSearchDialog,
          ),
          const SizedBox(width: 4),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: _kOrange,
          labelColor: _kOrange,
          unselectedLabelColor: Colors.white54,
          tabs: const [
            Tab(text: 'Của tôi'),
            Tab(text: 'Cộng đồng'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _kOrange,
        onPressed: _showListDialog,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'Danh sách mới',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: Của tôi
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: TextField(
                  controller: _searchController,
                  onChanged: (v) => setState(() => _searchQuery = v),
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Tìm danh sách...',
                    hintStyle: const TextStyle(color: Colors.white38),
                    prefixIcon: const Icon(
                      Icons.search,
                      color: Colors.white38,
                      size: 20,
                    ),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(
                              Icons.clear,
                              color: Colors.white38,
                              size: 18,
                            ),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  ),
                ),
              ),
              Expanded(
                child: filtered.isEmpty
                    ? _buildEmptyState()
                    : _viewMode == _LibViewMode.list
                    ? _buildListView(filtered)
                    : _buildGridView(filtered),
              ),
            ],
          ),
          // Tab 2: Cộng đồng
          _isLoadingPublic
              ? const Center(child: CircularProgressIndicator(color: _kOrange))
              : _publicLists.isEmpty
              ? const Center(
                  child: Text(
                    'Chưa có danh sách cộng đồng nào.',
                    style: TextStyle(color: Colors.white54),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () => _loadPublicLists(),
                  color: _kOrange,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount:
                        _publicLists.length +
                        (_publicPage < _publicTotalPages ? 1 : 0),
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 8),
                    itemBuilder: (ctx, i) {
                      if (i >= _publicLists.length) {
                        return Center(
                          child: TextButton(
                            onPressed: _isLoadingPublic
                                ? null
                                : () => _loadPublicLists(
                                    page: _publicPage + 1,
                                    append: true,
                                  ),
                            child: const Text(
                              'Tai them',
                              style: TextStyle(color: _kOrange),
                            ),
                          ),
                        );
                      }
                      final lst = _publicLists[i];
                      return ListTile(
                        tileColor: _kCard,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        title: Text(
                          lst['name'] ?? '',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Text(
                          '${lst['item_count'] ?? 0} truyện • Tạo bởi ${lst['owner_username'] ?? 'Ẩn danh'}',
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 12,
                          ),
                        ),
                        trailing: _FollowListButton(
                          isFollowing: lst['is_following'] == true,
                          onTap: () => _toggleFollowPublicList(lst),
                        ),
                        onTap: () => _navigateToDetail(lst),
                      );
                    },
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.collections_bookmark_outlined,
            size: 72,
            color: Colors.white12,
          ),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isEmpty
                ? 'Thư viện trống'
                : 'Không tìm thấy danh sách',
            style: const TextStyle(color: Colors.white38, fontSize: 16),
          ),
          if (_searchQuery.isEmpty) ...[
            const SizedBox(height: 8),
            const Text(
              'Tạo danh sách đầu tiên để lưu manga yêu thích!',
              style: TextStyle(color: Colors.white24, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildListView(List<Map<String, dynamic>> lists) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
      itemCount: lists.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (ctx, i) => _ListCard(
        lst: lists[i],
        coverUrl: _showCoverPreview
            ? _coverCache[lists[i]['id'].toString()]
            : null,
        showCoverPreview: _showCoverPreview,
        onEdit: () => _showListDialog(
          currentId: lists[i]['id'],
          currentName: lists[i]['name'],
          currentVisibility: lists[i]['visibility'] ?? 'private',
          currentDescription: lists[i]['description'],
        ),
        onDelete: () =>
            _confirmDeleteList(ctx, lists[i]['id'], lists[i]['name']),
        onTap: () => _navigateToDetail(lists[i]),
      ),
    );
  }

  Widget _buildGridView(List<Map<String, dynamic>> lists) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.8,
      ),
      itemCount: lists.length,
      itemBuilder: (ctx, i) => _GridListCard(
        lst: lists[i],
        coverUrl: _showCoverPreview
            ? _coverCache[lists[i]['id'].toString()]
            : null,
        onEdit: () => _showListDialog(
          currentId: lists[i]['id'],
          currentName: lists[i]['name'],
          currentVisibility: lists[i]['visibility'] ?? 'private',
          currentDescription: lists[i]['description'],
        ),
        onDelete: () =>
            _confirmDeleteList(ctx, lists[i]['id'], lists[i]['name']),
        onTap: () => _navigateToDetail(lists[i]),
      ),
    );
  }

  Future<void> _toggleFollowPublicList(Map<String, dynamic> lst) async {
    final listId = lst['id']?.toString() ?? '';
    if (listId.isEmpty) return;
    final isFollowing = lst['is_following'] == true;
    try {
      if (isFollowing) {
        await ListService.unfollowList(listId);
      } else {
        await ListService.followList(listId);
      }
      if (!mounted) return;
      setState(() {
        lst['is_following'] = !isFollowing;
        final count =
            int.tryParse((lst['follower_count'] ?? 0).toString()) ?? 0;
        lst['follower_count'] = isFollowing
            ? (count - 1).clamp(0, 1 << 31)
            : count + 1;
      });
      await context.read<AppProvider>().fetchLists();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Loi: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _navigateToDetail(Map<String, dynamic> lst) {
    final isOwner = context.read<AppProvider>().customLists.any(
      (myList) => myList['id'].toString() == lst['id'].toString(),
    );
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ListDetailScreen(
          listId: lst['id'],
          listName: lst['name'],
          isOwner: isOwner,
        ),
      ),
    ).then((_) {
      if (mounted) {
        context.read<AppProvider>().fetchLists().then((_) => _loadCovers());
      }
    });
  }
}

class _VisibilityOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _VisibilityOption({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? _kOrange.withValues(alpha: 0.15)
                : const Color(0xFF3A3A3A),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isSelected ? _kOrange : Colors.white24),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: isSelected ? _kOrange : Colors.white54,
                size: 20,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? _kOrange : Colors.white54,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VisibilityBadge extends StatelessWidget {
  final String visibility;
  const _VisibilityBadge({required this.visibility});

  @override
  Widget build(BuildContext context) {
    final isPublic = visibility == 'public';
    final color = isPublic ? Colors.green : Colors.white38;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Text(
        isPublic ? 'Public' : 'Private',
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _FollowListButton extends StatelessWidget {
  final bool isFollowing;
  final VoidCallback onTap;

  const _FollowListButton({required this.isFollowing, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isFollowing ? _kOrange.withValues(alpha: 0.12) : _kOrange,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: _kOrange),
        ),
        child: Text(
          isFollowing ? 'Dang theo' : 'Theo doi',
          style: TextStyle(
            color: isFollowing ? _kOrange : Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

// ---------- List Card ----------
class _ListCard extends StatelessWidget {
  final Map<String, dynamic> lst;
  final String? coverUrl;
  final bool showCoverPreview;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onTap;

  const _ListCard({
    required this.lst,
    required this.coverUrl,
    required this.showCoverPreview,
    required this.onEdit,
    required this.onDelete,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: _kCard,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Row(
          children: [
            // Cover or Folder
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                bottomLeft: Radius.circular(8),
              ),
              child: SizedBox(
                width: 68,
                height: 80,
                child: showCoverPreview && coverUrl != null
                    ? CachedNetworkImage(
                        imageUrl: coverUrl!,
                        fit: BoxFit.cover,
                        errorWidget: (_, _, _) => _folderIcon(),
                      )
                    : _folderIcon(),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lst['name'],
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _VisibilityBadge(
                          visibility: lst['visibility'] ?? 'private',
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _formatDate(lst['created_at']),
                          style: const TextStyle(
                            color: Colors.white38,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            // Actions
            PopupMenuButton<String>(
              icon: const Icon(
                Icons.more_vert,
                color: Colors.white38,
                size: 20,
              ),
              color: const Color(0xFF3A3A3A),
              onSelected: (val) {
                if (val == 'edit') onEdit();
                if (val == 'delete') onDelete();
              },
              itemBuilder: (ctx) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(
                        Icons.edit_outlined,
                        color: Colors.white70,
                        size: 18,
                      ),
                      SizedBox(width: 8),
                      Text('Đổi tên', style: TextStyle(color: Colors.white)),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(
                        Icons.delete_outline,
                        color: Colors.redAccent,
                        size: 18,
                      ),
                      SizedBox(width: 8),
                      Text('Xóa', style: TextStyle(color: Colors.redAccent)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _folderIcon() {
    return Container(
      color: const Color(0xFF3A3A3A),
      child: const Icon(Icons.folder_rounded, color: _kOrange, size: 32),
    );
  }

  String _formatDate(dynamic createdAt) {
    if (createdAt == null) return '';
    try {
      final dt = DateTime.parse(createdAt.toString()).toLocal();
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return '';
    }
  }
}

// ---------- Grid List Card ----------
class _GridListCard extends StatelessWidget {
  final Map<String, dynamic> lst;
  final String? coverUrl;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onTap;

  const _GridListCard({
    required this.lst,
    required this.coverUrl,
    required this.onEdit,
    required this.onDelete,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: _kCard,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: coverUrl != null
                  ? CachedNetworkImage(
                      imageUrl: coverUrl!,
                      fit: BoxFit.cover,
                      errorWidget: (_, _, _) => _folderFallback(),
                    )
                  : _folderFallback(),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 4, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      lst['name'],
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(
                      Icons.more_vert,
                      color: Colors.white38,
                      size: 18,
                    ),
                    color: const Color(0xFF3A3A3A),
                    padding: EdgeInsets.zero,
                    onSelected: (val) {
                      if (val == 'edit') onEdit();
                      if (val == 'delete') onDelete();
                    },
                    itemBuilder: (ctx) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Text(
                          'Đổi tên',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text(
                          'Xóa',
                          style: TextStyle(color: Colors.redAccent),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _folderFallback() {
    return Container(
      color: const Color(0xFF3A3A3A),
      child: const Center(
        child: Icon(Icons.folder_rounded, color: _kOrange, size: 48),
      ),
    );
  }
}
