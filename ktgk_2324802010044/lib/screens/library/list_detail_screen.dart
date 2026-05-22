import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../../models/manga.dart';
import '../detail/detail_screen.dart';

const _kOrange = Color(0xFFFF6740);
const _kCard = Color(0xFF2C2C2C);
const _kBg = Color(0xFF000000);

enum _ViewMode { compact, detailed, grid }

enum _SortMode { titleAsc, titleDesc, newest, oldest, statusAsc }

enum _CoverSize { small, medium, large }

const _statusAll = 'Tất cả';
const _statusList = [_statusAll, 'Reading', 'Completed', 'Dropped'];

class ListDetailScreen extends StatefulWidget {
  final String listId;
  final String listName;
  final bool isOwner;
  const ListDetailScreen({
    super.key,
    required this.listId,
    required this.listName,
    this.isOwner = true,
  });
  @override
  State<ListDetailScreen> createState() => _ListDetailScreenState();
}

class _ListDetailScreenState extends State<ListDetailScreen> {
  List<Map<String, dynamic>> _allItems = [];
  bool _loading = true;

  // Filters & sort
  String _searchQuery = '';
  String _statusFilter = _statusAll;
  _SortMode _sortMode = _SortMode.newest;
  final Set<String> _tagFilter = {};

  // View config
  _ViewMode _viewMode = _ViewMode.detailed;
  _CoverSize _coverSize = _CoverSize.medium;

  // Multi-select
  bool _selectionMode = false;
  final Set<String> _selectedIds = {};

  final _searchController = TextEditingController();

  bool get _canEdit => widget.isOwner;

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadItems() async {
    if (!mounted) return;
    setState(() => _loading = true);
    final data = await context.read<AppProvider>().fetchItemsInList(
      widget.listId,
    );
    if (mounted) {
      setState(() {
        _allItems = data;
        _loading = false;
      });
    }
  }

  // ===================== DATA PROCESSING =====================
  List<String> get _allTags {
    final tags = <String>{};
    for (final item in _allItems) {
      final genres = item['genres'];
      if (genres is List) {
        for (final g in genres) {
          tags.add(g.toString());
        }
      }
    }
    return tags.toList()..sort();
  }

  List<Map<String, dynamic>> get _filteredItems {
    var list = _allItems.where((item) {
      // Status filter
      if (_statusFilter != _statusAll && item['status'] != _statusFilter) {
        return false;
      }
      // Search
      if (_searchQuery.isNotEmpty &&
          !item['title'].toString().toLowerCase().contains(
            _searchQuery.toLowerCase(),
          )) {
        return false;
      }
      // Tag filter
      if (_tagFilter.isNotEmpty) {
        final genres = item['genres'];
        if (genres is! List) return false;
        final genreSet = genres.map((g) => g.toString()).toSet();
        if (!_tagFilter.any((t) => genreSet.contains(t))) return false;
      }
      return true;
    }).toList();

    // Sort
    switch (_sortMode) {
      case _SortMode.titleAsc:
        list.sort(
          (a, b) => a['title'].toString().compareTo(b['title'].toString()),
        );
        break;
      case _SortMode.titleDesc:
        list.sort(
          (a, b) => b['title'].toString().compareTo(a['title'].toString()),
        );
        break;
      case _SortMode.newest:
        list.sort(
          (a, b) => (b['created_at'] ?? '').toString().compareTo(
            (a['created_at'] ?? '').toString(),
          ),
        );
        break;
      case _SortMode.oldest:
        list.sort(
          (a, b) => (a['created_at'] ?? '').toString().compareTo(
            (b['created_at'] ?? '').toString(),
          ),
        );
        break;
      case _SortMode.statusAsc:
        list.sort(
          (a, b) => (a['status'] ?? '').toString().compareTo(
            (b['status'] ?? '').toString(),
          ),
        );
        break;
    }

    return list;
  }

