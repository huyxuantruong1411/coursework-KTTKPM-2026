import 'package:flutter/material.dart';
import '../../widgets/manga_cover_image.dart';
import '../../models/manga.dart';
import '../../services/manga_service.dart';
import '../detail/detail_screen.dart';

const _kOrange = Color(0xFFFF6740);
const _kSurface = Color(0xFF1A1A1A);
const _kCard = Color(0xFF2C2C2C);
const _kBg = Color(0xFF121212);

enum ViewMode { list, comfortable, compact }

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _searchController = TextEditingController();
  List<Manga> _searchResults = [];
  bool _isLoading = false;
  bool _showFilters = false;
  ViewMode _viewMode = ViewMode.comfortable;

  // Tags data
  List<Map<String, dynamic>> _allTags = [];
  bool _isLoadingTags = true;

  // Filter state
  String _sortBy = 'relevance';
  String _sortOrder = 'desc';
  List<String> _includedTags = [];
  List<String> _excludedTags = [];
  List<String> _contentRatings = [];
  List<String> _demographics = [];
  List<String> _statuses = [];
  int? _year;

  @override
  void initState() {
    super.initState();
    _loadTags();
  }

  Future<void> _loadTags() async {
    final tags = await MangaService.getTags();
    if (mounted) {
      setState(() {
        _allTags = tags;
        _isLoadingTags = false;
      });
    }
  }

  Future<void> _performSearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty &&
        _includedTags.isEmpty &&
        _contentRatings.isEmpty &&
        _demographics.isEmpty &&
        _statuses.isEmpty &&
        _year == null) {
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);

    String? sortKey;
    if (_sortBy != 'relevance') {
      if (_sortBy == 'title') {
        sortKey = _sortOrder == 'asc' ? 'title_asc' : 'title_desc';
      } else if (_sortBy == 'year') {
        sortKey = _sortOrder == 'asc' ? 'year_asc' : 'year_desc';
      } else if (_sortBy == 'followedCount') {
        sortKey = 'follows_desc';
      } else if (_sortBy == 'latestUploadedChapter' ||
          _sortBy == 'createdAt' ||
          _sortBy == 'updatedAt') {
        sortKey = 'recent';
      }
    }

    try {
      final res = await MangaService.searchManga(
        query: query,
        includeTags: _includedTags.isNotEmpty ? _includedTags : null,
        excludeTags: _excludedTags.isNotEmpty ? _excludedTags : null,
        status: _statuses.isNotEmpty ? _statuses.first : null,
        contentRating: _contentRatings.isNotEmpty
            ? _contentRatings.first
            : null,
        demographic: _demographics.isNotEmpty ? _demographics.first : null,
        yearFrom: _year,
        yearTo: _year,
        sort: sortKey,
      );

      final results = ((res['items'] ?? []) as List)
          .cast<Map<String, dynamic>>()
          .map(Manga.fromJson)
          .toList();

      if (mounted) {
        setState(() {
          _searchResults = results;
          _showFilters = false;
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _resetFilters() {
    setState(() {
      _sortBy = 'relevance';
      _sortOrder = 'desc';
      _includedTags = [];
      _excludedTags = [];
      _contentRatings = [];
      _demographics = [];
      _statuses = [];
      _year = null;
    });
  }

  void _toggleTag(String tagId) {
    setState(() {
      if (_includedTags.contains(tagId)) {
        _includedTags.remove(tagId);
        _excludedTags.add(tagId);
      } else if (_excludedTags.contains(tagId)) {
        _excludedTags.remove(tagId);
      } else {
        _includedTags.add(tagId);
      }
    });
  }

  int _getTagState(String tagId) {
    if (_includedTags.contains(tagId)) return 1;
    if (_excludedTags.contains(tagId)) return -1;
    return 0;
  }

  int get _activeFiltersCount {
    int count = 0;
    if (_sortBy != 'relevance') count++;
    count += _includedTags.length + _excludedTags.length;
    count += _contentRatings.length;
    count += _demographics.length;
    count += _statuses.length;
    if (_year != null) count++;
    return count;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kSurface,
        title: TextField(
          controller: _searchController,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Tìm kiếm truyện...',
            hintStyle: const TextStyle(color: Colors.white54),
            border: InputBorder.none,
            prefixIcon: const Icon(Icons.search, color: Colors.white54),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, color: Colors.white54),
                    onPressed: () {
                      _searchController.clear();
                      setState(() {});
                    },
                  )
                : null,
          ),
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => _performSearch(),
        ),
        actions: [
          IconButton(
            icon: Stack(
              children: [
                Icon(Icons.tune, color: _showFilters ? _kOrange : Colors.white),
                if (_activeFiltersCount > 0)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: _kOrange,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 12,
                        minHeight: 12,
                      ),
                      child: Text(
                        '$_activeFiltersCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            onPressed: () => setState(() => _showFilters = !_showFilters),
          ),
        ],
      ),
      body: Column(
        children: [
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity, height: 0),
            secondChild: _buildFilterPanel(),
            crossFadeState: _showFilters
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 300),
          ),
          _buildToolbar(),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: _kOrange),
                  )
                : _searchResults.isEmpty
                ? _buildEmptyState()
                : _buildResults(),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterPanel() {
    return Container(
      color: _kCard,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Filter Tags (MangaDex style popup button)
          ElevatedButton.icon(
            onPressed: _showTagSelectorDialog,
            icon: const Icon(Icons.label_outline),
            label: Text(
              _includedTags.isEmpty && _excludedTags.isEmpty
                  ? 'Chọn Thể loại / Tags'
                  : '${_includedTags.length} Included, ${_excludedTags.length} Excluded',
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _kSurface,
              foregroundColor: Colors.white,
              alignment: Alignment.centerLeft,
            ),
          ),
          const SizedBox(height: 12),

          // Dropdowns Row 1
          Row(
            children: [
              Expanded(
                child: _buildDropdown('Sort by', _sortBy, {
                  'relevance': 'Relevance',
                  'latestUploadedChapter': 'Latest Upload',
                  'title': 'Title',
                  'createdAt': 'Created At',
                  'followedCount': 'Follows',
                  'year': 'Year',
                }, (v) => setState(() => _sortBy = v!)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMultiSelect(
                  'Content Rating',
                  _contentRatings,
                  {
                    'safe': 'Safe',
                    'suggestive': 'Suggestive',
                    'erotica': 'Erotica',
                    'pornographic': 'Pornographic',
                  },
                  (v) => setState(() {
                    if (_contentRatings.contains(v)) {
                      _contentRatings.remove(v);
                    } else {
                      _contentRatings.add(v);
                    }
                  }),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Dropdowns Row 2
          Row(
            children: [
              Expanded(
                child: _buildMultiSelect(
                  'Demographic',
                  _demographics,
                  {
                    'shounen': 'Shounen',
                    'shoujo': 'Shoujo',
                    'seinen': 'Seinen',
                    'josei': 'Josei',
                  },
                  (v) => setState(() {
                    if (_demographics.contains(v)) {
                      _demographics.remove(v);
                    } else {
                      _demographics.add(v);
                    }
                  }),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMultiSelect(
                  'Status',
                  _statuses,
                  {
                    'ongoing': 'Ongoing',
                    'completed': 'Completed',
                    'hiatus': 'Hiatus',
                    'cancelled': 'Cancelled',
                  },
                  (v) => setState(() {
                    if (_statuses.contains(v)) {
                      _statuses.remove(v);
                    } else {
                      _statuses.add(v);
                    }
                  }),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          const SizedBox(height: 16),
          Row(
            children: [
              TextButton(
                onPressed: _resetFilters,
                child: const Text(
                  'Reset',
                  style: TextStyle(color: Colors.white54),
                ),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: _performSearch,
                icon: const Icon(Icons.search, size: 18),
                label: const Text('Tìm kiếm'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kOrange,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showTagSelectorDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: _kCard,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              insetPadding: const EdgeInsets.all(16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Text(
                      'Select Tags',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: _isLoadingTags
                          ? const Center(
                              child: CircularProgressIndicator(color: _kOrange),
                            )
                          : ListView(children: _buildTagGroups(setDialogState)),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _includedTags.clear();
                              _excludedTags.clear();
                            });
                            setDialogState(() {});
                          },
                          child: const Text(
                            'Clear All',
                            style: TextStyle(color: Colors.white54),
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(ctx),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _kOrange,
                          ),
                          child: const Text(
                            'Xong',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  List<Widget> _buildTagGroups(StateSetter setDialogState) {
    // Group tags
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (var tag in _allTags) {
      final group = (tag['group'] ?? 'Other').toString();
      if (!grouped.containsKey(group)) grouped[group] = [];
      grouped[group]!.add(tag);
    }

    List<Widget> widgets = [];
    grouped.forEach((group, tags) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            group.toUpperCase(),
            style: const TextStyle(
              color: _kOrange,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      );
      widgets.add(
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: tags.map((tag) {
            final tagId = tag['id'];
            final state = _getTagState(tagId);
            Color bgColor = _kSurface;
            Color textColor = Colors.white70;
            IconData? icon;

            if (state == 1) {
              bgColor = Colors.green.withValues(alpha: 0.2);
              textColor = Colors.green;
              icon = Icons.check;
            } else if (state == -1) {
              bgColor = Colors.red.withValues(alpha: 0.2);
              textColor = Colors.red;
              icon = Icons.close;
            }

            return GestureDetector(
              onTap: () {
                setDialogState(() {
                  _toggleTag(tagId);
                });
                // Also update outer state
                setState(() {});
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: textColor.withValues(alpha: 0.5)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, size: 14, color: textColor),
                      const SizedBox(width: 4),
                    ],
                    Text(
                      tag['name'],
                      style: TextStyle(color: textColor, fontSize: 12),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      );
      widgets.add(const SizedBox(height: 12));
    });
    return widgets;
  }

  Widget _buildDropdown(
    String label,
    String value,
    Map<String, String> options,
    ValueChanged<String?> onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: _kSurface,
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              dropdownColor: _kSurface,
              value: value,
              items: options.entries
                  .map(
                    (e) => DropdownMenuItem(
                      value: e.key,
                      child: Text(
                        e.value,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMultiSelect(
    String label,
    List<String> values,
    Map<String, String> options,
    ValueChanged<String> onToggle,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: _kSurface,
            borderRadius: BorderRadius.circular(8),
          ),
          child: GestureDetector(
            onTap: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: _kCard,
                  title: Text(
                    label,
                    style: const TextStyle(color: Colors.white),
                  ),
                  content: StatefulBuilder(
                    builder: (c, setStateDialog) => SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: options.entries
                            .map(
                              (e) => CheckboxListTile(
                                title: Text(
                                  e.value,
                                  style: const TextStyle(color: Colors.white),
                                ),
                                value: values.contains(e.key),
                                activeColor: _kOrange,
                                onChanged: (_) {
                                  setStateDialog(() {
                                    onToggle(e.key);
                                  });
                                },
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Xong'),
                    ),
                  ],
                ),
              );
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    values.isEmpty
                        ? 'Any'
                        : values.map((v) => options[v]).join(', '),
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Icon(Icons.arrow_drop_down, color: Colors.white54),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildToolbar() {
    return Container(
      color: _kBg,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          Text(
            '${_searchResults.length} titles found',
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const Spacer(),
          // View mode toggles
          Row(
            children: [
              _buildViewModeBtn(Icons.view_list, ViewMode.list),
              _buildViewModeBtn(Icons.grid_view, ViewMode.comfortable),
              _buildViewModeBtn(Icons.apps, ViewMode.compact),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildViewModeBtn(IconData icon, ViewMode mode) {
    final isSelected = _viewMode == mode;
    return IconButton(
      icon: Icon(icon, size: 20, color: isSelected ? _kOrange : Colors.white38),
      onPressed: () => setState(() => _viewMode = mode),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 64,
            color: Colors.white.withValues(alpha: 0.1),
          ),
          const SizedBox(height: 16),
          const Text(
            'Không tìm thấy kết quả nào',
            style: TextStyle(color: Colors.white54, fontSize: 16),
          ),
          const SizedBox(height: 8),
          const Text(
            'Thử thay đổi từ khóa hoặc bộ lọc',
            style: TextStyle(color: Colors.white38, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildResults() {
    if (_viewMode == ViewMode.list) {
      return ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _searchResults.length,
        itemBuilder: (ctx, i) => _MangaListCard(manga: _searchResults[i]),
      );
    } else if (_viewMode == ViewMode.comfortable) {
      return GridView.builder(
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.55,
        ),
        itemCount: _searchResults.length,
        itemBuilder: (ctx, i) =>
            _MangaComfortableCard(manga: _searchResults[i]),
      );
    } else {
      return GridView.builder(
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 0.6,
        ),
        itemCount: _searchResults.length,
        itemBuilder: (ctx, i) => _MangaCompactCard(manga: _searchResults[i]),
      );
    }
  }
}

// ---------- View Mode Cards ----------

class _MangaListCard extends StatelessWidget {
  final Manga manga;
  const _MangaListCard({required this.manga});

  String get _authorText => manga.author.isEmpty || manga.author == 'Unknown'
      ? 'Tac gia dang cap nhat'
      : manga.author;

  String get _descriptionText =>
      manga.description.isEmpty ||
          manga.description == 'No description available.'
      ? 'Chua co mo ta.'
      : manga.description;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => DetailScreen(manga: manga)),
      ),
      child: Container(
        height: 140,
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.circular(8),
        ),
        clipBehavior: Clip.antiAlias,
        child: Row(
          children: [
            SizedBox(
              width: 100,
              height: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  MangaCoverImage(
                    coverUrl: manga.coverUrl,
                    mangaId: manga.id,
                    fileName: manga.coverFileName,
                    fit: BoxFit.cover,
                  ),
                  Positioned(
                    top: 4,
                    left: 4,
                    child: _StatusBadge(status: manga.status),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      manga.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _authorText,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                      ),
                      maxLines: 1,
                    ),
                    const SizedBox(height: 6),
                    Expanded(
                      child: Text(
                        _descriptionText,
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 11,
                          height: 1.4,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (manga.genres.isNotEmpty)
                      Wrap(
                        spacing: 4,
                        children: manga.genres
                            .take(3)
                            .map((g) => _GenreChip(label: g))
                            .toList(),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MangaComfortableCard extends StatelessWidget {
  final Manga manga;
  const _MangaComfortableCard({required this.manga});

  String get _authorText => manga.author.isEmpty || manga.author == 'Unknown'
      ? 'Tac gia dang cap nhat'
      : manga.author;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => DetailScreen(manga: manga)),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.circular(8),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  MangaCoverImage(
                    coverUrl: manga.coverUrl,
                    mangaId: manga.id,
                    fileName: manga.coverFileName,
                    fit: BoxFit.cover,
                  ),
                  Positioned(
                    top: 4,
                    left: 4,
                    child: _StatusBadge(status: manga.status),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      manga.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _authorText,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                      ),
                      maxLines: 1,
                    ),
                    const Spacer(),
                    if (manga.genres.isNotEmpty)
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: manga.genres
                              .take(3)
                              .map(
                                (g) => Padding(
                                  padding: const EdgeInsets.only(right: 4),
                                  child: _GenreChip(label: g),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MangaCompactCard extends StatelessWidget {
  final Manga manga;
  const _MangaCompactCard({required this.manga});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => DetailScreen(manga: manga)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  MangaCoverImage(
                    coverUrl: manga.coverUrl,
                    mangaId: manga.id,
                    fileName: manga.coverFileName,
                    fit: BoxFit.cover,
                  ),
                  Positioned(
                    top: 4,
                    left: 4,
                    child: _StatusBadge(status: manga.status),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            manga.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});
  @override
  Widget build(BuildContext context) {
    final colors = {
      'ongoing': const Color(0xFF22C55E),
      'completed': const Color(0xFF3B82F6),
      'hiatus': const Color(0xFFF59E0B),
      'cancelled': const Color(0xFFEF4444),
    };
    final labels = {
      'ongoing': 'ON',
      'completed': 'END',
      'hiatus': 'HIA',
      'cancelled': 'CAN',
    };
    final color = colors[status.toLowerCase()] ?? Colors.grey;
    final label =
        labels[status.toLowerCase()] ?? status.substring(0, 2).toUpperCase();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _GenreChip extends StatelessWidget {
  final String label;
  const _GenreChip({required this.label});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: _kOrange.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: _kOrange.withValues(alpha: 0.4)),
      ),
      child: Text(label, style: const TextStyle(color: _kOrange, fontSize: 9)),
    );
  }
}
