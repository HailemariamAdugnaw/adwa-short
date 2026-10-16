class TimePass {
  TimePass({
    required this.id,
    required this.name,
    required this.durationHours,
    required this.priceBirr,
    this.description = '',
    this.isPopular = false,
  });

  final String id;
  final String name;
  final int durationHours;
  final num priceBirr;
  final String description;
  final bool isPopular;

  factory TimePass.fromJson(Map<String, dynamic> json) {
    return TimePass(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Pass',
      durationHours: _asInt(json['duration_hours']) ?? 0,
      priceBirr: (json['price_birr'] is num
          ? json['price_birr'] as num
          : (num.tryParse(json['price_birr']?.toString() ?? '') ?? 0)),
      description: json['description']?.toString() ?? '',
      isPopular: json['is_popular'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'duration_hours': durationHours,
        'price_birr': priceBirr,
        'description': description,
        'is_popular': isPopular,
      };

  String get shortDuration {
    if (durationHours < 24) return '${durationHours}h';
    final d = durationHours ~/ 24;
    final h = durationHours % 24;
    return h == 0 ? '${d}d' : '${d}d ${h}h';
  }
}

int? _asInt(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v);
  return null;
}
