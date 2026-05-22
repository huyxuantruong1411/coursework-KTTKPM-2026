class MangaListBrief {
  final String listId;
  final String name;
  final String? description;
  final String visibility; // 'public' | 'private'
  final int itemCount;
  final int followerCount;
  final String? coverUrl;
  final DateTime? updatedAt;
  final bool? containsManga;

  bool? get contains => containsManga;

  MangaListBrief({
    required this.listId,
    required this.name,
    this.description,
    this.visibility = 'private',
    this.itemCount = 0,
    this.followerCount = 0,
    this.coverUrl,
    this.updatedAt,
    this.containsManga,
  });

  factory MangaListBrief.fromJson(Map<String, dynamic> json) {
    return MangaListBrief(
      listId: json['ListId']?.toString() ?? json['list_id']?.toString() ?? '',
      name: json['Name'] ?? json['name'] ?? '',
      description: json['Description'] ?? json['description'],
      visibility: json['Visibility'] ?? json['visibility'] ?? 'private',
      itemCount: json['ItemCount'] ?? json['item_count'] ?? 0,
      followerCount: json['FollowerCount'] ?? json['follower_count'] ?? 0,
      coverUrl: json['CoverUrl'] ?? json['cover_url'],
      updatedAt: json['UpdatedAt'] != null
          ? DateTime.tryParse(json['UpdatedAt'])
          : json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'])
          : null,
      containsManga:
          json['contains_manga'] as bool? ?? json['contains'] as bool?,
    );
  }
}

class MangaListDetail {
  final String listId;
  final String name;
  final String? description;
  final String visibility;
  final String ownerId;
  final String? ownerUsername;
  final int itemCount;
  final int followerCount;
  final List<ListMangaItem> items;
  final String? coverUrl;

  MangaListDetail({
    required this.listId,
    required this.name,
    this.description,
    this.visibility = 'private',
    required this.ownerId,
    this.ownerUsername,
    this.itemCount = 0,
    this.followerCount = 0,
    this.items = const [],
    this.coverUrl,
  });

  factory MangaListDetail.fromJson(Map<String, dynamic> json) {
    final itemsJson = json['items'] as List? ?? [];
    return MangaListDetail(
      listId: json['ListId']?.toString() ?? json['list_id']?.toString() ?? '',
      name: json['Name'] ?? json['name'] ?? '',
      description: json['Description'] ?? json['description'],
      visibility: json['Visibility'] ?? json['visibility'] ?? 'private',
      ownerId:
          json['OwnerId']?.toString() ?? json['owner_id']?.toString() ?? '',
      ownerUsername: json['OwnerUsername'] ?? json['owner_username'],
      itemCount: json['ItemCount'] ?? json['item_count'] ?? 0,
      followerCount: json['FollowerCount'] ?? json['follower_count'] ?? 0,
      items: itemsJson
          .map((e) => ListMangaItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      coverUrl: json['CoverUrl'] ?? json['cover_url'],
    );
  }
}

class ListMangaItem {
  final String mangaId;
  final String? title;
  final String? coverUrl;
  final String? status;
  final int? year;
  final String? contentRating;
  final int position;

  ListMangaItem({
    required this.mangaId,
    this.title,
    this.coverUrl,
    this.status,
    this.year,
    this.contentRating,
    this.position = 0,
  });

  factory ListMangaItem.fromJson(Map<String, dynamic> json) {
    return ListMangaItem(
      mangaId:
          json['MangaId']?.toString() ?? json['manga_id']?.toString() ?? '',
      title: json['TitleEn'] ?? json['title'] ?? json['Title'],
      coverUrl: json['cover_url'] ?? json['CoverUrl'],
      status: json['Status'] ?? json['status'],
      year: json['Year'] ?? json['year'],
      contentRating: json['ContentRating'] ?? json['content_rating'],
      position: json['Position'] ?? json['position'] ?? 0,
    );
  }
}
