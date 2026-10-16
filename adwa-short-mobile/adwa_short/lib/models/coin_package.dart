class CoinPackage {
  CoinPackage({
    required this.id,
    required this.name,
    required this.coins,
    required this.priceBirr,
    this.episodesUnlocked = 0,
    this.bonusCoins = 0,
    this.isPopular = false,
  });

  final String id;
  final String name;
  final int coins;
  final num priceBirr;
  final int episodesUnlocked;
  final int bonusCoins;
  final bool isPopular;

  factory CoinPackage.fromJson(Map<String, dynamic> json) {
    return CoinPackage(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Coin Pack',
      coins: _asInt(json['coins']) ?? 0,
      priceBirr: (json['price_birr'] is num
          ? json['price_birr'] as num
          : (num.tryParse(json['price_birr']?.toString() ?? '') ?? 0)),
      episodesUnlocked: _asInt(json['episodes_unlocked']) ?? 0,
      bonusCoins: _asInt(json['bonus_coins']) ?? 0,
      isPopular: json['is_popular'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'coins': coins,
        'price_birr': priceBirr,
        'episodes_unlocked': episodesUnlocked,
        'bonus_coins': bonusCoins,
        'is_popular': isPopular,
      };

  int get totalCoins => coins + bonusCoins;
}

int? _asInt(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v);
  return null;
}
