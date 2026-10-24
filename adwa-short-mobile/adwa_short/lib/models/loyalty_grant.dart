class LoyaltyGrant {
  LoyaltyGrant({
    required this.id,
    required this.type,
    required this.title,
    this.description,
    required this.grantedAt,
    this.expiresAt,
    required this.value,
  });

  final String id;
  final LoyaltyGrantType type;
  final String title;
  final String? description;
  final DateTime grantedAt;
  final DateTime? expiresAt;
  final int value;

  factory LoyaltyGrant.fromJson(Map<String, dynamic> json) {
    final dynamic details = json['details'];
    Map<String, dynamic>? detailsMap;
    if (details is Map<String, dynamic>) {
      detailsMap = details;
    } else if (details is Map) {
      detailsMap = Map<String, dynamic>.from(details);
    }
    final typeRaw =
        json['type']?.toString() ?? detailsMap?['type']?.toString();
    final titleRaw = json['title']?.toString() ??
        detailsMap?['title']?.toString() ??
        detailsMap?['reward']?.toString();
    final descRaw = json['description']?.toString() ??
        detailsMap?['description']?.toString();
    final valueNum = _asInt(json['value']) ??
        _asInt(detailsMap?['value']) ??
        _asInt(detailsMap?['coins']) ??
        0;
    return LoyaltyGrant(
      id: json['id']?.toString() ?? '',
      type: parseLoyaltyGrantType(typeRaw),
      title: (titleRaw != null && titleRaw.isNotEmpty) ? titleRaw : 'Reward',
      description: descRaw,
      grantedAt: json['granted_at'] != null
          ? DateTime.tryParse(json['granted_at'].toString()) ??
              DateTime.now()
          : DateTime.now(),
      expiresAt: json['expires_at'] != null
          ? DateTime.tryParse(json['expires_at'].toString())
          : null,
      value: valueNum,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'title': title,
        'description': description,
        'granted_at': grantedAt.toIso8601String(),
        'expires_at': expiresAt?.toIso8601String(),
        'value': value,
      };
}

enum LoyaltyGrantType {
  coins,
  freeEpisode,
  pass,
  subscription,
}

LoyaltyGrantType parseLoyaltyGrantType(String? s) {
  switch (s) {
    case 'coins':
      return LoyaltyGrantType.coins;
    case 'free_episode':
      return LoyaltyGrantType.freeEpisode;
    case 'pass':
      return LoyaltyGrantType.pass;
    case 'subscription':
      return LoyaltyGrantType.subscription;
    default:
      return LoyaltyGrantType.coins;
  }
}

class AdUnlockRule {
  AdUnlockRule({
    required this.adsRequired,
    required this.episodesUnlocked,
  });

  final int adsRequired;
  final int episodesUnlocked;

  factory AdUnlockRule.fromJson(Map<String, dynamic> json) {
    return AdUnlockRule(
      adsRequired: _asInt(json['ads_required']) ?? 1,
      episodesUnlocked: _asInt(json['episodes_unlocked']) ?? 1,
    );
  }
}

int? _asInt(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v);
  return null;
}