  // ===================== ACTIONS =====================
  Future<void> _deleteItem(String itemId) async {
    if (!_canEdit) return;
    await context.read<AppProvider>().removeMangaFromList(itemId);
    await _loadItems();
  }

  Future<void> _bulkDelete() async {
    if (!_canEdit) return;
    if (_selectedIds.isEmpty) return;
    final count = _selectedIds.length;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _kCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Xóa manga?', style: TextStyle(color: Colors.white)),
        content: Text(
          'Xóa $count manga đã chọn khỏi danh sách?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    if (!mounted) return;
    await context.read<AppProvider>().bulkRemoveMangaFromList(
      _selectedIds.toList(),
    );
    setState(() {
      _selectedIds.clear();
      _selectionMode = false;
    });
    await _loadItems();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Đã xóa $count manga.'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showImportDialog() async {
    if (!_canEdit) return;
    final provider = context.read<AppProvider>();
    await provider.fetchLists();
    final otherLists = provider.customLists
        .where((l) => l['id'].toString() != widget.listId)
        .toList();

    if (!mounted) return;

    if (otherLists.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không có danh sách nào khác để import.')),
      );
      return;
    }

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
              'Import từ danh sách khác',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Text(
              'Manga trùng lặp sẽ tự động bỏ qua.',
              style: TextStyle(color: Colors.white38, fontSize: 12),
            ),
          ),
          const Divider(color: Colors.white12),
          ...otherLists.map(
            (lst) => ListTile(
              leading: const Icon(Icons.folder_rounded, color: _kOrange),
              title: Text(
                lst['name'],
                style: const TextStyle(color: Colors.white),
              ),
              onTap: () async {
                Navigator.pop(ctx);
                _performImport(lst['id'].toString(), lst['name'].toString());
              },
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Future<void> _performImport(String sourceListId, String sourceName) async {
    if (!_canEdit) return;
    final snack = ScaffoldMessenger.of(context);
    snack.showSnackBar(
      SnackBar(content: Text('Đang import từ "$sourceName"...')),
    );

    final (imported, skipped) = await context
        .read<AppProvider>()
        .importMangaFromList(sourceListId, widget.listId);

    await _loadItems();
    if (!mounted) return;

    snack.hideCurrentSnackBar();
    snack.showSnackBar(
      SnackBar(
        content: Text(
          'Import xong! Thêm: $imported | Bỏ qua (trùng): $skipped',
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _showStatusDialog(String itemId, String currentStatus) {
    if (!_canEdit) return;
    String selected = currentStatus;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setModalState) => AlertDialog(
          backgroundColor: _kCard,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: const Text(
            'Trạng thái đọc',
            style: TextStyle(color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: ['Reading', 'Completed', 'Dropped'].map((s) {
              final isActive = selected == s;
              return ListTile(
                leading: Icon(
                  isActive
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  color: isActive ? _kOrange : Colors.white38,
                ),
                title: Text(s, style: const TextStyle(color: Colors.white)),
                onTap: () => setModalState(() => selected = s),
              );
            }).toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Hủy', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              onPressed: () async {
                await context.read<AppProvider>().updateMangaStatus(
                  itemId,
                  selected,
                );
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                await _loadItems();
              },
              child: const Text('Lưu'),
            ),
          ],
        ),
      ),
    );
  }

  void _showConfigSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _kCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setSheet) => SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  'Cài đặt hiển thị',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              const Divider(color: Colors.white12),

              // View mode
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Text(
                  'Chế độ hiển thị',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _ViewModeButton(
                    icon: Icons.view_agenda_outlined,
                    label: 'Chi tiết',
                    selected: _viewMode == _ViewMode.detailed,
                    onTap: () {
                      setState(() => _viewMode = _ViewMode.detailed);
                      setSheet(() {});
                    },
                  ),
                  _ViewModeButton(
                    icon: Icons.view_list_rounded,
                    label: 'Nhỏ gọn',
                    selected: _viewMode == _ViewMode.compact,
                    onTap: () {
                      setState(() => _viewMode = _ViewMode.compact);
                      setSheet(() {});
                    },
                  ),
                  _ViewModeButton(
                    icon: Icons.grid_view_rounded,
                    label: 'Lưới',
                    selected: _viewMode == _ViewMode.grid,
                    onTap: () {
                      setState(() => _viewMode = _ViewMode.grid);
                      setSheet(() {});
                    },
                  ),
                ],
              ),

