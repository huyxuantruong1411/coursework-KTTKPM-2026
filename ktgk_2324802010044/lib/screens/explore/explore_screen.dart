import 'package:flutter/material.dart';
import '../../widgets/manga_cover_image.dart';
import '../../models/manga.dart';
import '../../services/manga_service.dart';
import '../detail/detail_screen.dart';

const _kOrange = Color(0xFFFF6740);
const _kSurface = Color(0xFF1A1A1A);
const _kCard = Color(0xFF2C2C2C);

// Các thể loại nổi bật để filter nhanh
const _featuredGenres = <String, String>{
  'Action': '391b0423-d847-456f-aff0-8b0cfc03066b',
  'Romance': '423e2eae-a7a2-4a8b-ac03-a8351462d71d',
  'Fantasy': 'cdc58593-87dd-415e-bbc0-2ec27bf404cc',
  'Comedy': '4d32cc48-9f00-4cca-9b5a-a839f0764984',
  'Horror': 'cdad7e68-1419-41dd-bdce-27753074a640',
  'Sci-Fi': '256c8bd9-4904-4360-bf4f-508a76d67183',
  'Slice of Life': 'e5301a23-ebd9-49dd-a0cb-2add944c7fe9',
  'Adventure': '87cc87cd-a395-47af-b27a-93258283bbc6',
};

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});
  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  late Future<List<Manga>> _popularFuture;
  late Future<List<Manga>> _recentFuture;
  late Future<List<Manga>> _recommendedFuture;
  String? _selectedGenreId;
  String? _selectedGenreName;

  @override
  void initState() {
    super.initState();
    _popularFuture = MangaService.getPopularManga().then(
      (res) => res.map((e) => Manga.fromJson(e)).toList(),
    );
    _recentFuture = MangaService.getRecentManga().then(
      (res) => res.map((e) => Manga.fromJson(e)).toList(),
    );
    _recommendedFuture = MangaService.getRecommendations().then(
      (res) => res.map((e) => Manga.fromJson(e)).toList(),
    );
  }

  void _filterByGenre(String name, String id) {
    setState(() {
      if (_selectedGenreId == id) {
        _selectedGenreId = null;
        _selectedGenreName = null;
        _popularFuture = MangaService.getPopularManga().then(
          (res) => res.map((e) => Manga.fromJson(e)).toList(),
        );
      } else {
        _selectedGenreId = id;
        _selectedGenreName = name;
        _popularFuture =
            MangaService.searchManga(
              query: '',
              includeTags: [id],
              limit: 20,
            ).then(
              (res) => ((res['items'] ?? []) as List)
                  .cast<Map<String, dynamic>>()
                  .map((e) => Manga.fromJson(e))
                  .toList(),
            );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(),
          _buildGenreFilterRow(),
          _buildSectionHeader(
            _selectedGenreName != null
                ? 'Thể loại: $_selectedGenreName'
                : '🔥 Phổ biến',
            showMore: false,
          ),
          _buildPopularGrid(),
          _buildSectionHeader('⭐ Gợi ý cho bạn', showMore: false),
          _buildHorizontalList(_recommendedFuture),
          _buildSectionHeader('🕐 Mới cập nhật', showMore: false),
          _buildHorizontalList(_recentFuture),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }

  // ---------- APP BAR với Hero Banner ----------
  Widget _buildSliverAppBar() {
    return SliverAppBar(
      backgroundColor: Colors.black,
      expandedHeight: 220,
      pinned: true,
      surfaceTintColor: Colors.transparent,
      title: Row(
        children: [
          Text(
            'MangaDex',
            style: TextStyle(
              color: _kOrange,
              fontWeight: FontWeight.bold,
              fontSize: 22,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(
            Icons.notifications_none_rounded,
            color: Colors.white70,
          ),
          onPressed: () {},
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.parallax,
        background: FutureBuilder<List<Manga>>(
          future: _popularFuture,
          builder: (ctx, snap) {
            if (!snap.hasData || snap.data!.isEmpty) {
              return Container(color: _kSurface);
            }
            final hero = snap.data![0];
            return GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => DetailScreen(manga: hero)),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  MangaCoverImage(
                    coverUrl: hero.coverUrl,
                    mangaId: hero.id,
                    fileName: hero.coverFileName,
                    fit: BoxFit.cover,
                  ),
                  // Gradient overlay
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.85),
                        ],
                        stops: const [0.3, 1.0],
                      ),
                    ),
                  ),
                  // Text info
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 16,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: _kOrange,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'NỔI BẬT',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          hero.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            shadows: [
                              Shadow(blurRadius: 8, color: Colors.black54),
                            ],
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          hero.author.isEmpty || hero.author == 'Unknown'
                              ? 'Tac gia dang cap nhat'
                              : hero.author,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // ---------- Genre Filter Row ----------
  Widget _buildGenreFilterRow() {
    return SliverToBoxAdapter(
      child: SizedBox(
        height: 44,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          children: _featuredGenres.entries.map((e) {
            final isSelected = _selectedGenreId == e.value;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => _filterByGenre(e.key, e.value),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: isSelected ? _kOrange : _kCard,
                    borderRadius: BorderRadius.circular(9999),
                    border: Border.all(
                      color: isSelected
                          ? _kOrange
                          : Colors.white.withValues(alpha: 0.12),
                    ),
                  ),
                  child: Center(
                    child: Text(
                      e.key,
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.white70,
                        fontSize: 13,
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
      ),
    );
  }

  // ---------- Section Header ----------
  Widget _buildSectionHeader(String title, {bool showMore = true}) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (showMore)
              TextButton(
                onPressed: () {},
                style: TextButton.styleFrom(
                  foregroundColor: _kOrange,
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Xem thêm →'),
              ),
          ],
        ),
      ),
    );
  }

  // ---------- Popular Grid ----------
  Widget _buildPopularGrid() {
    return FutureBuilder<List<Manga>>(
      future: _popularFuture,
      builder: (ctx, snap) {
        if (!snap.hasData) {
          return const SliverToBoxAdapter(
            child: SizedBox(
              height: 300,
              child: Center(child: CircularProgressIndicator(color: _kOrange)),
            ),
          );
        }
        final mangas = snap.data!;
        return SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 0.62,
            ),
            delegate: SliverChildBuilderDelegate(
              (ctx, i) => _MangaGridCard(manga: mangas[i]),
              childCount: mangas.length,
            ),
          ),
        );
      },
    );
  }

  // ---------- Horizontal Scroll ----------
  Widget _buildHorizontalList(Future<List<Manga>> futureData) {
    return FutureBuilder<List<Manga>>(
      future: futureData,
      builder: (ctx, snap) {
        if (!snap.hasData) {
          return const SliverToBoxAdapter(child: SizedBox(height: 160));
        }
        final mangas = snap.data!;
        return SliverToBoxAdapter(
          child: SizedBox(
            height: 200,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: mangas.length,
              itemBuilder: (ctx, i) => Padding(
                padding: const EdgeInsets.only(right: 10),
                child: _MangaHorizontalCard(manga: mangas[i]),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ---------- Manga Grid Card ----------
class _MangaGridCard extends StatelessWidget {
  final Manga manga;
  const _MangaGridCard({required this.manga});

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
                  // Status badge
                  Positioned(
                    top: 4,
                    left: 4,
                    child: _StatusBadge(status: manga.status),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            manga.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.white,
              fontWeight: FontWeight.w500,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------- Manga Horizontal Card ----------
class _MangaHorizontalCard extends StatelessWidget {
  final Manga manga;
  const _MangaHorizontalCard({required this.manga});

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
      child: SizedBox(
        width: 310,
        child: Card(
          color: _kCard,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          clipBehavior: Clip.antiAlias,
          child: Row(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(6),
                  bottomLeft: Radius.circular(6),
                ),
                child: MangaCoverImage(
                  coverUrl: manga.coverUrl,
                  mangaId: manga.id,
                  fileName: manga.coverFileName,
                  width: 90,
                  height: 200,
                  fit: BoxFit.cover,
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        manga.title,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _authorText,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.white54,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      if (manga.genres.isNotEmpty)
                        Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: manga.genres
                              .take(3)
                              .map(
                                (g) => Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _kOrange.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(9999),
                                    border: Border.all(
                                      color: _kOrange.withValues(alpha: 0.4),
                                    ),
                                  ),
                                  child: Text(
                                    g,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: _kOrange,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------- Status Badge Widget ----------
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
