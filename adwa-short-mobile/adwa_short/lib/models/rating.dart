class EpisodeRating {
  const EpisodeRating({
    required this.id,
    required this.userId,
    required this.episodeId,
    required this.rating,
    this.createdAt,
  });

  final int id;
  final int userId;
  final int episodeId;
  final int rating;
  final DateTime? createdAt;

  factory EpisodeRating.fromJson(Map<String, dynamic> json) {
    return EpisodeRating(
      id: _asInt(json['id']) ?? 0,
      userId: _asInt(json['user_id']) ?? 0,
      episodeId: _asInt(json['episode_id']) ?? 0,
      rating: (_asInt(json['rating']) ?? 0).clamp(1, 5),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'episode_id': episodeId,
        'rating': rating,
        'created_at': createdAt?.toIso8601String(),
      };

  EpisodeRating copyWith({
    int? id,
    int? userId,
    int? episodeId,
    int? rating,
    DateTime? createdAt,
  }) =>
      EpisodeRating(
        id: id ?? this.id,
        userId: userId ?? this.userId,
        episodeId: episodeId ?? this.episodeId,
        rating: rating ?? this.rating,
        createdAt: createdAt ?? this.createdAt,
      );
}

class RatingSummary {
  const RatingSummary({
    required this.average,
    required this.count,
    this.distribution = const [0, 0, 0, 0, 0],
    this.userRating,
  });

  final double average;
  final int count;
  final List<int> distribution;
  final int? userRating;

  factory RatingSummary.fromJson(Map<String, dynamic> json) {
    final rawDist = json['distribution'];
    List<int> dist;
    if (rawDist is List && rawDist.length == 5) {
      dist = rawDist.map((e) => _asInt(e) ?? 0).toList();
    } else {
      dist = const [0, 0, 0, 0, 0];
    }
    final avgRaw = json['average'] ?? json['average_rating'];
    final countRaw = json['count'] ?? json['rating_count'];
    final userRaw = json['user_rating'];
    return RatingSummary(
      average: _asDouble(avgRaw) ?? 0.0,
      count: _asInt(countRaw) ?? 0,
      distribution: dist,
      userRating: _asInt(userRaw),
    );
  }

  Map<String, dynamic> toJson() => {
        'average': average,
        'count': count,
        'distribution': distribution,
        'user_rating': userRating,
      };

  RatingSummary copyWith({
    double? average,
    int? count,
    List<int>? distribution,
    int? userRating,
  }) =>
      RatingSummary(
        average: average ?? this.average,
        count: count ?? this.count,
        distribution: distribution ?? this.distribution,
        userRating: userRating ?? this.userRating,
      );

  static const RatingSummary empty = RatingSummary(average: 0, count: 0);
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
