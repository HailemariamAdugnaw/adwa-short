class SubscriptionPlan {
  SubscriptionPlan({
    required this.id,
    required this.name,
    required this.billingCycle,
    required this.priceBirr,
    this.description = '',
    this.features = const [],
    this.isPopular = false,
  });

  final String id;
  final String name;
  final String billingCycle;
  final num priceBirr;
  final String description;
  final List<String> features;
  final bool isPopular;

  factory SubscriptionPlan.fromJson(Map<String, dynamic> json) {
    return SubscriptionPlan(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Plan',
      billingCycle:
          json['billing_cycle']?.toString() ?? 'monthly',
      priceBirr: (json['price_birr'] is num
          ? json['price_birr'] as num
          : (num.tryParse(json['price_birr']?.toString() ?? '') ?? 0)),
      description: json['description']?.toString() ?? '',
      features: _parseStringList(json['features']),
      isPopular: json['is_popular'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'billing_cycle': billingCycle,
        'price_birr': priceBirr,
        'description': description,
        'features': features,
        'is_popular': isPopular,
      };

  String get priceLabel {
    final unit = billingCycle == 'yearly' ? 'year' : 'month';
    return 'Birr ${priceBirr.toStringAsFixed(0)} / $unit';
  }
}

List<String> _parseStringList(dynamic raw) {
  if (raw is List) {
    return raw
        .map((e) => e?.toString() ?? '')
        .where((s) => s.isNotEmpty)
        .toList();
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
