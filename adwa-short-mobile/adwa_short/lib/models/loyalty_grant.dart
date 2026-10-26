class LoyaltyGrant {
  LoyaltyGrant({
    required this.id,
    required this.type,
    required this.title,
    this.description,
    required this.grantedAt,
    this.expiresAt,
    required this.value,
    this.rewardId,
  });

  final String id;
  final LoyaltyGrantType type;
  final String title;
  final String? description;
  final DateTime grantedAt;
  final DateTime? expiresAt;
  final int value;
  final int? rewardId;

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
    final rewardIdNum = _asInt(json['reward_id']) ??
        _asInt(detailsMap?['reward_id']);
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
      rewardId: rewardIdNum,
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
        'reward_id': rewardId,
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
    this.isActive = true,
    this.provider = 'admob',
    this.appId,
    this.rewardedUnitId,
    this.interstitialUnitId,
    this.bannerUnitId,
    this.rewardAdValueBirr = 0.0,
    this.estimatedCpmBirr = 0.0,
    this.testMode = true,
  });

  final int adsRequired;
  final int episodesUnlocked;
  final bool isActive;
  final String provider;
  final String? appId;
  final String? rewardedUnitId;
  final String? interstitialUnitId;
  final String? bannerUnitId;
  final double rewardAdValueBirr;
  final double estimatedCpmBirr;
  final bool testMode;

  factory AdUnlockRule.fromJson(Map<String, dynamic> json) {
    return AdUnlockRule(
      adsRequired: _asInt(json['ads_required']) ?? 1,
      episodesUnlocked: _asInt(json['episodes_unlocked']) ?? 1,
      isActive: json['is_active'] as bool? ?? true,
      provider: json['provider']?.toString() ?? 'admob',
      appId: json['app_id']?.toString(),
      rewardedUnitId: json['rewarded_unit_id']?.toString(),
      interstitialUnitId: json['interstitial_unit_id']?.toString(),
      bannerUnitId: json['banner_unit_id']?.toString(),
      rewardAdValueBirr: _asDouble(json['reward_ad_value_birr']) ?? 0.0,
      estimatedCpmBirr: _asDouble(json['estimated_cpm_birr']) ?? 0.0,
      testMode: json['test_mode'] as bool? ?? true,
    );
  }
}

class LoyaltyConfig {
  LoyaltyConfig({
    required this.minBalanceBirr,
    required this.maxBalanceBirr,
    required this.dailyAccessDays,
    required this.freeCoins,
    required this.freeFullSeriesCount,
    required this.isActive,
  });

  final double minBalanceBirr;
  final double maxBalanceBirr;
  final int dailyAccessDays;
  final int freeCoins;
  final int freeFullSeriesCount;
  final bool isActive;

  factory LoyaltyConfig.fromJson(Map<String, dynamic> json) {
    return LoyaltyConfig(
      minBalanceBirr: _asDouble(json['min_balance_birr']) ?? 50.0,
      maxBalanceBirr: _asDouble(json['max_balance_birr']) ?? 1000.0,
      dailyAccessDays: _asInt(json['daily_access_days']) ?? 7,
      freeCoins: _asInt(json['free_coins']) ?? 100,
      freeFullSeriesCount: _asInt(json['free_full_series_count']) ?? 1,
      isActive: json['is_active'] as bool? ?? true,
    );
  }
}

class LoyaltyUserStatus {
  LoyaltyUserStatus({
    required this.minBalanceBirr,
    required this.maxBalanceBirr,
    required this.dailyAccessDays,
    required this.freeCoins,
    required this.freeFullSeriesCount,
    required this.isActive,
    required this.walletBalanceBirr,
    required this.walletBalanceCoins,
    required this.qualifies,
    required this.neededBirr,
    required this.progressPct,
    required this.canClaim,
    this.rewardId,
    this.isClaimed = false,
  });

  final double minBalanceBirr;
  final double maxBalanceBirr;
  final int dailyAccessDays;
  final int freeCoins;
  final int freeFullSeriesCount;
  final bool isActive;
  final double walletBalanceBirr;
  final int walletBalanceCoins;
  final bool qualifies;
  final double neededBirr;
  final double progressPct;
  final bool canClaim;
  final int? rewardId;
  final bool isClaimed;

  LoyaltyUserStatus copyWith({
    double? minBalanceBirr,
    double? maxBalanceBirr,
    int? dailyAccessDays,
    int? freeCoins,
    int? freeFullSeriesCount,
    bool? isActive,
    double? walletBalanceBirr,
    int? walletBalanceCoins,
    bool? qualifies,
    double? neededBirr,
    double? progressPct,
    bool? canClaim,
    int? rewardId,
    bool? isClaimed,
  }) {
    return LoyaltyUserStatus(
      minBalanceBirr: minBalanceBirr ?? this.minBalanceBirr,
      maxBalanceBirr: maxBalanceBirr ?? this.maxBalanceBirr,
      dailyAccessDays: dailyAccessDays ?? this.dailyAccessDays,
      freeCoins: freeCoins ?? this.freeCoins,
      freeFullSeriesCount: freeFullSeriesCount ?? this.freeFullSeriesCount,
      isActive: isActive ?? this.isActive,
      walletBalanceBirr: walletBalanceBirr ?? this.walletBalanceBirr,
      walletBalanceCoins: walletBalanceCoins ?? this.walletBalanceCoins,
      qualifies: qualifies ?? this.qualifies,
      neededBirr: neededBirr ?? this.neededBirr,
      progressPct: progressPct ?? this.progressPct,
      canClaim: canClaim ?? this.canClaim,
      rewardId: rewardId ?? this.rewardId,
      isClaimed: isClaimed ?? this.isClaimed,
    );
  }

  factory LoyaltyUserStatus.fromJson(Map<String, dynamic> json) {
    return LoyaltyUserStatus(
      minBalanceBirr: _asDouble(json['min_balance_birr']) ?? 50.0,
      maxBalanceBirr: _asDouble(json['max_balance_birr']) ?? 1000.0,
      dailyAccessDays: _asInt(json['daily_access_days']) ?? 7,
      freeCoins: _asInt(json['free_coins']) ?? 100,
      freeFullSeriesCount: _asInt(json['free_full_series_count']) ?? 1,
      isActive: json['is_active'] as bool? ?? true,
      walletBalanceBirr: _asDouble(json['wallet_balance_birr']) ?? 0.0,
      walletBalanceCoins: _asInt(json['wallet_balance_coins']) ?? 0,
      qualifies: json['qualifies'] as bool? ?? false,
      neededBirr: _asDouble(json['needed_birr']) ?? 0.0,
      progressPct: _asDouble(json['progress_pct']) ?? 0.0,
      canClaim: json['can_claim'] as bool? ?? false,
      rewardId: _asInt(json['reward_id']),
      isClaimed: json['is_claimed'] as bool? ?? false,
    );
  }
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
