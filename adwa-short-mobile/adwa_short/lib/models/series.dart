import 'episode.dart';

class Series {
  Series({
    required this.id,
    required this.title,
    this.description = '',
    this.posterUrl,
    this.bannerUrl,
    this.category,
    this.creatorId,
    this.creatorName,
    this.isVip = false,
    this.isExclusive = false,
    this.isHot = false,
    this.isNewRelease = false,
    this.totalEpisodes = 0,
    this.freeEpisodeCount = 0,
    this.coinCost,
    this.episodes = const [],
    this.cast = const [],
    this.tags = const [],
    this.rating,
    this.averageRating,
    this.ratingCount,
    this.reviewCount,
    this.viewsCount = 0,
    this.episodeId,
  });

  final String id;
  final String title;
  final String description;
  final String? posterUrl;
  final String? bannerUrl;
  final String? category;
  final int? creatorId;
  final String? creatorName;
  final bool isVip;
  final bool isExclusive;
  final bool isHot;
  final bool isNewRelease;
  final int totalEpisodes;
  final int freeEpisodeCount;
  final int? coinCost;
  final List<Episode> episodes;
  final List<CastMember> cast;
  final List<String> tags;
  final num? rating;
  final double? averageRating;
  final int? ratingCount;
  final int? reviewCount;
  final int viewsCount;
  final String? episodeId;

  factory Series.fromJson(Map<String, dynamic> json) {
    final rawCategory = json['category'];
    String? categoryName;
    if (rawCategory is String) {
      categoryName = rawCategory;
    } else if (rawCategory is Map) {
      categoryName = rawCategory['name']?.toString();
    } else if (rawCategory != null) {
      categoryName = rawCategory.toString();
    }
    final rawCast = json['cast'];
    List<CastMember> castList;
    if (rawCast is List) {
      castList = rawCast.map((e) {
        if (e is Map<String, dynamic>) {
          return CastMember.fromJson(e);
        }
        return CastMember(
          id: e?.toString() ?? '',
          name: e?.toString() ?? 'Unknown',
        );
      }).toList();
    } else {
      castList = const [];
    }
    final freeCount = _asInt(json['free_episode_count']) ??
        _asInt(json['free_episodes']) ??
        _asInt(json['effective_free_episodes']) ??
        0;
    final parsedCoinCost = _asInt(json['coin_cost']) ??
        _asInt(json['coin_price']) ??
        _asInt(json['effective_coin_cost']);
    final rawEpisodes = json['episodes'];
    List<Episode> episodesList;
    if (rawEpisodes is List) {
      episodesList = rawEpisodes
          .whereType<Map<String, dynamic>>()
          .map((e) => Episode.fromJson(e,
              defaultFreeCount: freeCount, defaultCoinCost: parsedCoinCost))
          .toList();
    } else {
      episodesList = const [];
    }
    return Series(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Untitled',
      description: json['description']?.toString() ?? '',
      posterUrl: json['poster_url']?.toString(),
      bannerUrl: json['banner_url']?.toString(),
      category: categoryName,
      creatorId: _asInt(json['creator_id']),
      creatorName: json['creator_name']?.toString() ??
          (json['creator'] is Map ? json['creator']['display_name']?.toString() : null),
      isVip: json['is_vip'] == true,
      isExclusive: json['is_exclusive'] == true,
      isHot: json['is_hot'] == true,
      isNewRelease: json['is_new_release'] == true,
      totalEpisodes:
          _asInt(json['total_episodes']) ?? _asInt(json['episode_count']) ?? 0,
      freeEpisodeCount: freeCount,
      coinCost: parsedCoinCost,
      episodes: episodesList,
      cast: castList,
      tags: _parseStringList(json['tags']),
      rating: json['rating'] is num ? json['rating'] as num : null,
      averageRating: _asDouble(json['average_rating']),
      ratingCount: _asInt(json['rating_count']),
      reviewCount: _asInt(json['review_count']),
      viewsCount: _asInt(json['views_count']) ??
          _asInt(json['view_count']) ??
          0,
      episodeId: json['episode_id']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'poster_url': posterUrl,
        'banner_url': bannerUrl,
        'category': category,
        'creator_id': creatorId,
        'creator_name': creatorName,
        'is_vip': isVip,
        'is_exclusive': isExclusive,
        'is_hot': isHot,
        'is_new_release': isNewRelease,
        'total_episodes': totalEpisodes,
        'free_episode_count': freeEpisodeCount,
        'coin_cost': coinCost,
        'episodes': episodes.map((e) => e.toJson()).toList(),
        'cast': cast.map((e) => e.toJson()).toList(),
        'tags': tags,
        'rating': rating,
        'average_rating': averageRating,
        'rating_count': ratingCount,
        'review_count': reviewCount,
        'views_count': viewsCount,
        'episode_id': episodeId,
      };

  Series copyWith({
    String? id,
    String? title,
    String? description,
    String? posterUrl,
    String? bannerUrl,
    String? category,
    int? creatorId,
    String? creatorName,
    bool? isVip,
    bool? isExclusive,
    bool? isHot,
    bool? isNewRelease,
    int? totalEpisodes,
    int? freeEpisodeCount,
    int? coinCost,
    List<Episode>? episodes,
    List<CastMember>? cast,
    List<String>? tags,
    num? rating,
    double? averageRating,
    int? ratingCount,
    int? reviewCount,
    int? viewsCount,
    String? episodeId,
  }) =>
      Series(
        id: id ?? this.id,
        title: title ?? this.title,
        description: description ?? this.description,
        posterUrl: posterUrl ?? this.posterUrl,
        bannerUrl: bannerUrl ?? this.bannerUrl,
        category: category ?? this.category,
        creatorId: creatorId ?? this.creatorId,
        creatorName: creatorName ?? this.creatorName,
        isVip: isVip ?? this.isVip,
        isExclusive: isExclusive ?? this.isExclusive,
        isHot: isHot ?? this.isHot,
        isNewRelease: isNewRelease ?? this.isNewRelease,
        totalEpisodes: totalEpisodes ?? this.totalEpisodes,
        freeEpisodeCount: freeEpisodeCount ?? this.freeEpisodeCount,
        coinCost: coinCost ?? this.coinCost,
        episodes: episodes ?? this.episodes,
        cast: cast ?? this.cast,
        tags: tags ?? this.tags,
        rating: rating ?? this.rating,
        averageRating: averageRating ?? this.averageRating,
        ratingCount: ratingCount ?? this.ratingCount,
        reviewCount: reviewCount ?? this.reviewCount,
        viewsCount: viewsCount ?? this.viewsCount,
        episodeId: episodeId ?? this.episodeId,
      );
}

class CastMember {
  CastMember({
    required this.id,
    required this.name,
    this.role,
    this.avatarUrl,
  });

  final String id;
  final String name;
  final String? role;
  final String? avatarUrl;

  factory CastMember.fromJson(Map<String, dynamic> json) {
    return CastMember(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Unknown',
      role: json['role']?.toString(),
      avatarUrl: json['avatar_url']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'role': role,
        'avatar_url': avatarUrl,
      };
}

List<String> _parseStringList(dynamic raw) {
  if (raw is List) {
    return raw.map((e) => e?.toString() ?? '').where((s) => s.isNotEmpty).toList();
  }
  if (raw is String) {
    return raw
        .split(',')
        .map((e) => e.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }
  return const [];
}

int? _asInt(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v);
  return null;
}

double? _asDouble(dynamic v) {
  if (v is double) return v;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v);
  return null;
}
