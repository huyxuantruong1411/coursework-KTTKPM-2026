import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../widgets/manga_cover_image.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../models/manga.dart';
import '../../providers/app_provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/mangadex_api.dart';
import '../../services/manga_service.dart';
import '../../services/chapter_service.dart';
import '../../services/comment_service.dart';
import '../../services/manga_download_service.dart';
import '../../services/rating_service.dart';
import '../../services/recommendation_service.dart';
import '../reader/reader_screen.dart';
import '../creator/creator_screen.dart';

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
  int? _myRating;
  bool _ratingLoading = false;
  List<Map<String, dynamic>> _comments = [];
  bool _commentsLoading = false;
  bool _commentsLoaded = false;
  final _commentController = TextEditingController();
  bool _commentIsSpoiler = false;
  bool _postingComment = false;
  final Set<String> _revealedSpoilers = {};
  List<Manga> _recommendations = [];
  bool _recommendationsLoading = false;
  bool _recommendationsLoaded = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _tabController.addListener(_handleTabChanged);
    _fullManga = widget.manga;
    _loadData();
  }

  void _handleTabChanged() {
    if (_tabController.index == 2) _loadCovers();
    if (_tabController.index == 3) _loadComments();
    if (_tabController.index == 4) _loadRecommendations();
  }

  Future<void> _loadData() async {
    final detailFuture = MangaService.getMangaDetail(
      widget.manga.id,
    ).then((res) => res != null ? Manga.fromJson(res) : null);
    final chaptersFuture = ChapterService.getChapters(widget.manga.id).then(
      (res) => res
          .map(_normalizeChapter)
          .where((c) => c['id'].toString().isNotEmpty)
          .toList(),
    );
    final lastReadFuture = context.read<AppProvider>().getLastReadChapter(
      widget.manga.id,
    );
    final myRatingFuture = RatingService.getMyRating(widget.manga.id);

    final results = await Future.wait<Object?>([
      detailFuture,
      chaptersFuture,
      lastReadFuture,
      myRatingFuture,
    ]);
    if (!mounted) return;
    setState(() {
      if (results[0] != null) _fullManga = results[0] as Manga;
      _chapters = results[1] as List<Map<String, dynamic>>;
      _lastRead = results[2] as Map<String, dynamic>?;
      _myRating = results[3] as int?;
      _chaptersLoading = false;
    });
  }

  static Map<String, dynamic> _normalizeChapter(Map<String, dynamic> raw) {
    return {
      'id':
          raw['ChapterId']?.toString() ??
          raw['chapter_id']?.toString() ??
          raw['id']?.toString() ??
          '',
      'chapter':
          raw['ChapterNumber']?.toString() ??
          raw['chapter_number']?.toString() ??
          raw['chapter']?.toString() ??
          'Oneshot',
      'title': raw['Title']?.toString() ?? raw['title']?.toString() ?? '',
      'volume': raw['Volume']?.toString() ?? raw['volume']?.toString() ?? '',
      'language':
          raw['TranslatedLang']?.toString() ??
          raw['translated_lang']?.toString() ??
          raw['language']?.toString() ??
          'en',
      'pages': raw['Pages'] is int
          ? raw['Pages']
          : raw['pages'] is int
          ? raw['pages']
          : int.tryParse((raw['Pages'] ?? raw['pages'] ?? '0').toString()) ?? 0,
      'publishAt':
          raw['PublishAt']?.toString() ?? raw['publish_at']?.toString() ?? '',
      'group':
          raw['ScanlationGroup']?.toString() ??
          raw['group']?.toString() ??
          'Unknown',
    };
  }

  Future<void> _loadCovers() async {
    if (_covers.isNotEmpty || _coversLoading) return;
    setState(() => _coversLoading = true);
    final covers = await MangaDexApi().getMangaCovers(widget.manga.id);
    if (mounted) {
      setState(() {
        _covers = covers;
        _coversLoading = false;
      });
    }
  }

  Future<void> _loadComments({bool force = false}) async {
    if (_commentsLoading || (_commentsLoaded && !force)) return;
    setState(() => _commentsLoading = true);
    try {
      final res = await CommentService.getComments(widget.manga.id, limit: 50);
      final items = (res['items'] as List? ?? [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      if (!mounted) return;
      setState(() {
        _comments = items;
        _commentsLoaded = true;
        _commentsLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _commentsLoading = false);
    }
  }

  Future<void> _postComment() async {
    final content = _commentController.text.trim();
    if (content.length < 5 || _postingComment) return;
    setState(() => _postingComment = true);
    try {
      final res = await CommentService.postComment(
        widget.manga.id,
        content,
        isSpoiler: _commentIsSpoiler,
      );
      final comment = res?['comment'];
      if (!mounted) return;
      setState(() {
        if (comment is Map) {
          _comments.insert(0, Map<String, dynamic>.from(comment));
        }
        _commentController.clear();
        _commentIsSpoiler = false;
        _commentsLoaded = true;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Loi dang binh luan: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _postingComment = false);
    }
  }

  Future<void> _loadRecommendations({bool force = false}) async {
    if (_recommendationsLoading || (_recommendationsLoaded && !force)) return;
    setState(() => _recommendationsLoading = true);
    final recs = await RecommendationService.getSimilarManga(
      widget.manga.id,
      limit: 12,
    );
    if (!mounted) return;
    setState(() {
      _recommendations = recs;
      _recommendationsLoaded = true;
      _recommendationsLoading = false;
    });
  }

  void _showDownloadDialog() {
    if (_chapters.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Khong co chapter de tai.')));
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DownloadOptionsSheet(
        manga: _fullManga ?? widget.manga,
        chapters: _chapters,
      ),
    );
  }

  String _commentIdOf(Map<String, dynamic> comment) {
    return comment['CommentId']?.toString() ??
        comment['comment_id']?.toString() ??
        comment['id']?.toString() ??
        '';
  }

  String _commentUserIdOf(Map<String, dynamic> comment) {
    return comment['UserId']?.toString() ??
        comment['user_id']?.toString() ??
        '';
  }

  int _commentInt(Map<String, dynamic> comment, String pascal, String snake) {
    final value = comment[pascal] ?? comment[snake] ?? 0;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
  }

  bool _commentBool(Map<String, dynamic> comment, String pascal, String snake) {
    final value = comment[pascal] ?? comment[snake] ?? false;
    if (value is bool) return value;
    return value.toString().toLowerCase() == 'true';
  }

  String _commentText(
    Map<String, dynamic> comment,
    String pascal,
    String snake,
  ) {
    return comment[pascal]?.toString() ?? comment[snake]?.toString() ?? '';
  }

  Future<void> _toggleCommentReaction(
    Map<String, dynamic> comment,
    bool isLike,
  ) async {
    final commentId = _commentIdOf(comment);
    if (commentId.isEmpty) return;
    try {
      final res = isLike
          ? await CommentService.likeComment(commentId)
          : await CommentService.dislikeComment(commentId);
      if (!mounted) return;
      setState(() {
        comment['LikeCount'] = res['like_count'] ?? comment['LikeCount'];
        comment['DislikeCount'] =
            res['dislike_count'] ?? comment['DislikeCount'];
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Loi cap nhat reaction: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _deleteComment(Map<String, dynamic> comment) async {
    final commentId = _commentIdOf(comment);
    if (commentId.isEmpty) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _kCard,
        title: const Text(
          'Xoa binh luan?',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Huy'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Xoa'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await CommentService.deleteComment(commentId);
      if (mounted) {
        setState(
          () => _comments.removeWhere((c) => _commentIdOf(c) == commentId),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Loi xoa binh luan: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _showEditCommentDialog(Map<String, dynamic> comment) async {
    final commentId = _commentIdOf(comment);
    if (commentId.isEmpty) return;
    final ctrl = TextEditingController(
      text: _commentText(comment, 'Content', 'content'),
    );
    final content = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _kCard,
        title: const Text(
          'Sua binh luan',
          style: TextStyle(color: Colors.white),
        ),
        content: TextField(
          controller: ctrl,
          minLines: 3,
          maxLines: 6,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(hintText: 'Noi dung...'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Huy'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Luu'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (content == null || content.length < 5) return;
    try {
      await CommentService.updateComment(commentId, content);
      if (mounted) {
        setState(() => comment['Content'] = content);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Loi sua binh luan: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _showReportCommentDialog(Map<String, dynamic> comment) async {
    const reasons = [
      'Spam or advertising',
      'Harassment or hate speech',
      'Unmarked spoilers',
      'Inappropriate content',
      'Misinformation',
      'Other',
    ];
    var selected = reasons.first;
    final customCtrl = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: _kCard,
          title: const Text(
            'Bao cao binh luan',
            style: TextStyle(color: Colors.white),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ...reasons.map((reason) {
                  final isSelected = selected == reason;
                  return InkWell(
                    onTap: () => setDialogState(() => selected = reason),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          Icon(
                            isSelected
                                ? Icons.radio_button_checked
                                : Icons.radio_button_unchecked,
                            color: isSelected ? _kOrange : Colors.white38,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              reason,
                              style: const TextStyle(color: Colors.white70),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
                if (selected == 'Other')
                  TextField(
                    controller: customCtrl,
                    minLines: 2,
                    maxLines: 4,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(hintText: 'Ly do...'),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Huy'),
            ),
            ElevatedButton(
              onPressed: () {
                final value = selected == 'Other'
                    ? customCtrl.text.trim()
                    : selected;
                Navigator.pop(ctx, value);
              },
              child: const Text('Gui'),
            ),
          ],
        ),
      ),
    );
    customCtrl.dispose();
    if (reason == null || reason.trim().isEmpty) return;
    try {
      await CommentService.reportComment(_commentIdOf(comment), reason.trim());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Da gui bao cao.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Loi bao cao: $e'), backgroundColor: Colors.red),
      );
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

  Future<void> _rateManga(int score) async {
    if (_ratingLoading) return;
    setState(() => _ratingLoading = true);
    try {
      await RatingService.rateManga(widget.manga.id, score);
      final detail = await MangaService.getMangaDetail(widget.manga.id);
      if (!mounted) return;
      setState(() {
        _myRating = score;
        if (detail != null) _fullManga = Manga.fromJson(detail);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Da cham $score/10 diem.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Loi cham diem: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _ratingLoading = false);
    }
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
    _tabController.removeListener(_handleTabChanged);
    _tabController.dispose();
    _commentController.dispose();
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
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                indicatorColor: _kOrange,
                labelColor: _kOrange,
                unselectedLabelColor: Colors.white54,
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
                onTap: (i) {
                  if (i == 2) _loadCovers();
                  if (i == 3) _loadComments();
                  if (i == 4) _loadRecommendations();
                },
                tabs: const [
                  Tab(
                    icon: Icon(Icons.info_outline, size: 18),
                    text: 'Thông tin',
                  ),
                  Tab(icon: Icon(Icons.list_alt, size: 18), text: 'Chương'),
                  Tab(
                    icon: Icon(Icons.photo_library_outlined, size: 18),
                    text: 'Cover Art',
                  ),
                  Tab(
                    icon: Icon(Icons.chat_bubble_outline, size: 18),
                    text: 'Binh luan',
                  ),
                  Tab(icon: Icon(Icons.auto_awesome, size: 18), text: 'Goi y'),
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
                  _buildCommentsTab(),
                  _buildRecommendationsTab(),
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
            MangaCoverImage(coverUrl: manga.coverUrl, mangaId: manga.id, fileName: manga.coverFileName, fit: BoxFit.cover),
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
              bottom: 16,
              left: 16,
              right: 16,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Cover card
                  Hero(
                    tag: 'cover_${manga.id}',
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: MangaCoverImage(
                        coverUrl: manga.coverUrl,
                        mangaId: manga.id,
                        fileName: manga.coverFileName,
                        width: 120,
                        height: 170,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          manga.title,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            height: 1.2,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          manga.author,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.white70,
                          ),
                        ),
                        if (manga.artist.isNotEmpty &&
                            manga.artist != manga.author)
                          Text(
                            '🎨 ${manga.artist}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.white54,
                            ),
                          ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            _StatusPill(status: manga.status),
                            const SizedBox(width: 6),
                            if (manga.demographic.isNotEmpty)
                              _DemoPill(label: manga.demographic),
                          ],
                        ),
                        const SizedBox(height: 10),
                        // Action buttons
                        Row(
                          children: [
                            _ActionBtn(
                              icon: Icons.bookmark_add_outlined,
                              label: 'Lưu',
                              onTap: _showAddToListDialog,
                            ),
                            const SizedBox(width: 8),
                            _ActionBtn(
                              icon: Icons.download_rounded,
                              label: 'Tai',
                              onTap: _showDownloadDialog,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _chapters.isEmpty
                                    ? null
                                    : () => _startReading(),
                                icon: Icon(
                                  _lastRead != null
                                      ? Icons.play_arrow
                                      : Icons.menu_book,
                                  size: 18,
                                ),
                                label: Text(
                                  _continueButtonLabel,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _kOrange,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 10,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
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
          ],
        ),
      ),
    );
  }

  void _startReading() {
    if (_lastRead != null) {
      final chapterId = _lastRead!['chapter_id']?.toString() ?? '';
      final chapter = _chapters.firstWhere(
        (c) => c['id'] == chapterId,
        orElse: () => <String, dynamic>{},
      );
      final chapterNumber =
          (_lastRead!['chapter_number']?.toString().isNotEmpty == true)
          ? _lastRead!['chapter_number'].toString()
          : chapter['chapter']?.toString() ?? '';
      if (chapterId.isNotEmpty) _openChapter(chapterId, chapterNumber);
    } else if (_chapters.isNotEmpty) {
      _openChapter(
        _chapters.first['id'].toString(),
        _chapters.first['chapter'].toString(),
      );
    }
  }

  String get _continueButtonLabel {
    if (_lastRead == null) return 'Đọc ngay';
    final chapterNumber = _lastRead!['chapter_number']?.toString() ?? '';
    return chapterNumber.isNotEmpty ? 'Tiếp tục Ch.$chapterNumber' : 'Tiếp tục';
  }

  void _openChapter(String chapterId, String chapterNum) {
    final manga = _fullManga ?? widget.manga;
    final chapterLang = _chapters
        .firstWhere(
          (c) => c['id'] == chapterId,
          orElse: () => {'language': 'en'},
        )['language']
        .toString();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReaderScreen(
          chapterId: chapterId,
          chapterTitle: chapterNum,
          mangaId: manga.id,
          mangaTitle: manga.title,
          mangaCoverUrl: manga.coverUrl,
          chapters: _chapters,
          currentChapterIndex: _chapters.indexWhere(
            (c) => c['id'] == chapterId,
          ),
          currentLanguage: chapterLang,
        ),
      ),
    ).then((_) {
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
        _buildRatingCard(manga),
        const SizedBox(height: 18),
        // Synopsis
        const Text(
          'Tóm tắt',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
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
                        p: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                          height: 1.6,
                        ),
                        strong: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                        em: const TextStyle(
                          color: Colors.white70,
                          fontStyle: FontStyle.italic,
                        ),
                        del: const TextStyle(
                          color: Colors.white54,
                          decoration: TextDecoration.lineThrough,
                        ),
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
                          colors: [_kBg.withValues(alpha: 0.0), _kBg],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (!_synopsisExpanded)
          Center(
            child: TextButton(
              onPressed: () => setState(() => _synopsisExpanded = true),
              child: const Text(
                'Xem thêm ▼',
                style: TextStyle(color: _kOrange, fontSize: 12),
              ),
            ),
          ),
        const Divider(color: Colors.white12, height: 32),

        // Metadata grid
        _ClickableMetaRow(
          label: 'Tác giả',
          value: manga.author,
          onTap: () => _openCreator(manga, manga.author, role: 'author'),
        ),
        if (manga.artist.isNotEmpty)
          _ClickableMetaRow(
            label: 'Họa sĩ',
            value: manga.artist,
            onTap: () => _openCreator(manga, manga.artist, role: 'artist'),
          ),
        if (manga.year != null)
          _MetaRow(label: 'Năm', value: manga.year.toString()),
        if (manga.demographic.isNotEmpty)
          _MetaRow(label: 'Đối tượng', value: _demoLabel(manga.demographic)),
        if (manga.contentRating.isNotEmpty)
          _MetaRow(
            label: 'Phân loại',
            value: manga.contentRating.toUpperCase(),
          ),
        if (manga.originalLanguage.isNotEmpty)
          _MetaRow(
            label: 'Ngôn ngữ gốc',
            value: manga.originalLanguage.toUpperCase(),
          ),
        _MetaRow(label: 'Trạng thái', value: manga.status.toUpperCase()),
        if (manga.lastChapter != null && manga.lastChapter!.isNotEmpty)
          _MetaRow(label: 'Chương cuối', value: 'Ch. ${manga.lastChapter}'),

        if (manga.genres.isNotEmpty) ...[
          const Divider(color: Colors.white12, height: 32),
          const Text(
            'Thể loại',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: manga.genres
                .map((g) => _TagChip(label: g, color: _kOrange))
                .toList(),
          ),
        ],
        if (manga.themes.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Text(
            'Chủ đề',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: manga.themes
                .map((t) => _TagChip(label: t, color: const Color(0xFF3B82F6)))
                .toList(),
          ),
        ],
        if (manga.altTitles.isNotEmpty) ...[
          const Divider(color: Colors.white12, height: 32),
          const Text(
            'Tên gọi khác',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          ...manga.altTitles
              .take(8)
              .map(
                (t) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '• $t',
                    style: const TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                ),
              ),
        ],
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildRatingCard(Manga manga) {
    final average = manga.rating > 0 ? manga.rating.toStringAsFixed(1) : '--';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.star_rounded, color: _kOrange, size: 22),
              const SizedBox(width: 8),
              Text(
                'Danh gia $average/10',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              const Spacer(),
              if (_myRating != null)
                Text(
                  'Ban: $_myRating/10',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: List.generate(10, (index) {
              final score = index + 1;
              final selected = (_myRating ?? 0) >= score;
              return InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: _ratingLoading ? null : () => _rateManga(score),
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: Icon(
                    selected ? Icons.star_rounded : Icons.star_border_rounded,
                    color: selected ? _kOrange : Colors.white30,
                    size: 26,
                  ),
                ),
              );
            }),
          ),
          if (_ratingLoading)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: LinearProgressIndicator(
                color: _kOrange,
                backgroundColor: Colors.white12,
                minHeight: 2,
              ),
            ),
        ],
      ),
    );
  }

  void _openCreator(Manga manga, String name, {String? role}) {
    if (name.isEmpty) return;
    final creator = manga.creators.where((c) {
      final sameName = c['name']?.toString() == name;
      final sameRole = role == null || c['role']?.toString() == role;
      return sameName && sameRole;
    }).firstOrNull;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreatorScreen(
          creatorId: creator?['id']?.toString(),
          creatorName: name,
        ),
      ),
    );
  }

  String _demoLabel(String d) {
    const map = {
      'shounen': 'Shounen',
      'shoujo': 'Shoujo',
      'seinen': 'Seinen',
      'josei': 'Josei',
    };
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
              Text(
                '${filtered.length} chương',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
              const Spacer(),
              // Language filter
              if (_availableLanguages.length > 1)
                PopupMenuButton<String>(
                  icon: Icon(
                    Icons.language,
                    color: _langFilter != 'all' ? _kOrange : Colors.white54,
                    size: 20,
                  ),
                  color: _kCard,
                  onSelected: (v) => setState(() => _langFilter = v),
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'all',
                      child: Text(
                        'Tất cả',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                    ..._availableLanguages.map(
                      (l) => PopupMenuItem(
                        value: l,
                        child: Text(
                          l.toUpperCase(),
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              // Sort
              IconButton(
                icon: Icon(
                  _chaptersAsc ? Icons.arrow_downward : Icons.arrow_upward,
                  color: Colors.white54,
                  size: 20,
                ),
                onPressed: () => setState(() => _chaptersAsc = !_chaptersAsc),
                tooltip: _chaptersAsc ? 'Cũ → Mới' : 'Mới → Cũ',
              ),
              // Search
              IconButton(
                icon: const Icon(Icons.search, color: Colors.white54, size: 20),
                onPressed: _showChapterSearch,
              ),
            ],
          ),
        ),
        if (_chapterSearch.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Chip(
              label: Text(
                'Tìm: "$_chapterSearch"',
                style: const TextStyle(color: Colors.white, fontSize: 11),
              ),
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
              ? const Center(
                  child: Text(
                    'Không có chương nào.',
                    style: TextStyle(color: Colors.white38),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 24),
                  itemCount: filtered.length,
                  itemBuilder: (_, i) {
                    final chap = filtered[i];
                    final isLastRead =
                        _lastRead != null &&
                        _lastRead!['chapter_id'] == chap['id'];
                    return ListTile(
                      dense: true,
                      tileColor: isLastRead
                          ? _kOrange.withValues(alpha: 0.08)
                          : null,
                      leading: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: isLastRead
                              ? _kOrange.withValues(alpha: 0.2)
                              : _kCard,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Center(
                          child: Text(
                            chap['language'].toString().toUpperCase(),
                            style: TextStyle(
                              color: isLastRead ? _kOrange : Colors.white54,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      title: Text(
                        'Ch. ${chap['chapter']} ${chap['title'].toString().isNotEmpty ? "— ${chap['title']}" : ""}',
                        style: TextStyle(
                          color: isLastRead ? _kOrange : Colors.white,
                          fontSize: 13,
                          fontWeight: isLastRead
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '${chap['group']}${chap['pages'] > 0 ? " • ${chap['pages']}p" : ""}',
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 11,
                        ),
                        maxLines: 1,
                      ),
                      trailing: isLastRead
                          ? const Icon(
                              Icons.bookmark,
                              color: _kOrange,
                              size: 16,
                            )
                          : null,
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
        title: const Text(
          'Tìm chương',
          style: TextStyle(color: Colors.white, fontSize: 15),
        ),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Số chương hoặc tiêu đề...',
            prefixIcon: Icon(Icons.search, size: 18),
          ),
          onSubmitted: (v) {
            setState(() => _chapterSearch = v);
            Navigator.pop(ctx);
          },
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() => _chapterSearch = '');
              Navigator.pop(ctx);
            },
            child: const Text('Xóa', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() => _chapterSearch = ctrl.text);
              Navigator.pop(ctx);
            },
            child: const Text('Tìm'),
          ),
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
      return const Center(
        child: Text(
          'Không có cover art.',
          style: TextStyle(color: Colors.white38),
        ),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.68,
      ),
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
                CachedNetworkImage(
                  imageUrl: cover['urlSmall'],
                  fit: BoxFit.cover,
                  placeholder: (_, _) => Container(color: _kCard),
                ),
                if (cover['volume'].toString().isNotEmpty)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.8),
                          ],
                        ),
                      ),
                      child: Text(
                        'Vol. ${cover['volume']}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
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

  Widget _buildCommentsTab() {
    final auth = context.watch<AuthProvider>();
    final isLoggedIn = auth.isAuthenticated;
    final canPost =
        isLoggedIn &&
        !_postingComment &&
        _commentController.text.trim().length >= 5;

    return RefreshIndicator(
      color: _kOrange,
      onRefresh: () => _loadComments(force: true),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _kCard,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _commentController,
                  enabled: isLoggedIn && !_postingComment,
                  minLines: 3,
                  maxLines: 6,
                  style: const TextStyle(color: Colors.white),
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: isLoggedIn
                        ? 'Viet binh luan...'
                        : 'Dang nhap de binh luan',
                    hintStyle: const TextStyle(color: Colors.white38),
                    filled: true,
                    fillColor: const Color(0xFF1E1E1E),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Checkbox(
                      value: _commentIsSpoiler,
                      activeColor: _kOrange,
                      onChanged: isLoggedIn
                          ? (value) {
                              setState(
                                () => _commentIsSpoiler = value ?? false,
                              );
                            }
                          : null,
                    ),
                    const Text(
                      'Danh dau spoiler',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                    const Spacer(),
                    ElevatedButton.icon(
                      onPressed: canPost ? _postComment : null,
                      icon: _postingComment
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.send_rounded, size: 16),
                      label: const Text('Dang'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _kOrange,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (_commentsLoading && _comments.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator(color: _kOrange)),
            )
          else if (_comments.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                child: Text(
                  'Chua co binh luan nao.',
                  style: TextStyle(color: Colors.white38),
                ),
              ),
            )
          else
            ..._comments.map((comment) => _buildCommentItem(comment, auth)),
        ],
      ),
    );
  }

  Widget _buildCommentItem(Map<String, dynamic> comment, AuthProvider auth) {
    final id = _commentIdOf(comment);
    final userId = _commentUserIdOf(comment);
    final canManage = auth.user?.userId == userId;
    final username = _commentText(comment, 'Username', 'username').isNotEmpty
        ? _commentText(comment, 'Username', 'username')
        : 'User';
    final content = _commentText(comment, 'Content', 'content');
    final createdAt = _commentText(comment, 'CreatedAt', 'created_at');
    final isSpoiler = _commentBool(comment, 'IsSpoiler', 'is_spoiler');
    final revealed = !isSpoiler || _revealedSpoilers.contains(id);
    final likeCount = _commentInt(comment, 'LikeCount', 'like_count');
    final dislikeCount = _commentInt(comment, 'DislikeCount', 'dislike_count');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: _kOrange.withValues(alpha: 0.18),
            child: Text(
              username.isEmpty ? '?' : username[0].toUpperCase(),
              style: const TextStyle(
                color: _kOrange,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 10),
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
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (createdAt.isNotEmpty)
                      Text(
                        createdAt.split('T').first,
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 11,
                        ),
                      ),
                  ],
                ),
                if (isSpoiler)
                  Container(
                    margin: const EdgeInsets.only(top: 6),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      'Spoiler',
                      style: TextStyle(color: Color(0xFFF59E0B), fontSize: 11),
                    ),
                  ),
                const SizedBox(height: 8),
                if (!revealed)
                  TextButton.icon(
                    onPressed: () => setState(() => _revealedSpoilers.add(id)),
                    icon: const Icon(Icons.visibility_outlined, size: 16),
                    label: const Text('Hien spoiler'),
                    style: TextButton.styleFrom(foregroundColor: _kOrange),
                  )
                else
                  Text(
                    content,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      height: 1.45,
                    ),
                  ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    TextButton.icon(
                      onPressed: auth.isAuthenticated
                          ? () => _toggleCommentReaction(comment, true)
                          : null,
                      icon: const Icon(Icons.thumb_up_alt_outlined, size: 15),
                      label: Text('$likeCount'),
                    ),
                    TextButton.icon(
                      onPressed: auth.isAuthenticated
                          ? () => _toggleCommentReaction(comment, false)
                          : null,
                      icon: const Icon(Icons.thumb_down_alt_outlined, size: 15),
                      label: Text('$dislikeCount'),
                    ),
                    if (canManage)
                      TextButton.icon(
                        onPressed: () => _showEditCommentDialog(comment),
                        icon: const Icon(Icons.edit_outlined, size: 15),
                        label: const Text('Sua'),
                      ),
                    if (canManage)
                      TextButton.icon(
                        onPressed: () => _deleteComment(comment),
                        icon: const Icon(Icons.delete_outline, size: 15),
                        label: const Text('Xoa'),
                      ),
                    TextButton.icon(
                      onPressed: auth.isAuthenticated
                          ? () => _showReportCommentDialog(comment)
                          : null,
                      icon: const Icon(Icons.flag_outlined, size: 15),
                      label: const Text('Bao cao'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendationsTab() {
    if (_recommendationsLoading && _recommendations.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: _kOrange));
    }
    if (_recommendations.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.auto_awesome, color: Colors.white24, size: 48),
              const SizedBox(height: 12),
              const Text(
                'Chua co goi y tuong tu.',
                style: TextStyle(color: Colors.white38),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: () => _loadRecommendations(force: true),
                icon: const Icon(Icons.refresh),
                label: const Text('Thu lai'),
              ),
            ],
          ),
        ),
      );
    }
    return RefreshIndicator(
      color: _kOrange,
      onRefresh: () => _loadRecommendations(force: true),
      child: GridView.builder(
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 8,
          mainAxisSpacing: 12,
          childAspectRatio: 0.58,
        ),
        itemCount: _recommendations.length,
        itemBuilder: (_, index) {
          final manga = _recommendations[index];
          return GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => DetailScreen(manga: manga)),
              );
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: CachedNetworkImage(
                      imageUrl: manga.coverUrl,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      placeholder: (_, _) => Container(color: _kCard),
                      errorWidget: (_, _, _) => Container(
                        color: _kCard,
                        child: const Icon(
                          Icons.image_not_supported,
                          color: Colors.white24,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  manga.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          );
        },
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
    final colors = {
      'ongoing': const Color(0xFF22C55E),
      'completed': const Color(0xFF3B82F6),
      'hiatus': const Color(0xFFF59E0B),
      'cancelled': const Color(0xFFEF4444),
    };
    final color = colors[status.toLowerCase()] ?? Colors.grey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(9999),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
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
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(9999),
      ),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          color: Colors.white54,
          fontSize: 9,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ActionBtn({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF2A2A2A),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white70, size: 18),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(color: Colors.white54, fontSize: 9),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  final String label;
  final String value;
  const _MetaRow({required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(color: Colors.white38, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _ClickableMetaRow extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;

  const _ClickableMetaRow({
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(color: Colors.white38, fontSize: 13),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: onTap,
              child: Text(
                value,
                style: const TextStyle(
                  color: _kOrange,
                  fontSize: 13,
                  decoration: TextDecoration.underline,
                  decorationColor: _kOrange,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  final String label;
  final Color color;
  const _TagChip({required this.label, required this.color});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(9999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _DownloadOptionsSheet extends StatefulWidget {
  const _DownloadOptionsSheet({required this.manga, required this.chapters});

  final Manga manga;
  final List<Map<String, dynamic>> chapters;

  @override
  State<_DownloadOptionsSheet> createState() => _DownloadOptionsSheetState();
}

class _DownloadOptionsSheetState extends State<_DownloadOptionsSheet> {
  DownloadLanguage _language = DownloadLanguage.english;
  DownloadFormat _format = DownloadFormat.folderPerChapter;
  DownloadQuality _quality = DownloadQuality.standard;
  bool _allChapters = true;
  final Set<String> _selectedChapterIds = {};
  bool _isDownloading = false;
  double _progress = 0;
  String _progressStatus = '';

  List<Map<String, dynamic>> get _filteredChapters {
    return widget.chapters.where((chapter) {
      final lang = chapter['language']?.toString() ?? '';
      if (_language == DownloadLanguage.english) return lang == 'en';
      if (_language == DownloadLanguage.vietnamese) return lang == 'vi';
      return true;
    }).toList();
  }

  List<Map<String, dynamic>> get _chaptersToDownload {
    if (_allChapters) return _filteredChapters;
    return _filteredChapters
        .where(
          (chapter) => _selectedChapterIds.contains(chapter['id']?.toString()),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.86,
      maxChildSize: 0.96,
      minChildSize: 0.45,
      builder: (context, controller) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1E1E1E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: _isDownloading ? _buildProgress() : _buildOptions(controller),
      ),
    );
  }

  Widget _buildOptions(ScrollController controller) {
    return ListView(
      controller: controller,
      padding: const EdgeInsets.all(20),
      children: [
        Center(
          child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            const Icon(Icons.download_rounded, color: _kOrange),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Tai manga: ${widget.manga.title}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        const _DownloadSectionLabel('Ngon ngu'),
        _DownloadRadioGroup<DownloadLanguage>(
          value: _language,
          options: const [
            MapEntry(DownloadLanguage.english, 'Tieng Anh (en)'),
            MapEntry(DownloadLanguage.vietnamese, 'Tieng Viet (vi)'),
            MapEntry(DownloadLanguage.all, 'Tat ca ngon ngu'),
          ],
          onChanged: (value) {
            setState(() {
              _language = value;
              _selectedChapterIds.clear();
            });
          },
        ),
        const SizedBox(height: 12),
        const _DownloadSectionLabel('Dinh dang'),
        _DownloadRadioGroup<DownloadFormat>(
          value: _format,
          options: const [
            MapEntry(DownloadFormat.folderPerChapter, 'Thu muc theo chapter'),
            MapEntry(DownloadFormat.chapterPdf, 'Zip anh theo chapter'),
            MapEntry(DownloadFormat.fullMangaPdf, 'Gop tat ca trang'),
          ],
          onChanged: (value) => setState(() => _format = value),
        ),
        const SizedBox(height: 12),
        const _DownloadSectionLabel('Chat luong anh'),
        _DownloadRadioGroup<DownloadQuality>(
          value: _quality,
          options: const [
            MapEntry(DownloadQuality.standard, 'Standard'),
            MapEntry(DownloadQuality.dataSaver, 'Data saver'),
          ],
          onChanged: (value) => setState(() => _quality = value),
        ),
        const SizedBox(height: 12),
        const _DownloadSectionLabel('Chapter'),
        CheckboxListTile(
          value: _allChapters,
          dense: true,
          contentPadding: EdgeInsets.zero,
          activeColor: _kOrange,
          title: Text(
            'Tat ca (${_filteredChapters.length} chapter)',
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          onChanged: (value) {
            setState(() {
              _allChapters = value ?? true;
              _selectedChapterIds.clear();
            });
          },
        ),
        if (!_allChapters)
          Container(
            height: 220,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: ListView.builder(
              itemCount: _filteredChapters.length,
              itemBuilder: (_, index) {
                final chapter = _filteredChapters[index];
                final id = chapter['id']?.toString() ?? '';
                final title = chapter['title']?.toString() ?? '';
                return CheckboxListTile(
                  dense: true,
                  value: _selectedChapterIds.contains(id),
                  activeColor: _kOrange,
                  title: Text(
                    'Ch. ${chapter['chapter']}${title.isEmpty ? '' : ' - $title'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  onChanged: (value) {
                    setState(() {
                      if (value == true) {
                        _selectedChapterIds.add(id);
                      } else {
                        _selectedChapterIds.remove(id);
                      }
                    });
                  },
                );
              },
            ),
          ),
        const SizedBox(height: 8),
        Text(
          '${_chaptersToDownload.length} chapter se duoc tai',
          style: const TextStyle(color: Colors.white38, fontSize: 12),
        ),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          onPressed: _chaptersToDownload.isEmpty ? null : _startDownload,
          icon: const Icon(Icons.download_rounded),
          label: Text('Tai xuong (${_chaptersToDownload.length})'),
          style: ElevatedButton.styleFrom(
            backgroundColor: _kOrange,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Chi su dung noi dung tai ve cho muc dich ca nhan.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white24, fontSize: 11),
        ),
      ],
    );
  }

  Widget _buildProgress() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.downloading_rounded, color: _kOrange, size: 60),
          const SizedBox(height: 20),
          Text(
            'Dang tai ${widget.manga.title}',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 20),
          LinearProgressIndicator(
            value: _progress,
            color: _kOrange,
            backgroundColor: Colors.white12,
            minHeight: 6,
            borderRadius: BorderRadius.circular(3),
          ),
          const SizedBox(height: 10),
          Text(
            '${(_progress * 100).toInt()}%',
            style: const TextStyle(
              color: _kOrange,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _progressStatus,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Future<void> _startDownload() async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      await Permission.storage.request();
      await Permission.photos.request();
    }

    setState(() {
      _isDownloading = true;
      _progress = 0;
      _progressStatus = '';
    });

    try {
      await MangaDownloadService.downloadManga(
        MangaDownloadOptions(
          language: _language,
          format: _format,
          quality: _quality,
          selectedChapters: _chaptersToDownload,
          mangaTitle: widget.manga.title,
        ),
        onProgress: (progress, status) {
          if (!mounted) return;
          setState(() {
            _progress = progress;
            _progressStatus = status;
          });
        },
      );
      if (!mounted) return;
      Navigator.pop(context);
      // Trên web: browser tự mở dialog lưu file — không cần Share.
      // Trên native: share sheet đã được mở bên trong MangaDownloadService.
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi tải manga: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

class _DownloadSectionLabel extends StatelessWidget {
  const _DownloadSectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );
  }
}

class _DownloadRadioGroup<T> extends StatelessWidget {
  const _DownloadRadioGroup({
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final T value;
  final List<MapEntry<T, String>> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: options.map((option) {
        final isSelected = option.key == value;
        return InkWell(
          onTap: () => onChanged(option.key),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Icon(
                  isSelected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: isSelected ? _kOrange : Colors.white38,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    option.value,
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
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
    final listsContaining = await provider.getListsContainingManga(
      widget.manga.id,
    );
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
    final addFutures = _selectedListsToAdd.map(
      (listId) => provider.addMangaToList(listId, widget.manga),
    );
    await Future.wait(addFutures);

    // Process removals
    final removeFutures = _selectedListsToRemove.map(
      (listId) =>
          provider.removeMangaFromListByMangaId(listId, widget.manga.id),
    );
    await Future.wait(removeFutures);

    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Đã cập nhật danh sách!'),
        backgroundColor: Colors.green,
      ),
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
                const Text(
                  'Lưu vào danh sách',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(
                    _isGridView ? Icons.view_list : Icons.grid_view,
                    color: Colors.white70,
                  ),
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
                ? const Center(
                    child: CircularProgressIndicator(color: _kOrange),
                  )
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
                  onPressed:
                      (_selectedListsToAdd.isEmpty &&
                          _selectedListsToRemove.isEmpty)
                      ? null
                      : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kOrange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    disabledBackgroundColor: Colors.white12,
                    disabledForegroundColor: Colors.white38,
                  ),
                  child: const Text(
                    'Xác nhận',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
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
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _kOrange.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.folder_special, color: _kOrange, size: 20),
          ),
          title: Text(
            lst['name'],
            style: const TextStyle(color: Colors.white, fontSize: 15),
          ),
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
              color: isSelected
                  ? _kOrange.withValues(alpha: 0.1)
                  : const Color(0xFF2A2A2A),
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
                      const Icon(
                        Icons.circle_outlined,
                        color: Colors.white38,
                        size: 20,
                      ),
                  ],
                ),
                const Spacer(),
                Text(
                  lst['name'],
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
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
