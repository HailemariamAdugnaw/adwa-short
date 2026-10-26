class ShortItem {
  ShortItem({
    required this.id,
    required this.seriesId,
    this.episodeId,
    required this.title,
    required this.verticalVideoUrl,
    this.description = '',
    this.tags = const [],
    this.likesCount = 0,
    this.isLiked = false,
    this.isSaved = false,
    this.isAccessible = true,
    this.accessReason,
    this.episodeNumber,
    this.seriesTitle,
    this.totalEpisodes = 0,
    this.averageRating,
    this.ratingCount,
    this.thumbnailUrl,
    this.durationSeconds = 0,
    this.coinCost = 10,
  });

  final String id;
  final String seriesId;
  final String? episodeId;
  final String title;
  final String verticalVideoUrl;
  final String description;
  final List<String> tags;
  final int likesCount;
  final bool isLiked;
  final bool isSaved;
  final bool isAccessible;
  final String? accessReason;
  final int? episodeNumber;
  final String? seriesTitle;
  final int totalEpisodes;
  final double? averageRating;
  final int? ratingCount;
  final String? thumbnailUrl;
  final int durationSeconds;
  final int coinCost;

  bool get isLocked => !isAccessible;

  factory ShortItem.fromJson(Map<String, dynamic> json) {
    final rawTags = json['tags'];
    List<String> tagList;
    if (rawTags is List) {
      tagList = rawTags
          .map((e) => e?.toString() ?? '')
          .where((s) => s.isNotEmpty)
          .toList();
    } else if (rawTags is String) {
      tagList = rawTags
          .split(',')
          .map((e) => e.trim())
          .where((s) => s.isNotEmpty)
          .toList();
    } else {
      tagList = const [];
    }
    final accessibleValue = json['is_accessible'];
    final bool accessible;
    if (accessibleValue is bool) {
      accessible = accessibleValue;
    } else if (accessibleValue == null) {
      accessible = true;
    } else {
      accessible = accessibleValue.toString() == 'true';
    }
    return ShortItem(
      id: (json['id'] ?? json['episode_id'])?.toString() ?? '',
      seriesId: json['series_id']?.toString() ?? '',
      episodeId: json['episode_id']?.toString(),
      title: json['title']?.toString() ?? 'Untitled',
      verticalVideoUrl:
          (json['vertical_video_url'] ?? json['video_url'])?.toString() ?? '',
      description: json['description']?.toString() ??
          json['series_title']?.toString() ??
          '',
      tags: tagList,
      likesCount: _asInt(json['likes_count']) ??
          _asInt(json['view_count']) ??
          0,
      isLiked: json['is_liked'] == true,
      isSaved: json['is_saved'] == true,
      isAccessible: accessible,
      accessReason: json['access_reason']?.toString(),
      episodeNumber: _asInt(json['episode_number']) ?? _asInt(json['number']),
      seriesTitle: json['series_title']?.toString(),
      totalEpisodes: _asInt(json['total_episodes']) ??
          _asInt(json['episode_count']) ??
          0,
      averageRating: _asDouble(json['average_rating']),
      ratingCount: _asInt(json['rating_count']),
      thumbnailUrl:
          json['thumbnail_url']?.toString() ?? json['poster_url']?.toString(),
      durationSeconds: _asInt(json['duration_seconds']) ??
          _asInt(json['duration']) ??
          0,
      coinCost: _asInt(json['coin_cost']) ?? 10,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'series_id': seriesId,
        'episode_id': episodeId,
        'title': title,
        'vertical_video_url': verticalVideoUrl,
        'description': description,
        'tags': tags,
        'likes_count': likesCount,
        'is_liked': isLiked,
        'is_saved': isSaved,
        'is_accessible': isAccessible,
        'access_reason': accessReason,
        'episode_number': episodeNumber,
        'series_title': seriesTitle,
        'total_episodes': totalEpisodes,
        'average_rating': averageRating,
        'rating_count': ratingCount,
        'thumbnail_url': thumbnailUrl,
        'duration_seconds': durationSeconds,
        'coin_cost': coinCost,
      };

  ShortItem copyWith({
    String? id,
    String? seriesId,
    String? episodeId,
    String? title,
    String? verticalVideoUrl,
    String? description,
    List<String>? tags,
    int? likesCount,
    bool? isLiked,
    bool? isSaved,
    bool? isAccessible,
    String? accessReason,
    int? episodeNumber,
    String? seriesTitle,
    int? totalEpisodes,
    double? averageRating,
    int? ratingCount,
    String? thumbnailUrl,
    int? durationSeconds,
    int? coinCost,
  }) =>
      ShortItem(
        id: id ?? this.id,
        seriesId: seriesId ?? this.seriesId,
        episodeId: episodeId ?? this.episodeId,
        title: title ?? this.title,
        verticalVideoUrl: verticalVideoUrl ?? this.verticalVideoUrl,
        description: description ?? this.description,
        tags: tags ?? this.tags,
        likesCount: likesCount ?? this.likesCount,
        isLiked: isLiked ?? this.isLiked,
        isSaved: isSaved ?? this.isSaved,
        isAccessible: isAccessible ?? this.isAccessible,
        accessReason: accessReason ?? this.accessReason,
        episodeNumber: episodeNumber ?? this.episodeNumber,
        seriesTitle: seriesTitle ?? this.seriesTitle,
        totalEpisodes: totalEpisodes ?? this.totalEpisodes,
        averageRating: averageRating ?? this.averageRating,
        ratingCount: ratingCount ?? this.ratingCount,
        thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
        durationSeconds: durationSeconds ?? this.durationSeconds,
        coinCost: coinCost ?? this.coinCost,
      );
}

class ShortsFeed {
  ShortsFeed({this.nextCursor, required this.items});

  final String? nextCursor;
  final List<ShortItem> items;

  factory ShortsFeed.fromJson(dynamic json) {
    if (json is List) {
      return ShortsFeed(
        nextCursor: null,
        items: json
            .whereType<Map<String, dynamic>>()
            .map((e) => ShortItem.fromJson(e))
            .toList(),
      );
    }
    if (json is Map<String, dynamic>) {
      final rawItems = json['items'];
      List<ShortItem> itemsList;
      if (rawItems is List) {
        itemsList = rawItems
            .whereType<Map<String, dynamic>>()
            .map((e) => ShortItem.fromJson(e))
            .toList();
      } else {
        itemsList = const [];
      }
      return ShortsFeed(
        nextCursor: json['next_cursor']?.toString(),
        items: itemsList,
      );
    }
    return ShortsFeed(nextCursor: null, items: const []);
  }
}

int? _asInt(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return num.tryParse(v)?.toInt();
  return null;
}

double? _asDouble(dynamic v) {
  if (v is double) return v;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v);
  return null;
}
