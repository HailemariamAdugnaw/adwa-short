class AdwaCategory {
  AdwaCategory({
    required this.id,
    required this.name,
    this.iconUrl,
    this.posterUrl,
    this.sortOrder = 0,
  });

  final String id;
  final String name;
  final String? iconUrl;
  final String? posterUrl;
  final int sortOrder;

  factory AdwaCategory.fromJson(Map<String, dynamic> json) {
    return AdwaCategory(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Category',
      iconUrl: json['icon_url']?.toString(),
      posterUrl: json['poster_url']?.toString(),
      sortOrder: _asInt(json['sort_order']) ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'icon_url': iconUrl,
        'poster_url': posterUrl,
        'sort_order': sortOrder,
      };
}

int? _asInt(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v);
  return null;
}
