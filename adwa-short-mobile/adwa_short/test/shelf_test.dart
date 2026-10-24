import 'package:flutter_test/flutter_test.dart';

import 'package:adwa_short/models/category.dart';
import 'package:adwa_short/models/episode.dart';
import 'package:adwa_short/models/series.dart';
import 'package:adwa_short/models/shelf.dart';
import 'package:adwa_short/models/short_item.dart';

void main() {
  group('Shelf', () {
    test('parses banner shelf with hot key', () {
      final s = Shelf.fromJson({
        'key': 'hot',
        'title': 'Hot',
        'type': 'banner',
        'items': [
          {
            'id': '1',
            'title': 'Series A',
            'description': 'desc',
            'total_episodes': 12,
            'free_episode_count': 3,
            'is_hot': true,
          },
        ],
      });
      expect(s.key, ShelfKeys.hot);
      expect(s.type, ShelfType.banner);
      expect(s.items.length, 1);
      expect(s.items.first.isHot, isTrue);
    });

    test('parses row shelf', () {
      final s = Shelf.fromJson({
        'key': 'trending',
        'title': 'Top Trending',
        'type': 'row',
        'items': [],
      });
      expect(s.type, ShelfType.row);
    });

    test('parseShelfType falls back to row', () {
      expect(parseShelfType('unknown'), ShelfType.row);
      expect(parseShelfType(null), ShelfType.row);
    });
  });

  group('Series + Episode', () {
    test('series maps all flags and episodes', () {
      final s = Series.fromJson({
        'id': 's1',
        'title': 'Drama One',
        'description': 'A story.',
        'poster_url': 'https://x/p.png',
        'banner_url': 'https://x/b.png',
        'category': 'drama',
        'is_vip': true,
        'is_exclusive': false,
        'is_hot': true,
        'is_new_release': true,
        'total_episodes': 10,
        'free_episode_count': 2,
        'episodes': [
          {'id': 'e1', 'series_id': 's1', 'number': 1, 'title': 'Pilot'},
          {'id': 'e2', 'series_id': 's1', 'number': 2, 'title': 'Episode 2'},
        ],
        'tags': ['ethiopia', 'romance'],
      });
      expect(s.id, 's1');
      expect(s.isVip, isTrue);
      expect(s.isHot, isTrue);
      expect(s.episodes.length, 2);
      expect(s.episodes.first.number, 1);
      expect(s.tags, contains('ethiopia'));
    });

    test('episode metaLabel format', () {
      final e = Episode.fromJson({
        'id': 'e1',
        'series_id': 's1',
        'number': 12,
        'title': 'Pilot',
        'duration_seconds': 1380,
      });
      expect(e.metaLabel, 'E12 · 23 min');
    });
  });

  group('ShortItem', () {
    test('parses feed entry', () {
      final s = ShortItem.fromJson({
        'id': 'sh1',
        'series_id': 's1',
        'episode_id': 'e1',
        'title': 'Clip 1',
        'vertical_video_url': 'https://x/v.mp4',
        'description': 'A clip',
        'tags': ['hot', 'trending'],
        'likes_count': 1234,
        'is_liked': false,
        'is_saved': true,
      });
      expect(s.id, 'sh1');
      expect(s.likesCount, 1234);
      expect(s.isSaved, isTrue);
      expect(s.tags, contains('trending'));
    });

    test('ShortsFeed parses next_cursor', () {
      final feed = ShortsFeed.fromJson({
        'next_cursor': 'abc',
        'items': [
          {
            'id': 'sh1',
            'series_id': 's1',
            'title': 'Clip',
            'vertical_video_url': 'https://x/v.mp4',
          }
        ],
      });
      expect(feed.nextCursor, 'abc');
      expect(feed.items.length, 1);
    });
  });

  group('AdwaCategory', () {
    test('parses with default sort order', () {
      final c = AdwaCategory.fromJson({'id': '1', 'name': 'Drama'});
      expect(c.id, '1');
      expect(c.name, 'Drama');
      expect(c.sortOrder, 0);
    });
  });
}
