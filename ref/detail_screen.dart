import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../models/manga.dart';
import '../../providers/app_provider.dart';
import '../../services/mangadex_api.dart';
import '../reader/reader_screen.dart';

const _kOrange = Color(0xFFFF6740);
const _kCard = Color(0xFF2C2C2C);
const _kBg = Color(0xFF121212);

class DetailScreen extends StatefulWidget {
  final Manga manga;
  const DetailScreen({super.key, required this.manga});
  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Manga? _fullManga;
  List<Map<String, dynamic>> _chapters = [];
  List<Map<String, dynamic>> _covers = [];
  bool _chaptersLoading = true;
  bool _coversLoading = false;
  bool _synopsisExpanded = false;
  bool _chaptersAsc = true;
  String _langFilter = 'all';
  String _chapterSearch = '';
  Map<String, dynamic>? _lastRead;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fullManga = widget.manga;
    _loadData();
  }

  Future<void> _loadData() async {
    final api = MangaDexApi();
    // Load detail, chapters, last read in parallel
    final results = await Future.wait([
      api.getMangaDetail(widget.manga.id),
      api.getMangaChapters(widget.manga.id),
      context.read<AppProvider>().getLastReadChapter(widget.manga.id),
    ]);
    if (!mounted) return;
    setState(() {
      if (results[0] != null) _fullManga = results[0] as Manga;
      _chapters = results[1] as List<Map<String, dynamic>>;
      _lastRead = results[2] as Map<String, dynamic>?;
      _chaptersLoading = false;
    });
  }

  Future<void> _loadCovers() async {
    if (_covers.isNotEmpty) return;
    setState(() => _coversLoading = true);
    final covers = await MangaDexApi().getMangaCovers(widget.manga.id);
    if (mounted) {
      setState(() {
        _covers = covers;
        _coversLoading = false;
      });
    }
  }

  void _showAddToListDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AddToListSheet(manga: _fullManga ?? widget.manga),
    );
  }

  List<Map<String, dynamic>> get _filteredChapters {
    var list = _chapters.toList();
    if (_langFilter != 'all') {
      list = list.where((c) => c['language'] == _langFilter).toList();
    }
    if (_chapterSearch.isNotEmpty) {
      list = list.where((c) {
        final ch = c['chapter'].toString().toLowerCase();
        final t = c['title'].toString().toLowerCase();
        final q = _chapterSearch.toLowerCase();
        return ch.contains(q) || t.contains(q);
      }).toList();
    }
    if (!_chaptersAsc) {
      list = list.reversed.toList();
    }
    return list;
  }

  Set<String> get _availableLanguages {
    return _chapters.map((c) => c['language'].toString()).toSet();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final manga = _fullManga ?? widget.manga;
    return Scaffold(
      backgroundColor: _kBg,
      body: NestedScrollView(
        headerSliverBuilder: (ctx, inner) => [_buildHeroHeader(manga)],
        body: Column(
          children: [
            // Tab bar
            Container(
              color: _kBg,
              child: TabBar(
                controller: _tabController,
                indicatorColor: _kOrange,
                labelColor: _kOrange,
                unselectedLabelColor: Colors.white54,
                labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                onTap: (i) {
                  if (i == 2) _loadCovers();
                },
                tabs: const [
                  Tab(icon: Icon(Icons.info_outline, size: 18), text: 'Thông tin'),
                  Tab(icon: Icon(Icons.list_alt, size: 18), text: 'Chương'),
                  Tab(icon: Icon(Icons.photo_library_outlined, size: 18), text: 'Cover Art'),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildInfoTab(manga),
                  _buildChaptersTab(manga),
                  _buildCoversTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== HERO HEADER ====================
  Widget _buildHeroHeader(Manga manga) {
    return SliverAppBar(
      expandedHeight: 340,
      pinned: true,
      backgroundColor: _kBg,
      iconTheme: const IconThemeData(color: Colors.white),
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.parallax,
        background: Stack(
          fit: StackFit.expand,
          children: [
            CachedNetworkImage(imageUrl: manga.coverUrl, fit: BoxFit.cover),
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(color: Colors.black.withValues(alpha: 0.55)),
            ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, _kBg],
                  stops: const [0.3, 1.0],
                ),
              ),
            ),
            Positioned(
              bottom: 16, left: 16, right: 16,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Cover card
                  Hero(
                    tag: 'cover_${manga.id}',
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: CachedNetworkImage(
                        imageUrl: manga.coverUrl, width: 120, height: 170, fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(manga.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white, height: 1.2), maxLines: 3, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 6),
                        Text(manga.author, style: const TextStyle(fontSize: 13, color: Colors.white70)),
                        if (manga.artist.isNotEmpty && manga.artist != manga.author)
                          Text('🎨 ${manga.artist}', style: const TextStyle(fontSize: 12, color: Colors.white54)),
                        const SizedBox(height: 8),
                        Row(children: [
                          _StatusPill(status: manga.status),
                          const SizedBox(width: 6),
                          if (manga.demographic.isNotEmpty)
                            _DemoPill(label: manga.demographic),
                        ]),
                        const SizedBox(height: 10),
                        // Action buttons
                        Row(children: [
                          _ActionBtn(icon: Icons.bookmark_add_outlined, label: 'Lưu', onTap: _showAddToListDialog),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _chapters.isEmpty ? null : () => _startReading(),
                              icon: Icon(_lastRead != null ? Icons.play_arrow : Icons.menu_book, size: 18),
                              label: Text(_lastRead != null ? 'Tiếp tục Ch.${_lastRead!['chapter_number']}' : 'Đọc ngay', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(backgroundColor: _kOrange, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                            ),
                          ),
                        ]),
                      ],
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

  void _startReading() {
    if (_lastRead != null) {
      _openChapter(_lastRead!['chapter_id'], _lastRead!['chapter_number']);
    } else if (_chapters.isNotEmpty) {
      _openChapter(_chapters.first['id'], _chapters.first['chapter']);
    }
  }

  void _openChapter(String chapterId, String chapterNum) {
    final manga = _fullManga ?? widget.manga;
    final chapterLang = _chapters.firstWhere((c) => c['id'] == chapterId, orElse: () => {'language': 'en'})['language'];
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => ReaderScreen(
        chapterId: chapterId, chapterTitle: chapterNum,
        mangaId: manga.id, mangaTitle: manga.title, mangaCoverUrl: manga.coverUrl,
        chapters: _chapters, currentChapterIndex: _chapters.indexWhere((c) => c['id'] == chapterId),
        currentLanguage: chapterLang,
      ),
    )).then((_) {
      // Refresh last read when coming back
      if (!mounted) return;
      final provider = context.read<AppProvider>();
      provider.getLastReadChapter(manga.id).then((v) {
        if (mounted) setState(() => _lastRead = v);
      });
    });
  }

  // ==================== INFO TAB ====================
  Widget _buildInfoTab(Manga manga) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Synopsis
        const Text('Tóm tắt', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () => setState(() => _synopsisExpanded = !_synopsisExpanded),
          child: AnimatedSize(
            duration: const Duration(milliseconds: 300),
            alignment: Alignment.topCenter,
            child: Stack(
              children: [
                SizedBox(
                  height: _synopsisExpanded ? null : 100,
                  child: SingleChildScrollView(
                    physics: const NeverScrollableScrollPhysics(),
                    child: MarkdownBody(
                      data: manga.description,
                      styleSheet: MarkdownStyleSheet(
                        p: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.6),
                        strong: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        em: const TextStyle(color: Colors.white70, fontStyle: FontStyle.italic),
                        del: const TextStyle(color: Colors.white54, decoration: TextDecoration.lineThrough),
                        listBullet: const TextStyle(color: Colors.white70),
                      ),
                    ),
                  ),
                ),
                if (!_synopsisExpanded)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 40,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            _kBg.withValues(alpha: 0.0),
                            _kBg,
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (!_synopsisExpanded)
          Center(child: TextButton(onPressed: () => setState(() => _synopsisExpanded = true), child: const Text('Xem thêm ▼', style: TextStyle(color: _kOrange, fontSize: 12)))),
        const Divider(color: Colors.white12, height: 32),

        // Metadata grid
        _MetaRow(label: 'Tác giả', value: manga.author),
        if (manga.artist.isNotEmpty) _MetaRow(label: 'Họa sĩ', value: manga.artist),
        if (manga.year != null) _MetaRow(label: 'Năm', value: manga.year.toString()),
        if (manga.demographic.isNotEmpty) _MetaRow(label: 'Đối tượng', value: _demoLabel(manga.demographic)),
        if (manga.contentRating.isNotEmpty) _MetaRow(label: 'Phân loại', value: manga.contentRating.toUpperCase()),
        if (manga.originalLanguage.isNotEmpty) _MetaRow(label: 'Ngôn ngữ gốc', value: manga.originalLanguage.toUpperCase()),
        _MetaRow(label: 'Trạng thái', value: manga.status.toUpperCase()),
        if (manga.lastChapter != null && manga.lastChapter!.isNotEmpty) _MetaRow(label: 'Chương cuối', value: 'Ch. ${manga.lastChapter}'),

        if (manga.genres.isNotEmpty) ...[
          const Divider(color: Colors.white12, height: 32),
          const Text('Thể loại', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 6, children: manga.genres.map((g) => _TagChip(label: g, color: _kOrange)).toList()),
        ],
        if (manga.themes.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Text('Chủ đề', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 6, children: manga.themes.map((t) => _TagChip(label: t, color: const Color(0xFF3B82F6))).toList()),
        ],
        if (manga.altTitles.isNotEmpty) ...[
          const Divider(color: Colors.white12, height: 32),
          const Text('Tên gọi khác', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 8),
          ...manga.altTitles.take(8).map((t) => Padding(padding: const EdgeInsets.only(bottom: 4), child: Text('• $t', style: const TextStyle(color: Colors.white54, fontSize: 13)))),
        ],
        const SizedBox(height: 32),
      ],
    );
  }

  String _demoLabel(String d) {
    const map = {'shounen': 'Shounen', 'shoujo': 'Shoujo', 'seinen': 'Seinen', 'josei': 'Josei'};
    return map[d.toLowerCase()] ?? d;
  }

  // ==================== CHAPTERS TAB ====================
  Widget _buildChaptersTab(Manga manga) {
    final filtered = _filteredChapters;
    return Column(
      children: [
        // Toolbar
        Container(
          color: _kBg,
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: Row(
            children: [
              Text('${filtered.length} chương', style: const TextStyle(color: Colors.white54, fontSize: 12)),
              const Spacer(),
              // Language filter
              if (_availableLanguages.length > 1)
                PopupMenuButton<String>(
                  icon: Icon(Icons.language, color: _langFilter != 'all' ? _kOrange : Colors.white54, size: 20),
                  color: _kCard,
                  onSelected: (v) => setState(() => _langFilter = v),
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'all', child: Text('Tất cả', style: TextStyle(color: Colors.white))),
                    ..._availableLanguages.map((l) => PopupMenuItem(value: l, child: Text(l.toUpperCase(), style: const TextStyle(color: Colors.white)))),
                  ],
                ),
              // Sort
              IconButton(
                icon: Icon(_chaptersAsc ? Icons.arrow_downward : Icons.arrow_upward, color: Colors.white54, size: 20),
                onPressed: () => setState(() => _chaptersAsc = !_chaptersAsc),
                tooltip: _chaptersAsc ? 'Cũ → Mới' : 'Mới → Cũ',
              ),
              // Search
              IconButton(icon: const Icon(Icons.search, color: Colors.white54, size: 20), onPressed: _showChapterSearch),
            ],
          ),
        ),
        if (_chapterSearch.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Chip(
              label: Text('Tìm: "$_chapterSearch"', style: const TextStyle(color: Colors.white, fontSize: 11)),
              backgroundColor: _kOrange.withValues(alpha: 0.2),
              deleteIconColor: Colors.white54,
              onDeleted: () => setState(() => _chapterSearch = ''),
              visualDensity: VisualDensity.compact,
            ),
          ),
        // List
        Expanded(
          child: _chaptersLoading
              ? const Center(child: CircularProgressIndicator(color: _kOrange))
              : filtered.isEmpty
              ? const Center(child: Text('Không có chương nào.', style: TextStyle(color: Colors.white38)))
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 24),
                  itemCount: filtered.length,
                  itemBuilder: (_, i) {
                    final chap = filtered[i];
                    final isLastRead = _lastRead != null && _lastRead!['chapter_id'] == chap['id'];
                    return ListTile(
                      dense: true,
                      tileColor: isLastRead ? _kOrange.withValues(alpha: 0.08) : null,
                      leading: Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(color: isLastRead ? _kOrange.withValues(alpha: 0.2) : _kCard, borderRadius: BorderRadius.circular(6)),
                        child: Center(child: Text(chap['language'].toString().toUpperCase(), style: TextStyle(color: isLastRead ? _kOrange : Colors.white54, fontSize: 9, fontWeight: FontWeight.bold))),
                      ),
                      title: Text('Ch. ${chap['chapter']} ${chap['title'].toString().isNotEmpty ? "— ${chap['title']}" : ""}', style: TextStyle(color: isLastRead ? _kOrange : Colors.white, fontSize: 13, fontWeight: isLastRead ? FontWeight.bold : FontWeight.normal), maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text('${chap['group']}${chap['pages'] > 0 ? " • ${chap['pages']}p" : ""}', style: const TextStyle(color: Colors.white38, fontSize: 11), maxLines: 1),
                      trailing: isLastRead ? const Icon(Icons.bookmark, color: _kOrange, size: 16) : null,
                      onTap: () => _openChapter(chap['id'], chap['chapter']),
                    );
                  },
                ),
        ),
      ],
    );
  }

  void _showChapterSearch() {
    final ctrl = TextEditingController(text: _chapterSearch);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _kCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Tìm chương', style: TextStyle(color: Colors.white, fontSize: 15)),
        content: TextField(
          controller: ctrl, autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(hintText: 'Số chương hoặc tiêu đề...', prefixIcon: Icon(Icons.search, size: 18)),
          onSubmitted: (v) { setState(() => _chapterSearch = v); Navigator.pop(ctx); },
        ),
        actions: [
          TextButton(onPressed: () { setState(() => _chapterSearch = ''); Navigator.pop(ctx); }, child: const Text('Xóa', style: TextStyle(color: Colors.white54))),
          ElevatedButton(onPressed: () { setState(() => _chapterSearch = ctrl.text); Navigator.pop(ctx); }, child: const Text('Tìm')),
        ],
      ),
    );
  }

  // ==================== COVERS TAB ====================
  Widget _buildCoversTab() {
    if (_coversLoading) {
      return const Center(child: CircularProgressIndicator(color: _kOrange));
    }
    if (_covers.isEmpty) {
      return const Center(child: Text('Không có cover art.', style: TextStyle(color: Colors.white38)));
    }
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 0.68),
      itemCount: _covers.length,
      itemBuilder: (_, i) {
        final cover = _covers[i];
        return GestureDetector(
          onTap: () => _showCoverFullScreen(cover['url']),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Stack(
              fit: StackFit.expand,
              children: [
                CachedNetworkImage(imageUrl: cover['urlSmall'], fit: BoxFit.cover, placeholder: (_, _) => Container(color: _kCard)),
                if (cover['volume'].toString().isNotEmpty)
                  Positioned(
                    bottom: 0, left: 0, right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black.withValues(alpha: 0.8)])),
                      child: Text('Vol. ${cover['volume']}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showCoverFullScreen(String url) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: InteractiveViewer(
            child: CachedNetworkImage(imageUrl: url, fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }
}

// ==================== HELPER WIDGETS ====================
class _StatusPill extends StatelessWidget {
  final String status;
  const _StatusPill({required this.status});
  @override
  Widget build(BuildContext context) {
    final colors = {'ongoing': const Color(0xFF22C55E), 'completed': const Color(0xFF3B82F6), 'hiatus': const Color(0xFFF59E0B), 'cancelled': const Color(0xFFEF4444)};
    final color = colors[status.toLowerCase()] ?? Colors.grey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(9999), border: Border.all(color: color.withValues(alpha: 0.5))),
      child: Text(status.toUpperCase(), style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
    );
  }
}

class _DemoPill extends StatelessWidget {
  final String label;
  const _DemoPill({required this.label});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(9999)),
      child: Text(label.toUpperCase(), style: const TextStyle(color: Colors.white54, fontSize: 9, fontWeight: FontWeight.bold)),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon; final String label; final VoidCallback onTap;
  const _ActionBtn({required this.icon, required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(color: const Color(0xFF2A2A2A), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.white12)),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: Colors.white70, size: 18),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 9)),
        ]),
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  final String label; final String value;
  const _MetaRow({required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 110, child: Text(label, style: const TextStyle(color: Colors.white38, fontSize: 13))),
          Expanded(child: Text(value, style: const TextStyle(color: Colors.white, fontSize: 13))),
        ],
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  final String label; final Color color;
  const _TagChip({required this.label, required this.color});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(9999), border: Border.all(color: color.withValues(alpha: 0.35))),
      child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w500)),
    );
  }
}

