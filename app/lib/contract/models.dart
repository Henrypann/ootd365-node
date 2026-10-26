// Dart side of schema/wardrobe-v1.schema.json and schema/wardrobe-events-v1.schema.json.
// The node validates every write; these types only parse what it returns and
// catch obvious form mistakes before a request is sent.

import 'dart:math';

class ContractError implements Exception {
  const ContractError(this.path, this.message);

  final String path;
  final String message;

  @override
  String toString() => '$path: $message';
}

abstract final class ContractIds {
  static final pattern = RegExp(r'^[a-z0-9][a-z0-9_-]{0,63}$');

  static final _random = Random.secure();

  /// Same shape as the node's ids: prefix plus 12 hex characters.
  static String newId(String prefix) {
    final hex = List.generate(6, (_) => _random.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
    return '${prefix}_$hex';
  }

  static String newItemId() => newId('item');
}

/// Local calendar day as `YYYY-MM-DD`, the contract's date shape.
String contractDate(DateTime day) =>
    '${day.year.toString().padLeft(4, '0')}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';

enum Category {
  top('上装'),
  bottom('下装'),
  shoes('鞋'),
  outer('外搭'),
  other('其他');

  const Category(this.label);

  final String label;
}

enum Season {
  spring('春'),
  summer('夏'),
  autumn('秋'),
  winter('冬');

  const Season(this.label);

  final String label;
}

enum ItemStatus {
  active('在穿'),
  retired('已退役');

  const ItemStatus(this.label);

  final String label;
}

enum EventType {
  wear('穿着'),
  wash('洗涤');

  const EventType(this.label);

  final String label;
}

T _enumByName<T extends Enum>(List<T> values, Object? name, String path) {
  for (final value in values) {
    if (value.name == name) return value;
  }
  throw ContractError(path, 'Unknown value $name.');
}

class CosKey {
  const CosKey({required this.key, required this.sha256});

  factory CosKey.fromJson(Map<String, dynamic> json) =>
      CosKey(key: json['key'] as String, sha256: json['sha256'] as String);

  final String key;
  final String sha256;
}

/// Fields a person fills in. Sent as the body of `PUT /v1/items/{id}`.
class ItemFields {
  const ItemFields({
    required this.category,
    required this.season,
    required this.color,
    required this.status,
    this.acquiredAt,
  });

  final Category category;
  final Set<Season> season;
  final String color;
  final ItemStatus status;
  final String? acquiredAt;

  /// Mirrors the schema limits the form can get wrong.
  void check() {
    final trimmed = color.trim();
    if (trimmed.isEmpty || trimmed.length > 64) {
      throw const ContractError('color', '颜色写 1 到 64 个字。');
    }
  }

  Map<String, dynamic> toJson() => {
        'category': category.name,
        // Keep the schema's enum order so the manifest diffs stay stable.
        'season': [for (final s in Season.values) if (season.contains(s)) s.name],
        'color': color.trim(),
        'status': status.name,
        'acquired_at': acquiredAt,
      };
}

class Item {
  const Item({
    required this.id,
    required this.fields,
    required this.wearCount,
    required this.washCount,
    required this.cosKeys,
    required this.updatedAt,
  });

  factory Item.fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String;
    return Item(
      id: id,
      fields: ItemFields(
        category: _enumByName(Category.values, json['category'], 'items[$id].category'),
        season: {
          for (final s in json['season'] as List) _enumByName(Season.values, s, 'items[$id].season'),
        },
        color: json['color'] as String,
        status: _enumByName(ItemStatus.values, json['status'], 'items[$id].status'),
        acquiredAt: json['acquired_at'] as String?,
      ),
      wearCount: json['wear_count'] as int,
      washCount: json['wash_count'] as int,
      cosKeys: [for (final k in json['cos_keys'] as List) CosKey.fromJson(k as Map<String, dynamic>)],
      updatedAt: json['updated_at'] as String,
    );
  }

  final String id;
  final ItemFields fields;
  final int wearCount;
  final int washCount;
  final List<CosKey> cosKeys;
  final String updatedAt;

  String? get coverKey => cosKeys.isEmpty ? null : cosKeys.first.key;
}

class WardrobeIndex {
  const WardrobeIndex(this.items);

  factory WardrobeIndex.fromJson(Map<String, dynamic> json) {
    if (json['schema_version'] != 'wardrobe-v1') {
      throw const ContractError('schema_version', '节点的清单版本不对。');
    }
    return WardrobeIndex([for (final i in json['items'] as List) Item.fromJson(i as Map<String, dynamic>)]);
  }

  static const empty = WardrobeIndex([]);

  final List<Item> items;

  Item? byId(String id) {
    for (final item in items) {
      if (item.id == id) return item;
    }
    return null;
  }
}

class WardrobeEvent {
  const WardrobeEvent({
    required this.id,
    required this.type,
    required this.date,
    required this.itemIds,
    required this.recordedAt,
    this.lookKey,
  });

  factory WardrobeEvent.fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String;
    final look = json['look_key'] as Map<String, dynamic>?;
    return WardrobeEvent(
      id: id,
      type: _enumByName(EventType.values, json['type'], 'events[$id].type'),
      date: json['date'] as String,
      itemIds: [for (final i in json['item_ids'] as List) i as String],
      recordedAt: json['recorded_at'] as String,
      lookKey: look == null ? null : CosKey.fromJson(look),
    );
  }

  final String id;
  final EventType type;
  final String date;
  final List<String> itemIds;
  final String recordedAt;
  final CosKey? lookKey;
}

class EventLog {
  const EventLog(this.events);

  factory EventLog.fromJson(Map<String, dynamic> json) {
    if (json['schema_version'] != 'wardrobe-events-v1') {
      throw const ContractError('schema_version', '节点的事件日志版本不对。');
    }
    return EventLog([for (final e in json['events'] as List) WardrobeEvent.fromJson(e as Map<String, dynamic>)]);
  }

  static const empty = EventLog([]);

  final List<WardrobeEvent> events;
}