              // Cover size (only relevant for non-grid modes)
              if (_viewMode != _ViewMode.grid) ...[
                const Divider(color: Colors.white12),
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: Text(
                    'Kích thước cover',
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _CoverSizeButton(
                      label: 'Nhỏ',
                      size: _CoverSize.small,
                      selected: _coverSize == _CoverSize.small,
                      onTap: () {
                        setState(() => _coverSize = _CoverSize.small);
                        setSheet(() {});
                      },
                    ),
                    _CoverSizeButton(
                      label: 'Cân bằng',
                      size: _CoverSize.medium,
                      selected: _coverSize == _CoverSize.medium,
                      onTap: () {
                        setState(() => _coverSize = _CoverSize.medium);
                        setSheet(() {});
                      },
                    ),
                    _CoverSizeButton(
                      label: 'Lớn',
                      size: _CoverSize.large,
                      selected: _coverSize == _CoverSize.large,
                      onTap: () {
                        setState(() => _coverSize = _CoverSize.large);
                        setSheet(() {});
                      },
                    ),
                  ],
                ),
              ],

              // Sort
              const Divider(color: Colors.white12),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Text(
                  'Sắp xếp',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ),
              ...[
                (_SortMode.newest, 'Mới thêm trước'),
                (_SortMode.oldest, 'Cũ thêm trước'),
                (_SortMode.titleAsc, 'Tiêu đề A → Z'),
                (_SortMode.titleDesc, 'Tiêu đề Z → A'),
                (_SortMode.statusAsc, 'Theo trạng thái'),
              ].map((pair) {
                final isActive = _sortMode == pair.$1;
                return ListTile(
                  leading: Icon(
                    isActive
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                    color: isActive ? _kOrange : Colors.white38,
                    size: 20,
                  ),
                  dense: true,
                  title: Text(
                    pair.$2,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                  onTap: () {
                    setState(() => _sortMode = pair.$1);
                    setSheet(() {});
                  },
                );
              }),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  void _showTagFilterSheet() {
    final allTags = _allTags;
    if (allTags.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không có thể loại nào để lọc.')),
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      backgroundColor: _kCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setSheet) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Lọc theo thể loại',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  if (_tagFilter.isNotEmpty)
                    TextButton(
                      onPressed: () {
                        setState(() => _tagFilter.clear());
                        setSheet(() {});
                      },
                      child: const Text(
                        'Xóa hết',
                        style: TextStyle(color: _kOrange),
                      ),
                    ),
                ],
              ),
            ),
            const Divider(color: Colors.white12),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: allTags.map((tag) {
                    final selected = _tagFilter.contains(tag);
                    return FilterChip(
                      label: Text(tag),
                      selected: selected,
                      selectedColor: _kOrange,
                      backgroundColor: const Color(0xFF3A3A3A),
                      labelStyle: TextStyle(
                        color: selected ? Colors.white : Colors.white70,
                        fontSize: 12,
                      ),
                      checkmarkColor: Colors.white,
                      onSelected: (v) {
                        setState(() {
                          if (v) {
                            _tagFilter.add(tag);
                          } else {
                            _tagFilter.remove(tag);
                          }
                        });
                        setSheet(() {});
                      },
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===================== BUILD =====================
  @override
  Widget build(BuildContext context) {
    final filtered = _filteredItems;
    final hasActive =
        _tagFilter.isNotEmpty ||
        _statusFilter != _statusAll ||
        _searchQuery.isNotEmpty;

    return Scaffold(
      backgroundColor: _kBg,
      appBar: _selectionMode && _canEdit
          ? _buildSelectionAppBar()
          : _buildNormalAppBar(hasActive),
      body: Column(
        children: [
          // Status filter bar
          _buildStatusBar(),
          // Tag filter active chips
          if (_tagFilter.isNotEmpty) _buildActiveTagChips(),
          // Content
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: _kOrange),
                  )
                : filtered.isEmpty
                ? _buildEmptyState()
                : _buildContent(filtered),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildNormalAppBar(bool hasFilter) {
    return AppBar(
      backgroundColor: _kBg,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.listName,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontSize: 17,
            ),
          ),
          Text(
            '${_allItems.length} manga',
            style: const TextStyle(color: Colors.white38, fontSize: 12),
          ),
        ],
      ),
      actions: [
        // Search
        IconButton(
          icon: Icon(
            Icons.search,
            color: _searchQuery.isNotEmpty ? _kOrange : Colors.white70,
          ),
          onPressed: _showSearchBar,
        ),
        // Tag filter
        IconButton(
          icon: Icon(
            Icons.label_outline,
            color: _tagFilter.isNotEmpty ? _kOrange : Colors.white70,
          ),
          onPressed: _showTagFilterSheet,
          tooltip: 'Lọc theo thể loại',
        ),
        // Import
        if (_canEdit)
          IconButton(
            icon: const Icon(Icons.download_outlined, color: Colors.white70),
            onPressed: _showImportDialog,
            tooltip: 'Import từ danh sách khác',
          ),
        // Config
        IconButton(
          icon: const Icon(Icons.tune_rounded, color: Colors.white70),
          onPressed: _showConfigSheet,
          tooltip: 'Cài đặt hiển thị',
        ),
        // Multi select
        if (_canEdit)
          IconButton(
            icon: const Icon(Icons.checklist_rounded, color: Colors.white70),
            onPressed: () => setState(() {
              _selectionMode = true;
              _selectedIds.clear();
            }),
            tooltip: 'Chọn nhiều',
          ),
      ],
    );
  }

  PreferredSizeWidget _buildSelectionAppBar() {
    final count = _selectedIds.length;
    final filtered = _filteredItems;
    return AppBar(
      backgroundColor: const Color(0xFF1A1A1A),
      leading: IconButton(
        icon: const Icon(Icons.close, color: Colors.white),
        onPressed: () => setState(() {
          _selectionMode = false;
          _selectedIds.clear();
        }),
      ),
      title: Text(
        count == 0 ? 'Chọn manga' : 'Đã chọn $count',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
      actions: [
        // Select all
        TextButton.icon(
          onPressed: () => setState(() {
            if (_selectedIds.length == filtered.length) {
              _selectedIds.clear();
            } else {
              _selectedIds.addAll(filtered.map((e) => e['id'].toString()));
            }
          }),
          icon: Icon(
            _selectedIds.length == filtered.length
                ? Icons.deselect
                : Icons.select_all,
            color: _kOrange,
            size: 18,
          ),
          label: Text(
            _selectedIds.length == filtered.length ? 'Bỏ chọn' : 'Chọn hết',
            style: const TextStyle(color: _kOrange),
          ),
        ),
        // Delete selected
        if (count > 0)
          IconButton(
            icon: const Icon(Icons.delete_rounded, color: Colors.redAccent),
            onPressed: _bulkDelete,
            tooltip: 'Xóa đã chọn',
          ),
      ],
    );
  }

  Widget _buildStatusBar() {
    return Container(
      color: _kBg,
      height: 42,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        children: _statusList.map((s) {
          final isSelected = _statusFilter == s;
          // Count per status
          final c = s == _statusAll
              ? _allItems.length
              : _allItems.where((i) => i['status'] == s).length;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => setState(() => _statusFilter = s),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: isSelected ? _kOrange : _kCard,
                  borderRadius: BorderRadius.circular(9999),
                ),
                child: Center(
                  child: Text(
                    '$s ($c)',
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white54,
                      fontSize: 12,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildActiveTagChips() {
    return Container(
      color: _kBg,
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Wrap(
        spacing: 6,
        runSpacing: 4,
        children: _tagFilter
            .map(
              (tag) => Chip(
                label: Text(
                  tag,
                  style: const TextStyle(color: Colors.white, fontSize: 11),
                ),
                backgroundColor: _kOrange.withValues(alpha: 0.2),
                deleteIconColor: Colors.white54,
                side: BorderSide(color: _kOrange.withValues(alpha: 0.5)),
                onDeleted: () => setState(() => _tagFilter.remove(tag)),
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.book_outlined, size: 64, color: Colors.white12),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isNotEmpty ||
                    _statusFilter != _statusAll ||
                    _tagFilter.isNotEmpty
                ? 'Không có kết quả phù hợp'
                : 'Chưa có manga nào',
            style: const TextStyle(color: Colors.white38, fontSize: 15),
          ),
          if (_searchQuery.isEmpty &&
              _statusFilter == _statusAll &&
              _tagFilter.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Thêm manga từ trang Khám phá!',
                style: TextStyle(color: Colors.white24, fontSize: 13),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildContent(List<Map<String, dynamic>> items) {
    switch (_viewMode) {
      case _ViewMode.grid:
        return _buildGrid(items);
      case _ViewMode.compact:
        return _buildCompact(items);
      case _ViewMode.detailed:
        return _buildDetailed(items);
    }
  }

  // ---------- DETAILED VIEW ----------
  Widget _buildDetailed(List<Map<String, dynamic>> items) {
    final coverW = _coverSize == _CoverSize.small
        ? 56.0
        : _coverSize == _CoverSize.medium
        ? 80.0
        : 110.0;
    final coverH = coverW * 1.42;

    return ListView.separated(
      padding: EdgeInsets.fromLTRB(12, 8, 12, _selectionMode ? 80 : 24),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 6),
      itemBuilder: (ctx, i) {
        final item = items[i];
        final id = item['id'].toString();
        final isSelected = _selectedIds.contains(id);

        return GestureDetector(
          onLongPress: () {
            if (_canEdit && !_selectionMode) {
              setState(() {
                _selectionMode = true;
                _selectedIds.add(id);
              });
            }
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            decoration: BoxDecoration(
              color: isSelected ? _kOrange.withValues(alpha: 0.15) : _kCard,
              borderRadius: BorderRadius.circular(8),
              border: isSelected
                  ? Border.all(color: _kOrange.withValues(alpha: 0.6))
                  : null,
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () {
                if (_selectionMode) {
                  setState(() {
                    isSelected ? _selectedIds.remove(id) : _selectedIds.add(id);
                  });
                } else {
                  _openManga(item);
                }
              },
              child: Row(
                children: [
                  if (_selectionMode)
                    Padding(
                      padding: const EdgeInsets.only(left: 10),
                      child: Checkbox(
                        value: isSelected,
                        activeColor: _kOrange,
                        side: const BorderSide(color: Colors.white38),
                        onChanged: (v) => setState(() {
                          v! ? _selectedIds.add(id) : _selectedIds.remove(id);
                        }),
                      ),
                    ),
                  // Cover
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: CachedNetworkImage(
                        imageUrl: item['cover_url'] ?? '',
                        width: coverW,
                        height: coverH,
                        fit: BoxFit.cover,
                        placeholder: (_, _) => Container(
                          width: coverW,
                          height: coverH,
                          color: Colors.white10,
                        ),
                        errorWidget: (_, _, _) => Container(
                          width: coverW,
                          height: coverH,
                          color: Colors.white10,
                          child: const Icon(
                            Icons.broken_image,
                            color: Colors.white24,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 10,
                        horizontal: 4,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item['title'] ?? '',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              height: 1.3,
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          _StatusChip(status: item['status'] ?? 'Reading'),
                          if (item['genres'] is List &&
                              (item['genres'] as List).isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Wrap(
                                spacing: 4,
                                runSpacing: 3,
                                children: (item['genres'] as List)
                                    .take(3)
                                    .map((g) => _TagPill(label: g.toString()))
                                    .toList(),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  if (_canEdit && !_selectionMode)
                    PopupMenuButton<String>(
                      icon: const Icon(
                        Icons.more_vert,
                        color: Colors.white38,
                        size: 20,
                      ),
                      color: const Color(0xFF3A3A3A),
                      onSelected: (val) {
                        if (val == 'status') {
                          _showStatusDialog(id, item['status'] ?? 'Reading');
                        }
                        if (val == 'delete') _deleteItem(id);
                      },
                      itemBuilder: (ctx) => [
                        const PopupMenuItem(
                          value: 'status',
                          child: Row(
                            children: [
                              Icon(
                                Icons.edit_note,
                                color: Colors.white70,
                                size: 18,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Đổi trạng thái',
                                style: TextStyle(color: Colors.white),
                              ),
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
                              Text(
                                'Xóa khỏi danh sách',
                                style: TextStyle(color: Colors.redAccent),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ---------- COMPACT VIEW ----------
  Widget _buildCompact(List<Map<String, dynamic>> items) {
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(12, 8, 12, _selectionMode ? 80 : 24),
      itemCount: items.length,
      separatorBuilder: (_, _) =>
          const Divider(color: Colors.white10, height: 1),
      itemBuilder: (ctx, i) {
        final item = items[i];
        final id = item['id'].toString();
        final isSelected = _selectedIds.contains(id);

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 4,
            vertical: 0,
          ),
          leading: _selectionMode
              ? Checkbox(
                  value: isSelected,
                  activeColor: _kOrange,
                  side: const BorderSide(color: Colors.white38),
                  onChanged: (v) => setState(() {
                    v! ? _selectedIds.add(id) : _selectedIds.remove(id);
                  }),
                )
              : ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: CachedNetworkImage(
                    imageUrl: item['cover_url'] ?? '',
                    width: 38,
                    height: 54,
                    fit: BoxFit.cover,
                    placeholder: (_, _) =>
                        Container(width: 38, height: 54, color: Colors.white10),
                  ),
                ),
          title: Text(
            item['title'] ?? '',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 3),
            child: _StatusChip(
              status: item['status'] ?? 'Reading',
              small: true,
            ),
          ),
          trailing: !_canEdit || _selectionMode
              ? null
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.edit_note,
                        color: Colors.white38,
                        size: 18,
                      ),
                      onPressed: () =>
                          _showStatusDialog(id, item['status'] ?? 'Reading'),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.delete_outline,
                        color: Colors.white24,
                        size: 18,
                      ),
                      onPressed: () => _deleteItem(id),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                    ),
                  ],
                ),
          onTap: () {
            if (_selectionMode) {
              setState(
                () =>
                    isSelected ? _selectedIds.remove(id) : _selectedIds.add(id),
              );
            } else {
              _openManga(item);
            }
          },
          onLongPress: () {
            if (_canEdit && !_selectionMode) {
              setState(() {
                _selectionMode = true;
                _selectedIds.add(id);
              });
            }
          },
        );
      },
    );
  }

  // ---------- GRID VIEW ----------
  Widget _buildGrid(List<Map<String, dynamic>> items) {
    return GridView.builder(
      padding: EdgeInsets.fromLTRB(12, 8, 12, _selectionMode ? 80 : 24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 0.6,
      ),
      itemCount: items.length,
      itemBuilder: (ctx, i) {
        final item = items[i];
        final id = item['id'].toString();
        final isSelected = _selectedIds.contains(id);

        return GestureDetector(
          onTap: () {
            if (_selectionMode) {
              setState(
                () =>
                    isSelected ? _selectedIds.remove(id) : _selectedIds.add(id),
              );
            } else {
              _openManga(item);
            }
          },
          onLongPress: () {
            if (_canEdit && !_selectionMode) {
              setState(() {
                _selectionMode = true;
                _selectedIds.add(id);
              });
            }
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              border: isSelected
                  ? Border.all(color: _kOrange, width: 2.5)
                  : null,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(isSelected ? 5 : 6),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
                    imageUrl: item['cover_url'] ?? '',
                    fit: BoxFit.cover,
                    placeholder: (_, _) => Container(color: _kCard),
                    errorWidget: (_, _, _) => Container(
                      color: _kCard,
                      child: const Icon(
                        Icons.broken_image,
                        color: Colors.white24,
                      ),
                    ),
                  ),
                  // Bottom gradient + title
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.85),
                          ],
                          stops: const [0.5, 1.0],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 4,
                    right: 4,
                    bottom: 4,
                    child: Text(
                      item['title'] ?? '',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // Status badge
                  Positioned(
                    top: 4,
                    left: 4,
                    child: _StatusBadge(status: item['status'] ?? 'Reading'),
                  ),
                  // Checkbox overlay
                  if (isSelected)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Container(
                        width: 22,
                        height: 22,
                        decoration: const BoxDecoration(
                          color: _kOrange,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check,
                          color: Colors.white,
                          size: 14,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _openManga(Map<String, dynamic> item) {
    final manga = Manga(
      id: item['manga_id'] ?? '',
      title: item['title'] ?? '',
      coverUrl: item['cover_url'] ?? '',
    );
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => DetailScreen(manga: manga)),
    );
  }

  void _showSearchBar() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _kCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text(
          'Tìm trong danh sách',
          style: TextStyle(color: Colors.white, fontSize: 15),
        ),
        content: TextField(
          controller: _searchController,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Tên manga...',
            prefixIcon: Icon(Icons.search, size: 18),
          ),
          onChanged: (v) => setState(() => _searchQuery = v),
        ),
        actions: [
          if (_searchQuery.isNotEmpty)
            TextButton(
              onPressed: () {
                _searchController.clear();
                setState(() => _searchQuery = '');
                Navigator.pop(ctx);
              },
              child: const Text('Xóa', style: TextStyle(color: Colors.white54)),
            ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Xong'),
          ),
        ],
      ),
    );
  }
}

// ===================== HELPER WIDGETS =====================
class _StatusChip extends StatelessWidget {
  final String status;
  final bool small;
  const _StatusChip({required this.status, this.small = false});

  @override
  Widget build(BuildContext context) {
    final colors = {
      'Reading': const Color(0xFF22C55E),
      'Completed': const Color(0xFF3B82F6),
      'Dropped': const Color(0xFFEF4444),
    };
    final color = colors[status] ?? Colors.grey;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: small ? 6 : 8,
        vertical: small ? 2 : 3,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(9999),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: small ? 6 : 8, color: color),
          SizedBox(width: small ? 3 : 4),
          Text(
            status,
            style: TextStyle(
              color: color,
              fontSize: small ? 10 : 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _TagPill extends StatelessWidget {
  final String label;
  const _TagPill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: _kOrange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(9999),
        border: Border.all(color: _kOrange.withValues(alpha: 0.3)),
      ),
      child: Text(label, style: const TextStyle(color: _kOrange, fontSize: 10)),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final colors = {
      'Reading': const Color(0xFF22C55E),
      'Completed': const Color(0xFF3B82F6),
      'Dropped': const Color(0xFFEF4444),
    };
    final color = colors[status] ?? Colors.grey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        status.substring(0, 1),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _ViewModeButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _ViewModeButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? _kOrange : const Color(0xFF3A3A3A),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: selected ? Colors.white : Colors.white54,
              size: 22,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : Colors.white54,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CoverSizeButton extends StatelessWidget {
  final String label;
  final _CoverSize size;
  final bool selected;
  final VoidCallback onTap;
  const _CoverSizeButton({
    required this.label,
    required this.size,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? _kOrange : const Color(0xFF3A3A3A),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Colors.white54,
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
