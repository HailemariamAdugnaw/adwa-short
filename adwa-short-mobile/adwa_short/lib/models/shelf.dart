import 'series.dart';

class Shelf {
  Shelf({
    required this.key,
    required this.title,
    required this.type,
    required this.items,
  });

  final String key;
  final String title;
  final ShelfType type;
  final List<Series> items;

  factory Shelf.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    List<Series> seriesList;
    if (rawItems is List) {
      seriesList = rawItems
          .whereType<Map<String, dynamic>>()
          .map((e) => Series.fromJson(e))
          .toList();
    } else {
      seriesList = const [];
    }
    return Shelf(
      key: json['key']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      type: parseShelfType(json['type']?.toString()),
      items: seriesList,
    );
  }

  Map<String, dynamic> toJson() => {
        'key': key,
        'title': title,
        'type': type.name,
        'items': items.map((e) => e.toJson()).toList(),
      };
}

enum ShelfType { banner, row }

ShelfType parseShelfType(String? s) {
  switch (s) {
    case 'banner':
      return ShelfType.banner;
    case 'row':
      return ShelfType.row;
    default:
      return ShelfType.row;
  }
}

class ShelfKeys {
  ShelfKeys._();

  static const String hot = 'hot';
  static const String newReleases = 'new_releases';
  static const String trending = 'trending';
  static const String popular = 'popular';
  static const String mostSeen = 'most_seen';
  static const String frequentSeen = 'frequent_seen';
  static const String mostSearched = 'most_searched';
  static const String mostViral = 'most_viral';
  static const String vip = 'vip';
  static const String exclusive = 'exclusive';
  static const String romance = 'romance';
  static const String family = 'family';
  static const String drama = 'drama';
  static const String badCharacter = 'bad_character';
  static const String goodCharacter = 'good_character';
  static const String documentary = 'documentary';
  static const String ethiopia = 'ethiopia';
  static const String biography = 'biography';
  static const String celebrity = 'celebrity';
}
