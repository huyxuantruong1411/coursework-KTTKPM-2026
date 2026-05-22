import 'package:flutter/material.dart';
import '../../models/manga.dart';
import '../../services/creator_service.dart';
import '../../services/mangadex_api.dart';
import '../detail/detail_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';

const _kOrange = Color(0xFFFF6740);
const _kBg = Color(0xFF121212);
const _kCard = Color(0xFF2C2C2C);

class CreatorScreen extends StatefulWidget {
  final String? creatorId;
  final String creatorName;

  const CreatorScreen({
    super.key,
    this.creatorId,
    required this.creatorName,
  });

  @override
  State<CreatorScreen> createState() => _CreatorScreenState();
}

class _CreatorScreenState extends State<CreatorScreen> {
  List<Manga> _mangas = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMangas();
  }

  Future<void> _loadMangas() async {
    try {
      List<Manga> list;
      if (widget.creatorId != null && widget.creatorId!.isNotEmpty) {
        final res = await CreatorService.getCreatorDetail(widget.creatorId!);
        final items = ((res?['mangas']?['items'] ?? []) as List)
            .cast<Map<String, dynamic>>();
        list = items.map(Manga.fromJson).toList();
      } else {
        list = await MangaDexApi().searchManga(
          query: widget.creatorName,
          limit: 20,
        );
      }
      if (mounted) {
        setState(() {
          _mangas = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kCard,
        title: Text(widget.creatorName, style: const TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _kOrange))
          : _mangas.isEmpty
              ? const Center(child: Text('Không tìm thấy tác phẩm nào.', style: TextStyle(color: Colors.white54)))
              : GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: 0.62,
                  ),
                  itemCount: _mangas.length,
                  itemBuilder: (ctx, i) {
                    final m = _mangas[i];
                    return GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => DetailScreen(manga: m)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: CachedNetworkImage(
                                imageUrl: m.coverUrl,
                                fit: BoxFit.cover,
                                placeholder: (ctx, url) => Container(color: _kCard),
                                errorWidget: (ctx, url, e) => Container(color: _kCard),
                              ),
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            m.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
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
