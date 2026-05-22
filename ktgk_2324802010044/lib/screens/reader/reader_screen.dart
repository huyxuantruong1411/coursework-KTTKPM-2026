import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../../services/chapter_service.dart';
import '../../widgets/chapter_page_image.dart';

const _kOrange = Color(0xFFFF6740);

enum _ReadMode { longStrip, singlePage }

/// Per-page translation status.
enum _TranslateStatus { idle, loading, done, error }

class ReaderScreen extends StatefulWidget {
  final String chapterId;
  final String chapterTitle;
  final String mangaId;
  final String mangaTitle;
  final String mangaCoverUrl;
  final List<Map<String, dynamic>> chapters;
  final int currentChapterIndex;
  final String currentLanguage;

  const ReaderScreen({
    super.key,
    required this.chapterId,
    required this.chapterTitle,
    this.mangaId = '',
    this.mangaTitle = '',
    this.mangaCoverUrl = '',
    this.chapters = const [],
    this.currentChapterIndex = -1,
    this.currentLanguage = 'en',
  });

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  List<String> _imageUrls = [];
  bool _isLoading = true;
  bool _showUi = false;
  _ReadMode _readMode = _ReadMode.longStrip;
  int _currentPage = 0;
  late PageController _pageController;
  late ScrollController _scrollController;
  late String _currentChapterId;
  late String _currentChapterTitle;
  late int _currentChapterIndex;

  // ── Translation state ─────────────────────────────────────────────────────
  /// Maps page index (0-based) → translated image URL.
  final Map<int, String> _translatedUrls = {};

  /// Maps page index (0-based) → current translation status.
  final Map<int, _TranslateStatus> _translateStatus = {};

  /// Currently selected target language code.
  String _targetLang = 'vi';

  /// Whether a bulk "translate all" operation is in progress.
  bool _isTranslatingAll = false;

  /// Number of pages completed during a "translate all" batch.
  int _translateAllCompleted = 0;

