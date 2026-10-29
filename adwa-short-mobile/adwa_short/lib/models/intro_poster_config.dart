class IntroPosterConfig {
  const IntroPosterConfig({
    this.enabled = true,
    this.seriesId,
    this.title = '',
    this.posterUrl,
    this.bannerUrl,
    this.countdownSeconds = 5,
    this.actionText = 'Watch Now',
  });

  final bool enabled;
  final String? seriesId;
  final String title;
  final String? posterUrl;
  final String? bannerUrl;
  final int countdownSeconds;
  final String actionText;

  factory IntroPosterConfig.fromJson(Map<String, dynamic> json) {
    return IntroPosterConfig(
      enabled: json['enabled'] != false,
      seriesId: json['series_id']?.toString(),
      title: json['title']?.toString() ?? '',
      posterUrl: json['poster_url']?.toString(),
      bannerUrl: json['banner_url']?.toString(),
      countdownSeconds: (json['countdown_seconds'] as num?)?.toInt() ?? 5,
      actionText: json['action_text']?.toString() ?? 'Watch Now',
    );
  }

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'series_id': seriesId,
        'title': title,
        'poster_url': posterUrl,
        'banner_url': bannerUrl,
        'countdown_seconds': countdownSeconds,
        'action_text': actionText,
      };
}
