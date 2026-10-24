class Review {
  const Review({
    required this.id,
    required this.userId,
    required this.userName,
    this.userAvatarUrl,
    required this.episodeId,
    this.seriesId,
    required this.text,
    this.rating,
    this.isApproved = false,
    required this.createdAt,
  });

  final int id;
  final int userId;
  final String userName;
  final String? userAvatarUrl;
  final int episodeId;
  final int? seriesId;
  final String text;
  final int? rating;
  final bool isApproved;
  final DateTime createdAt;

  factory Review.fromJson(Map<String, dynamic> json) {
    final rawUser = json['user'];
    String userName;
    String? userAvatarUrl;
    int userId;
    if (rawUser is Map<String, dynamic>) {
      userName = rawUser['display_name']?.toString() ??
          rawUser['name']?.toString() ??
          'User';
      userAvatarUrl = rawUser['avatar_url']?.toString();
      userId = _asInt(rawUser['id']) ?? 0;
    } else {
      userName = json['user_name']?.toString() ??
          json['display_name']?.toString() ??
          'User';
      userAvatarUrl = json['user_avatar_url']?.toString();
      userId = _asInt(json['user_id']) ?? 0;
    }
    return Review(
      id: _asInt(json['id']) ?? 0,
      userId: userId,
      userName: userName,
      userAvatarUrl: userAvatarUrl,
      episodeId: _asInt(json['episode_id']) ?? 0,
      seriesId: _asInt(json['series_id']),
      text: json['text']?.toString() ?? '',
      rating: _asInt(json['rating']),
      isApproved: json['is_approved'] == true,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'user_name': userName,
        'user_avatar_url': userAvatarUrl,
        'episode_id': episodeId,
        'series_id': seriesId,
        'text': text,
        'rating': rating,
        'is_approved': isApproved,
        'created_at': createdAt.toIso8601String(),
      };

  Review copyWith({
    int? id,
    int? userId,
    String? userName,
    String? userAvatarUrl,
    int? episodeId,
    int? seriesId,
    String? text,
    int? rating,
    bool? isApproved,
    DateTime? createdAt,
  }) =>
      Review(
        id: id ?? this.id,
        userId: userId ?? this.userId,
        userName: userName ?? this.userName,
        userAvatarUrl: userAvatarUrl ?? this.userAvatarUrl,
        episodeId: episodeId ?? this.episodeId,
        seriesId: seriesId ?? this.seriesId,
        text: text ?? this.text,
        rating: rating ?? this.rating,
        isApproved: isApproved ?? this.isApproved,
        createdAt: createdAt ?? this.createdAt,
      );
}

int? _asInt(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v);
  return null;
}