  @override
  void initState() {
    super.initState();
    _currentChapterId = widget.chapterId;
    _currentChapterTitle = widget.chapterTitle;
    _currentChapterIndex = widget.currentChapterIndex;
    _pageController = PageController();
    _scrollController = ScrollController();
    _fetchImages();
    _saveHistory();
    // Immersive mode
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _scrollController.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  Future<void> _fetchImages() async {
    await _fetchImagesForChapter(_currentChapterId);
  }

  Future<void> _fetchImagesForChapter(String chapterId) async {
    if (mounted) setState(() => _isLoading = true);
    final urls = await ChapterService.getChapterPages(chapterId);
    if (mounted && _currentChapterId == chapterId) {
      setState(() {
        _imageUrls = urls;
        _isLoading = false;
        _currentPage = 0;
        // Clear translation state when chapter changes
        _translatedUrls.clear();
        _translateStatus.clear();
      });
      _resetReaderPosition();
    }
  }

  void _resetReaderPosition() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_readMode == _ReadMode.longStrip && _scrollController.hasClients) {
        _scrollController.jumpTo(0);
      } else if (_readMode == _ReadMode.singlePage &&
          _pageController.hasClients) {
        _pageController.jumpToPage(0);
      }
    });
  }

  void _saveHistory() {
    if (widget.mangaId.isEmpty) return;
    context.read<AppProvider>().saveReadingHistory(
      mangaId: widget.mangaId,
      mangaTitle: widget.mangaTitle,
      mangaCoverUrl: widget.mangaCoverUrl,
      chapterId: _currentChapterId,
      chapterNumber: _currentChapterTitle,
      chapterTitle:
          _currentChapterIndex >= 0 &&
              _currentChapterIndex < widget.chapters.length
          ? widget.chapters[_currentChapterIndex]['title'] ?? ''
          : '',
      pageIndex: _currentPage,
    );
  }

  // ── Translation helpers ───────────────────────────────────────────────────

  /// Resolve which URL to display for a page (translated or original).
  String _resolveUrl(int index) {
    final translated = _translatedUrls[index];
    if (translated != null && translated.isNotEmpty) return translated;
    return _imageUrls[index];
  }

  /// Translate a single page by its 0-based index.
  Future<void> _translatePageAtIndex(int index) async {
    if (index < 0 || index >= _imageUrls.length) return;

    final status = _translateStatus[index];
    // Skip if already loading or done
    if (status == _TranslateStatus.loading) return;
    if (status == _TranslateStatus.done) return;

    final originalUrl = _imageUrls[index];

    setState(() => _translateStatus[index] = _TranslateStatus.loading);

    final translatedUrl = await ChapterService.translatePage(
      originalUrl,
      targetLang: _targetLang,
      sourceLang: widget.currentLanguage,
    );

    if (!mounted) return;

    if (translatedUrl != null) {
      setState(() {
        _translatedUrls[index] = translatedUrl;
        _translateStatus[index] = _TranslateStatus.done;
      });
    } else {
      setState(() => _translateStatus[index] = _TranslateStatus.error);
    }
  }

  /// Reset a single page back to the original (remove its translation).
  void _resetPageTranslation(int index) {
    setState(() {
      _translatedUrls.remove(index);
      _translateStatus.remove(index);
    });
  }

  /// Translate all pages of the current chapter sequentially.
  Future<void> _translateAllPages() async {
    if (_isTranslatingAll) return;
    setState(() {
      _isTranslatingAll = true;
      _translateAllCompleted = 0;
    });
    for (var i = 0; i < _imageUrls.length; i++) {
      if (!mounted) break;
      await _translatePageAtIndex(i);
      if (mounted) {
        setState(() => _translateAllCompleted = i + 1);
      }
    }
    if (mounted) setState(() => _isTranslatingAll = false);
  }

  /// Reset all translations (revert chapter to original images).
  void _resetAllTranslations() {
    setState(() {
      _translatedUrls.clear();
      _translateStatus.clear();
    });
  }

  /// Show a bottom sheet to pick the target translation language.
  void _showLangPicker() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF2A2A2A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Text(
                'Dịch sang ngôn ngữ',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const Divider(color: Colors.white12, height: 1),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: kTranslateLangs.length,
                itemBuilder: (ctx2, i) {
                  final lang = kTranslateLangs[i];
                  final isSelected = lang['code'] == _targetLang;
                  return ListTile(
                    dense: true,
                    tileColor: isSelected
                        ? _kOrange.withValues(alpha: 0.1)
                        : null,
                    title: Text(
                      lang['label']!,
                      style: TextStyle(
                        color: isSelected ? _kOrange : Colors.white,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                    trailing: isSelected
                        ? const Icon(Icons.check, color: _kOrange, size: 18)
                        : null,
                    onTap: () {
                      Navigator.pop(ctx);
                      if (lang['code'] != _targetLang) {
                        setState(() {
                          _targetLang = lang['code']!;
                          // Clear existing translations because language changed
                          _translatedUrls.clear();
                          _translateStatus.clear();
                        });
                      }
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ── Translate button widget ───────────────────────────────────────────────

  Widget _buildTranslateButton(int index) {
    final status = _translateStatus[index] ?? _TranslateStatus.idle;
    final isDone = status == _TranslateStatus.done;
    final isLoading = status == _TranslateStatus.loading;
    final isError = status == _TranslateStatus.error;

    if (isLoading) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(color: _kOrange, strokeWidth: 2),
            ),
            SizedBox(width: 6),
            Text(
              'AI dịch...',
              style: TextStyle(color: Colors.white70, fontSize: 11),
            ),
          ],
        ),
      );
    }

    if (isDone) {
      return GestureDetector(
        onTap: () => _resetPageTranslation(index),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: _kOrange.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.refresh, color: Colors.white, size: 13),
              SizedBox(width: 4),
              Text(
                'Gốc',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: () => _translatePageAtIndex(index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isError ? Colors.red.withValues(alpha: 0.75) : Colors.black54,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.translate,
              color: Colors.white,
              size: 13,
            ),
            const SizedBox(width: 4),
            Text(
              isError ? 'Thử lại' : 'Dịch',
              style: const TextStyle(color: Colors.white, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  // ── Chapter navigation ────────────────────────────────────────────────────

  List<Map<String, dynamic>> get _chapterSequence {
    final indexed = <Map<String, dynamic>>[];
    for (var i = 0; i < widget.chapters.length; i++) {
      final chapter = widget.chapters[i];
      if (chapter['id']?.toString().isEmpty ?? true) continue;
      indexed.add({...chapter, '_originalIndex': i});
    }

    final sameLanguage = indexed
        .where((c) => c['language']?.toString() == widget.currentLanguage)
        .toList();
    final sequence = sameLanguage.isNotEmpty ? sameLanguage : indexed;
    sequence.sort((a, b) {
      final aNum = double.tryParse(a['chapter']?.toString() ?? '');
      final bNum = double.tryParse(b['chapter']?.toString() ?? '');
      if (aNum != null && bNum != null && aNum != bNum) {
        return aNum.compareTo(bNum);
      }
      return (a['_originalIndex'] as int).compareTo(b['_originalIndex'] as int);
    });
    return sequence;
  }

  int get _currentSequenceIndex {
    return _chapterSequence.indexWhere((c) => c['id'] == _currentChapterId);
  }

  bool get _hasPrev => _currentSequenceIndex > 0;
  bool get _hasNext {
    final index = _currentSequenceIndex;
    return index >= 0 && index < _chapterSequence.length - 1;
  }

  int? _adjacentOriginalIndex(int delta) {
    final sequence = _chapterSequence;
    final current = sequence.indexWhere((c) => c['id'] == _currentChapterId);
    final target = current + delta;
    if (current < 0 || target < 0 || target >= sequence.length) return null;
    return sequence[target]['_originalIndex'] as int?;
  }

  void _goToAdjacentChapter(int delta) {
    final originalIndex = _adjacentOriginalIndex(delta);
    if (originalIndex == null) return;
    _goToChapter(originalIndex);
  }

  String? _adjacentChapterLabel(int delta) {
    final sequence = _chapterSequence;
    final current = sequence.indexWhere((c) => c['id'] == _currentChapterId);
    final target = current + delta;
    if (current < 0 || target < 0 || target >= sequence.length) return null;
    return sequence[target]['chapter']?.toString();
  }

  void _goToChapter(int index) {
    if (index < 0 || index >= widget.chapters.length) return;
    final chap = widget.chapters[index];
    final chapterId = chap['id'].toString();
    final chapterTitle = chap['chapter'].toString();
    setState(() {
      _currentChapterId = chapterId;
      _currentChapterTitle = chapterTitle;
      _currentChapterIndex = index;
      _currentPage = 0;
      _imageUrls = [];
      _isLoading = true;
    });
    _resetReaderPosition();
    _fetchImagesForChapter(chapterId);
    _saveHistory();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Main reader content
          GestureDetector(
            onTap: () => setState(() => _showUi = !_showUi),
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: _kOrange),
                  )
                : _imageUrls.isEmpty
                ? const Center(
                    child: Text(
                      'Không thể tải hình ảnh!',
                      style: TextStyle(color: Colors.white),
                    ),
                  )
                : _readMode == _ReadMode.longStrip
                ? _buildLongStrip()
                : _buildSinglePage(),
          ),

          // Top bar
          if (_showUi)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.9),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (widget.mangaTitle.isNotEmpty)
                            Text(
                              widget.mangaTitle,
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 11,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          Text(
                            'Chương $_currentChapterTitle',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // ── Translation controls ──────────────────────────────
                    // Language picker button
                    IconButton(
                      icon: const Icon(
                        Icons.translate,
                        color: Colors.white70,
                        size: 22,
                      ),
                      tooltip: 'Chọn ngôn ngữ dịch ($_targetLang)',
                      onPressed: _showLangPicker,
                    ),
                    // Translate all / reset all button
                    _isTranslatingAll
                        ? Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    color: _kOrange,
                                    strokeWidth: 2,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '$_translateAllCompleted/${_imageUrls.length}',
                                  style: const TextStyle(
                                    color: _kOrange,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : IconButton(
                            icon: Icon(
                              _translatedUrls.isEmpty
                                  ? Icons.auto_fix_high
                                  : Icons.undo,
                              color: _translatedUrls.isEmpty
                                  ? Colors.white70
                                  : _kOrange,
                              size: 22,
                            ),
                            tooltip: _translatedUrls.isEmpty
                                ? 'Dịch tất cả trang'
                                : 'Về bản gốc',
                            onPressed: _imageUrls.isEmpty
                                ? null
                                : _translatedUrls.isEmpty
                                ? _translateAllPages
                                : _resetAllTranslations,
                          ),
                    // ── Existing controls ─────────────────────────────────
                    IconButton(
                      icon: const Icon(
                        Icons.format_list_bulleted,
                        color: Colors.white70,
                        size: 22,
                      ),
                      onPressed: _showChapterDrawer,
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.settings,
                        color: Colors.white70,
                        size: 22,
                      ),
                      onPressed: _showSettings,
                    ),
                  ],
                ),
              ),
            ),

          // Bottom bar
          if (_showUi)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).padding.bottom + 8,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.9),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Page indicator + slider
                    if (_imageUrls.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            Text(
                              '${_currentPage + 1}',
                              style: const TextStyle(
                                color: _kOrange,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Expanded(
                              child: SliderTheme(
                                data: SliderThemeData(
                                  activeTrackColor: _kOrange,
                                  inactiveTrackColor: Colors.white24,
                                  thumbColor: _kOrange,
                                  thumbShape: const RoundSliderThumbShape(
                                    enabledThumbRadius: 6,
                                  ),
                                  trackHeight: 3,
                                  overlayShape: const RoundSliderOverlayShape(
                                    overlayRadius: 14,
                                  ),
                                ),
                                child: Slider(
                                  min: 0,
                                  max: (_imageUrls.length - 1).toDouble(),
                                  value: _currentPage.toDouble().clamp(
                                    0,
                                    (_imageUrls.length - 1).toDouble(),
                                  ),
                                  onChanged: (v) {
                                    final page = v.round();
                                    setState(() => _currentPage = page);
                                    if (_readMode == _ReadMode.singlePage) {
                                      _pageController.jumpToPage(page);
                                    }
                                  },
                                ),
                              ),
                            ),
                            Text(
                              '${_imageUrls.length}',
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    // Chapter navigation
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextButton.icon(
                            onPressed: _hasPrev
                                ? () => _goToAdjacentChapter(-1)
                                : null,
                            icon: const Icon(Icons.skip_previous, size: 20),
                            label: const Text(
                              'Chương trước',
                              style: TextStyle(fontSize: 12),
                            ),
                            style: TextButton.styleFrom(
                              foregroundColor: _hasPrev
                                  ? _kOrange
                                  : Colors.white24,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(9999),
                            ),
                            child: Text(
                              'Ch. $_currentChapterTitle',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          TextButton.icon(
                            onPressed: _hasNext
                                ? () => _goToAdjacentChapter(1)
                                : null,
                            icon: const Text(
                              'Chương sau',
                              style: TextStyle(fontSize: 12),
                            ),
                            label: const Icon(Icons.skip_next, size: 20),
                            style: TextButton.styleFrom(
                              foregroundColor: _hasNext
                                  ? _kOrange
                                  : Colors.white24,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ---------- LONG STRIP MODE ----------
  Widget _buildLongStrip() {
    return InteractiveViewer(
      minScale: 1.0,
      maxScale: 3.0,
      child: NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (n is ScrollUpdateNotification && _imageUrls.isNotEmpty) {
            final scrollFraction = _scrollController.hasClients
                ? (_scrollController.offset /
                      (_scrollController.position.maxScrollExtent.clamp(
                        1,
                        double.infinity,
                      )))
                : 0.0;
            final page = (scrollFraction * _imageUrls.length).floor().clamp(
              0,
              _imageUrls.length - 1,
            );
            if (page != _currentPage) {
              setState(() => _currentPage = page);
            }
          }
          return false;
        },
        child: ListView.builder(
          controller: _scrollController,
          itemCount: _imageUrls.length + 1, // +1 for end card
          itemBuilder: (context, index) {
            if (index == _imageUrls.length) {
              return _buildEndCard();
            }

            final status = _translateStatus[index] ?? _TranslateStatus.idle;
            final isTranslating = status == _TranslateStatus.loading;
            final displayUrl = _resolveUrl(index);

            return Stack(
              alignment: Alignment.topRight,
              children: [
                // Page image (with optional loading overlay)
                isTranslating
                    ? Stack(
                        children: [
                          // Show original while translating
                          CachedNetworkImage(
                            imageUrl: _imageUrls[index],
                            fit: BoxFit.fitWidth,
                            width: double.infinity,
                            placeholder: (_, _) => const SizedBox(
                              height: 400,
                              child: Center(
                                child: CircularProgressIndicator(
                                  color: Colors.white24,
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                            errorWidget: (_, _, _) => const SizedBox(
                              height: 300,
                              child: Center(
                                child: Icon(
                                  Icons.broken_image,
                                  color: Colors.white24,
                                  size: 50,
                                ),
                              ),
                            ),
                          ),
                          // Translating overlay
                          Positioned.fill(
                            child: Container(
                              color: Colors.black54,
                              child: const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  CircularProgressIndicator(
                                    color: _kOrange,
                                    strokeWidth: 2,
                                  ),
                                  SizedBox(height: 12),
                                  Text(
                                    'Đang dịch...',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 13,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Có thể mất 10–20 giây',
                                    style: TextStyle(
                                      color: Colors.white38,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      )
                    : ChapterPageImage(
                        imageUrl: displayUrl,
                        pageIndex: index,
                        fit: BoxFit.fitWidth,
                        width: double.infinity,
                      ),
                // Translate button (top-right corner, hidden when UI is visible)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Opacity(
                    opacity: _showUi ? 1.0 : 0.0,
                    child: _buildTranslateButton(index),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // ---------- SINGLE PAGE MODE ----------
  Widget _buildSinglePage() {
    return PageView.builder(
      controller: _pageController,
      itemCount: _imageUrls.length + 1,
      onPageChanged: (page) =>
          setState(() => _currentPage = page.clamp(0, _imageUrls.length - 1)),
      itemBuilder: (context, index) {
        if (index == _imageUrls.length) {
          return _buildEndCard();
        }

        final status = _translateStatus[index] ?? _TranslateStatus.idle;
        final isTranslating = status == _TranslateStatus.loading;
        final displayUrl = _resolveUrl(index);

        return InteractiveViewer(
          minScale: 1.0,
          maxScale: 4.0,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Page image
              Center(
                child: isTranslating
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CachedNetworkImage(
                            imageUrl: _imageUrls[index],
                            fit: BoxFit.contain,
                            color: Colors.black38,
                            colorBlendMode: BlendMode.darken,
                            placeholder: (_, _) => const Center(
                              child: CircularProgressIndicator(
                                color: Colors.white24,
                                strokeWidth: 2,
                              ),
                            ),
                            errorWidget: (_, _, _) => const Center(
                              child: Icon(
                                Icons.broken_image,
                                color: Colors.white24,
                                size: 50,
                              ),
                            ),
                          ),
                          const Positioned.fill(
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CircularProgressIndicator(
                                    color: _kOrange,
                                    strokeWidth: 3,
                                  ),
                                  SizedBox(height: 16),
                                  Text(
                                    'Đang dịch trang...',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Có thể mất 10–20 giây',
                                    style: TextStyle(
                                      color: Colors.white54,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      )
                    : ChapterPageImage(
                        imageUrl: displayUrl,
                        pageIndex: index,
                        fit: BoxFit.contain,
                      ),
              ),
              // Translate button (top-right, shown when UI is visible)
              if (_showUi)
                Positioned(
                  top: MediaQuery.of(context).padding.top + 60,
                  right: 12,
                  child: _buildTranslateButton(index),
                ),
            ],
          ),
        );
      },
    );
  }

  // ---------- END CARD ----------
  Widget _buildEndCard() {
    return Container(
      height: 400,
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_outline, color: _kOrange, size: 48),
            const SizedBox(height: 16),
            Text(
              'Hoàn thành Ch. $_currentChapterTitle',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            if (_hasNext) ...[
              ElevatedButton.icon(
                onPressed: () => _goToAdjacentChapter(1),
                icon: const Icon(Icons.skip_next),
                label: Text('Ch. ${_adjacentChapterLabel(1) ?? ''}'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kOrange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white54,
                side: const BorderSide(color: Colors.white24),
              ),
              child: const Text('Quay lại chi tiết'),
            ),
          ],
        ),
      ),
    );
  }

  // ---------- SETTINGS ----------
  void _showSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF2A2A2A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setSheet) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Cài đặt đọc',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Chế độ đọc',
                style: TextStyle(color: Colors.white54, fontSize: 13),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _ModeBtn(
                    icon: Icons.view_day,
                    label: 'Cuộn dọc',
                    selected: _readMode == _ReadMode.longStrip,
                    onTap: () {
                      setState(() => _readMode = _ReadMode.longStrip);
                      setSheet(() {});
                    },
                  ),
                  const SizedBox(width: 10),
                  _ModeBtn(
                    icon: Icons.view_carousel,
                    label: 'Từng trang',
                    selected: _readMode == _ReadMode.singlePage,
                    onTap: () {
                      setState(() {
                        _readMode = _ReadMode.singlePage;
                        _pageController = PageController(
                          initialPage: _currentPage,
                        );
                      });
                      setSheet(() {});
                    },
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  // ---------- CHAPTER DRAWER ----------
  void _showChapterDrawer() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        builder: (_, scrollController) {
          return Container(
            decoration: const BoxDecoration(
              color: Color(0xFF1E1E1E),
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: _ChapterDrawerContent(
              chapters: widget.chapters,
              currentChapterId: _currentChapterId,
              currentLanguage: widget.currentLanguage,
              scrollController: scrollController,
              onChapterSelected: (index) {
                Navigator.pop(ctx);
                _goToChapter(index);
              },
            ),
          );
        },
      ),
    );
  }
}

// ── Chapter drawer ────────────────────────────────────────────────────────────

class _ChapterDrawerContent extends StatefulWidget {
  final List<Map<String, dynamic>> chapters;
  final String currentChapterId;
  final String currentLanguage;
  final ScrollController scrollController;
  final ValueChanged<int> onChapterSelected;

  const _ChapterDrawerContent({
    required this.chapters,
    required this.currentChapterId,
    required this.currentLanguage,
    required this.scrollController,
    required this.onChapterSelected,
  });

  @override
  State<_ChapterDrawerContent> createState() => _ChapterDrawerContentState();
}

class _ChapterDrawerContentState extends State<_ChapterDrawerContent> {
  String _searchQuery = '';
  bool _sortAsc = false;
  bool _showAllLanguages = false;

  @override
  Widget build(BuildContext context) {
    var filtered = widget.chapters;

    if (!_showAllLanguages) {
      filtered = filtered
          .where((c) => c['language'] == widget.currentLanguage)
          .toList();
    }

    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((c) {
        final ch = c['chapter'].toString().toLowerCase();
        final t = c['title'].toString().toLowerCase();
        final q = _searchQuery.toLowerCase();
        return ch.contains(q) || t.contains(q);
      }).toList();
    }

    if (!_sortAsc) {
      filtered = filtered.reversed.toList();
    }

    return Column(
      children: [
        // Handle
        Center(
          child: Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        // Toolbar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Tìm chương...',
                    hintStyle: const TextStyle(color: Colors.white54),
                    prefixIcon: const Icon(
                      Icons.search,
                      color: Colors.white54,
                      size: 20,
                    ),
                    isDense: true,
                    contentPadding: const EdgeInsets.all(8),
                    filled: true,
                    fillColor: const Color(0xFF2C2C2C),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (v) => setState(() => _searchQuery = v),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: Icon(
                  Icons.language,
                  color: _showAllLanguages ? _kOrange : Colors.white54,
                ),
                tooltip: 'Hiện tất cả ngôn ngữ',
                onPressed: () =>
                    setState(() => _showAllLanguages = !_showAllLanguages),
              ),
              IconButton(
                icon: Icon(
                  _sortAsc ? Icons.arrow_downward : Icons.arrow_upward,
                  color: Colors.white54,
                ),
                onPressed: () => setState(() => _sortAsc = !_sortAsc),
              ),
            ],
          ),
        ),
        const Divider(color: Colors.white12, height: 1),
        Expanded(
          child: filtered.isEmpty
              ? const Center(
                  child: Text(
                    'Không tìm thấy chương nào',
                    style: TextStyle(color: Colors.white54),
                  ),
                )
              : ListView.builder(
                  controller: widget.scrollController,
                  itemCount: filtered.length,
                  itemBuilder: (ctx, i) {
                    final chap = filtered[i];
                    final isCurrent = chap['id'] == widget.currentChapterId;
                    return ListTile(
                      dense: true,
                      tileColor: isCurrent
                          ? _kOrange.withValues(alpha: 0.1)
                          : null,
                      leading: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: isCurrent
                              ? _kOrange.withValues(alpha: 0.2)
                              : const Color(0xFF2C2C2C),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Center(
                          child: Text(
                            chap['language'].toString().toUpperCase(),
                            style: TextStyle(
                              color: isCurrent ? _kOrange : Colors.white54,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      title: Text(
                        'Ch. ${chap['chapter']} ${chap['title'].toString().isNotEmpty ? "— ${chap['title']}" : ""}',
                        style: TextStyle(
                          color: isCurrent ? _kOrange : Colors.white,
                          fontSize: 13,
                          fontWeight: isCurrent
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
                      trailing: isCurrent
                          ? const Icon(Icons.check, color: _kOrange, size: 18)
                          : null,
                      onTap: () {
                        final index = widget.chapters.indexWhere(
                          (c) => c['id'] == chap['id'],
                        );
                        if (index != -1) {
                          widget.onChapterSelected(index);
                        }
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }
}

// ── Mode button ───────────────────────────────────────────────────────────────

class _ModeBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _ModeBtn({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? _kOrange : const Color(0xFF3A3A3A),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: selected ? Colors.white : Colors.white54,
                size: 24,
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
      ),
    );
  }
}