// ==================== ADD TO LIST SHEET ====================
class _AddToListSheet extends StatefulWidget {
  final Manga manga;
  const _AddToListSheet({required this.manga});

  @override
  State<_AddToListSheet> createState() => _AddToListSheetState();
}

class _AddToListSheetState extends State<_AddToListSheet> {
  bool _isLoading = true;
  bool _isGridView = false;
  Set<String> _initialListsWithManga = {};
  final Set<String> _selectedListsToAdd = {};
  final Set<String> _selectedListsToRemove = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final provider = context.read<AppProvider>();
    await provider.fetchLists();
    final listsContaining = await provider.getListsContainingManga(widget.manga.id);
    if (!mounted) return;
    setState(() {
      _initialListsWithManga = listsContaining.toSet();
      _isLoading = false;
    });
  }

  void _toggleSelection(String listId) {
    setState(() {
      if (_initialListsWithManga.contains(listId)) {
        if (_selectedListsToRemove.contains(listId)) {
          _selectedListsToRemove.remove(listId);
        } else {
          _selectedListsToRemove.add(listId);
        }
      } else {
        if (_selectedListsToAdd.contains(listId)) {
          _selectedListsToAdd.remove(listId);
        } else {
          _selectedListsToAdd.add(listId);
        }
      }
    });
  }

  Future<void> _save() async {
    setState(() => _isLoading = true);
    final provider = context.read<AppProvider>();
    
    // Process additions
    final addFutures = _selectedListsToAdd.map((listId) => provider.addMangaToList(listId, widget.manga));
    await Future.wait(addFutures);

    // Process removals
    final removeFutures = _selectedListsToRemove.map((listId) => provider.removeMangaFromListByMangaId(listId, widget.manga.id));
    await Future.wait(removeFutures);

    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Đã cập nhật danh sách!'), backgroundColor: Colors.green),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                const Text('Lưu vào danh sách', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const Spacer(),
                IconButton(
                  icon: Icon(_isGridView ? Icons.view_list : Icons.grid_view, color: Colors.white70),
                  onPressed: () => setState(() => _isGridView = !_isGridView),
                  tooltip: _isGridView ? 'Chế độ danh sách' : 'Chế độ lưới',
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white12),
          
          // Body
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator(color: _kOrange))
              : provider.customLists.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Text(
                          'Bạn chưa có danh sách nào.\nHãy vào Thư viện để tạo danh sách!',
                          style: TextStyle(fontSize: 16, color: Colors.white70),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : _isGridView 
                      ? _buildGridView(provider.customLists)
                      : _buildListView(provider.customLists),
          ),
          
          // Footer
          if (!_isLoading && provider.customLists.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Colors.white12)),
              ),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: (_selectedListsToAdd.isEmpty && _selectedListsToRemove.isEmpty) ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kOrange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    disabledBackgroundColor: Colors.white12,
                    disabledForegroundColor: Colors.white38,
                  ),
                  child: const Text('Xác nhận', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildListView(List<dynamic> lists) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: lists.length,
      itemBuilder: (ctx, i) {
        final lst = lists[i];
        final listId = lst['id'].toString();
        final initiallyInList = _initialListsWithManga.contains(listId);
        final isSelected = initiallyInList 
            ? !_selectedListsToRemove.contains(listId) 
            : _selectedListsToAdd.contains(listId);

        return ListTile(
          leading: Container(
            width: 40, height: 40,
            decoration: BoxDecoration(color: _kOrange.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.folder_special, color: _kOrange, size: 20),
          ),
          title: Text(lst['name'], style: const TextStyle(color: Colors.white, fontSize: 15)),
          trailing: Checkbox(
            value: isSelected,
            onChanged: (_) => _toggleSelection(listId),
            activeColor: _kOrange,
            checkColor: Colors.white,
            side: const BorderSide(color: Colors.white54),
          ),
          onTap: () => _toggleSelection(listId),
        );
      },
    );
  }

  Widget _buildGridView(List<dynamic> lists) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.5,
      ),
      itemCount: lists.length,
      itemBuilder: (ctx, i) {
        final lst = lists[i];
        final listId = lst['id'].toString();
        final initiallyInList = _initialListsWithManga.contains(listId);
        final isSelected = initiallyInList 
            ? !_selectedListsToRemove.contains(listId) 
            : _selectedListsToAdd.contains(listId);

        return GestureDetector(
          onTap: () => _toggleSelection(listId),
          child: Container(
            decoration: BoxDecoration(
              color: isSelected ? _kOrange.withValues(alpha: 0.1) : const Color(0xFF2A2A2A),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? _kOrange : Colors.white12,
                width: isSelected ? 2 : 1,
              ),
            ),
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Icon(Icons.folder_special, color: _kOrange, size: 24),
                    if (isSelected)
                      const Icon(Icons.check_circle, color: _kOrange, size: 20)
                    else
                      const Icon(Icons.circle_outlined, color: Colors.white38, size: 20),
                  ],
                ),
                const Spacer(),
                Text(
                  lst['name'],
                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
