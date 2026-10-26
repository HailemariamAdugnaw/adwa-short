class Episode {
  Episode({
    required this.id,
    required this.seriesId,
    required this.number,
    required this.title,
    this.description = '',
    this.thumbnailUrl,
    this.videoUrl,
    this.durationSeconds = 0,
    this.isFree = false,
    this.isLocked = false,
    this.accessible = false,
    this.isAccessible,
    this.accessReason,
    this.creatorId,
    this.coinCost,
    this.viewsCount = 0,
    this.likesCount = 0,
    this.commentsCount = 0,
    this.averageRating,
    this.ratingCount,
    this.reviewCount,
    this.watchedProgress = 0,
    this.lastPosition = 0,
  });

  final String id;
  final String seriesId;
  final int number;
  final String title;
  final String description;
  final String? thumbnailUrl;
  final String? videoUrl;
  final int durationSeconds;
  final bool isFree;
  final bool isLocked;
  final bool accessible;
  final bool? isAccessible;
  final String? accessReason;
  final int? creatorId;
  final int? coinCost;
  final int viewsCount;
  final int likesCount;
  final int commentsCount;
  final double? averageRating;
  final int? ratingCount;
  final int? reviewCount;
  final double watchedProgress;
  final int lastPosition;

  bool get effectivelyAccessible =>
      isAccessible ?? (isFree || accessible || !isLocked);

  factory Episode.fromJson(Map<String, dynamic> json, {int? defaultFreeCount, int? defaultCoinCost}) {
    final epNum = _asInt(json['number']) ?? _asInt(json['episode_number']) ?? 0;
    final bool rawIsFree = json['is_free'] == true ||
        (defaultFreeCount != null && defaultFreeCount > 0 && epNum > 0 && epNum <= defaultFreeCount);
    final bool? apiAccessible = json['is_accessible'] is bool
        ? json['is_accessible'] as bool
        : null;
    final bool isAcc = apiAccessible ?? (rawIsFree || json['accessible'] == true);
    final bool rawIsLocked = json['is_locked'] is bool
        ? json['is_locked'] as bool
        : (!rawIsFree && !isAcc);
    final parsedCoin = _asInt(json['coin_cost']) ?? _asInt(json['effective_coin_cost']);

    return Episode(
      id: json['id']?.toString() ?? '',
      seriesId: json['series_id']?.toString() ?? '',
      number: epNum,
      title: json['title']?.toString() ?? 'Episode',
      description: json['description']?.toString() ?? '',
      thumbnailUrl:
          json['thumbnail_url']?.toString() ?? json['poster_url']?.toString(),
      videoUrl: json['video_url']?.toString() ??
          json['hls_url']?.toString() ??
          json['file_uri']?.toString() ??
          json['vertical_video_url']?.toString() ??
          json['stream_url']?.toString() ??
          json['url']?.toString(),
      durationSeconds:
          _asInt(json['duration_seconds']) ?? _asInt(json['duration']) ?? 0,
      isFree: rawIsFree,
      isLocked: rawIsLocked,
      accessible: json['accessible'] == true || isAcc,
      isAccessible: apiAccessible ?? isAcc,
      accessReason: json['access_reason']?.toString(),
      creatorId: _asInt(json['creator_id']),
      coinCost: (parsedCoin != null && parsedCoin > 0) ? parsedCoin : (defaultCoinCost ?? 10),
      viewsCount:
          _asInt(json['views_count']) ?? _asInt(json['view_count']) ?? 0,
      likesCount:
          _asInt(json['likes_count']) ?? _asInt(json['like_count']) ?? 0,
      commentsCount:
          _asInt(json['comments_count']) ?? _asInt(json['comment_count']) ?? 0,
      averageRating:
          _asDouble(json['average_rating']) ?? _asDouble(json['rating']),
      ratingCount: _asInt(json['rating_count']),
      reviewCount: _asInt(json['review_count']),
      watchedProgress:
          _asDouble(json['watched_progress']) ??
          _asDouble(json['progress']) ??
          0,
      lastPosition:
          _asInt(json['last_position']) ??
          _asInt(json['last_position_seconds']) ??
          0,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'series_id': seriesId,
    'number': number,
    'title': title,
    'description': description,
    'thumbnail_url': thumbnailUrl,
    'video_url': videoUrl,
    'duration_seconds': durationSeconds,
    'is_free': isFree,
    'is_locked': isLocked,
    'accessible': accessible,
    'is_accessible': isAccessible,
    'access_reason': accessReason,
    'creator_id': creatorId,
    'coin_cost': coinCost,
    'views_count': viewsCount,
    'likes_count': likesCount,
    'comments_count': commentsCount,
    'average_rating': averageRating,
    'rating_count': ratingCount,
    'review_count': reviewCount,
    'watched_progress': watchedProgress,
    'last_position': lastPosition,
  };

  Episode copyWith({
    String? id,
    String? seriesId,
    int? number,
    String? title,
    String? description,
    String? thumbnailUrl,
    String? videoUrl,
    int? durationSeconds,
    bool? isFree,
    bool? isLocked,
    bool? accessible,
    bool? isAccessible,
    String? accessReason,
    int? creatorId,
    int? coinCost,
    int? viewsCount,
    int? likesCount,
    int? commentsCount,
    double? averageRating,
    int? ratingCount,
    int? reviewCount,
    double? watchedProgress,
    int? lastPosition,
  }) => Episode(
    id: id ?? this.id,
    seriesId: seriesId ?? this.seriesId,
    number: number ?? this.number,
    title: title ?? this.title,
    description: description ?? this.description,
    thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
    videoUrl: videoUrl ?? this.videoUrl,
    durationSeconds: durationSeconds ?? this.durationSeconds,
    isFree: isFree ?? this.isFree,
    isLocked: isLocked ?? this.isLocked,
    accessible: accessible ?? this.accessible,
    isAccessible: isAccessible ?? this.isAccessible,
    accessReason: accessReason ?? this.accessReason,
    creatorId: creatorId ?? this.creatorId,
    coinCost: coinCost ?? this.coinCost,
    viewsCount: viewsCount ?? this.viewsCount,
    likesCount: likesCount ?? this.likesCount,
    commentsCount: commentsCount ?? this.commentsCount,
    averageRating: averageRating ?? this.averageRating,
    ratingCount: ratingCount ?? this.ratingCount,
    reviewCount: reviewCount ?? this.reviewCount,
    watchedProgress: watchedProgress ?? this.watchedProgress,
    lastPosition: lastPosition ?? this.lastPosition,
  );

  String get metaLabel {
    final mins = (durationSeconds / 60).ceil();
    return 'E$number${mins > 0 ? ' · $mins min' : ''}';
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
