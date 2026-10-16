import '../models/episode.dart';

class AccessCheck {
  const AccessCheck({
    required this.accessible,
    required this.reason,
    this.coinCost,
    this.adsRemaining = 0,
    this.adsRequired = 0,
  });

  final bool accessible;
  final AccessReason reason;
  final int? coinCost;
  final int adsRemaining;
  final int adsRequired;

  factory AccessCheck.fromJson(Map<String, dynamic> json) {
    final accessRaw = json['access'];
    final bool ok;
    if (accessRaw is bool) {
      ok = accessRaw;
    } else if (accessRaw is String) {
      ok = accessRaw == 'allowed' || accessRaw == 'ok' || accessRaw == 'true';
    } else {
      ok = json['accessible'] == true;
    }
    final reasonRaw = json['reason']?.toString();
    final methodRaw = json['method']?.toString();
    final String? effectiveReason = (reasonRaw != null && reasonRaw.isNotEmpty)
        ? reasonRaw
        : methodRaw;
    return AccessCheck(
      accessible: ok,
      reason: parseAccessReason(effectiveReason),
      coinCost: _asInt(json['coin_cost']),
      adsRemaining: _asInt(json['ads_remaining']) ?? 0,
      adsRequired: _asInt(json['ads_required']) ?? 0,
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

enum AccessReason {
  free,
  adUnlock,
  coins,
  pass,
  subscription,
  needAd,
  needCoins,
  needPass,
  needSubscription,
}

AccessReason parseAccessReason(String? s) {
  switch (s) {
    case 'free':
      return AccessReason.free;
    case 'ad_unlock':
      return AccessReason.adUnlock;
    case 'coins':
      return AccessReason.coins;
    case 'pass':
      return AccessReason.pass;
    case 'subscription':
      return AccessReason.subscription;
    case 'need_ad':
      return AccessReason.needAd;
    case 'need_coins':
      return AccessReason.needCoins;
    case 'need_pass':
      return AccessReason.needPass;
    case 'need_subscription':
      return AccessReason.needSubscription;
    default:
      return AccessReason.needCoins;
  }
}

class WatchHistoryEntry {
  const WatchHistoryEntry({
    required this.episode,
    required this.watchedAt,
    required this.progress,
    required this.lastPositionSeconds,
  });

  final Episode episode;
  final DateTime watchedAt;
  final double progress;
  final int lastPositionSeconds;

  factory WatchHistoryEntry.fromJson(Map<String, dynamic> json) {
    final dynamic rawEpisode = json['episode'];
    final dynamic rawSeries = json['series'];
    Map<String, dynamic> episodeJson;
    if (rawEpisode is Map<String, dynamic>) {
      episodeJson = Map<String, dynamic>.from(rawEpisode);
      if (rawSeries is Map<String, dynamic>) {
        episodeJson['series_id'] ??= rawSeries['id'];
        episodeJson['series_title'] ??= rawSeries['title'];
      }
    } else {
      episodeJson = {
        'id': json['episode_id']?.toString() ?? '',
        'series_id': json['series_id']?.toString() ?? '',
        'title': json['episode_title']?.toString() ?? 'Episode',
        'thumbnail_url': json['thumbnail_url']?.toString(),
        'number': _asInt(json['episode_number']) ?? 0,
        'duration_seconds': _asInt(json['duration_seconds']) ?? 0,
        'is_free': json['is_free'] == true,
        'accessible': json['accessible'] == true,
        'coin_cost': _asInt(json['coin_cost']),
      };
      if (rawSeries is Map<String, dynamic>) {
        episodeJson['series_id'] ??= rawSeries['id']?.toString();
        episodeJson['series_title'] = rawSeries['title']?.toString();
      }
    }
    final watchedAtRaw = json['watched_at'] ?? json['created_at'];
    final watchedAt = watchedAtRaw != null
        ? DateTime.tryParse(watchedAtRaw.toString()) ?? DateTime.now()
        : DateTime.now();
    final watchTime = _asInt(json['watch_time_seconds']) ?? 0;
    final duration = _asInt(episodeJson['duration_seconds']) ?? 0;
    final progressRaw = _asDouble(json['progress']) ??
        _asDouble(json['watched_progress']);
    final double progress;
    if (progressRaw != null) {
      progress = progressRaw;
    } else if (duration > 0) {
      progress = (watchTime / duration).clamp(0.0, 1.0);
    } else {
      progress = (json['completed'] == true) ? 1.0 : 0.0;
    }
    return WatchHistoryEntry(
      episode: Episode.fromJson(episodeJson),
      watchedAt: watchedAt,
      progress: progress,
      lastPositionSeconds: _asInt(json['last_position_seconds']) ??
          _asInt(json['last_position']) ??
          watchTime,
    );
  }
}

class SearchResult {
  const SearchResult({
    this.series = const [],
    this.actors = const [],
    this.tags = const [],
  });

  final List<Map<String, dynamic>> series;
  final List<Map<String, dynamic>> actors;
  final List<Map<String, dynamic>> tags;

  factory SearchResult.fromJson(dynamic json) {
    if (json is List) {
      return SearchResult(
        series: json.whereType<Map<String, dynamic>>().toList(),
      );
    }
    if (json is Map<String, dynamic>) {
      return SearchResult(
        series: _asMapList(json['series']),
        actors: _asMapList(json['actors']),
        tags: _asMapList(json['tags']),
      );
    }
    return const SearchResult();
  }
}

List<Map<String, dynamic>> _asMapList(dynamic raw) {
  if (raw is List) {
    return raw.whereType<Map<String, dynamic>>().toList();
  }
  return const [];
}
