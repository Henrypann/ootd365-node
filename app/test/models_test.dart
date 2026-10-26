import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ootd365/contract/models.dart';
import 'package:ootd365/node/node_settings.dart';

// The repo's fake samples are the fixtures, so the app and the schema can't drift apart silently.
Map<String, dynamic> _sample(String name) =>
    jsonDecode(File('../examples/$name').readAsStringSync()) as Map<String, dynamic>;

void main() {
  test('parses the wardrobe sample', () {
    final index = WardrobeIndex.fromJson(_sample('wardrobe-v1.sample.json'));
    expect(index.items, hasLength(5));
    final tee = index.byId('demo_item_navy_tee')!;
    expect(tee.fields.category, Category.top);
    expect(tee.fields.season, {Season.spring, Season.summer});
    expect(tee.wearCount, 4);
    expect(tee.coverKey, 'wardrobe/v1/items/demo_item_navy_tee/demo_asset_front.jpg');
    expect(index.byId('demo_item_grey_trousers')!.fields.acquiredAt, isNull);
  });

  test('parses the events sample', () {
    final log = EventLog.fromJson(_sample('wardrobe-events-v1.sample.json'));
    expect(log.events, hasLength(3));
    expect(log.events.first.lookKey!.key, startsWith('wardrobe/v1/looks/demo_event_0115_wear/'));
    expect(log.events.last.type, EventType.wash);
  });

  test('rejects another schema version', () {
    expect(() => WardrobeIndex.fromJson({'schema_version': 'wardrobe-v2', 'items': []}), throwsA(isA<ContractError>()));
  });

  test('item fields serialize in schema order and trim color', () {
    final json = const ItemFields(
      category: Category.outer,
      season: {Season.winter, Season.spring},
      color: '  black ',
      status: ItemStatus.active,
    ).toJson();
    expect(json, {
      'category': 'outer',
      'season': ['spring', 'winter'],
      'color': 'black',
      'status': 'active',
      'acquired_at': null,
    });
  });

  test('empty color fails the client check', () {
    expect(
      () => const ItemFields(category: Category.top, season: {}, color: ' ', status: ItemStatus.active).check(),
      throwsA(isA<ContractError>()),
    );
  });

  test('new ids match the contract id syntax', () {
    final ids = {for (var i = 0; i < 200; i++) ContractIds.newItemId()};
    expect(ids, hasLength(200));
    expect(ids.every(ContractIds.pattern.hasMatch), isTrue);
  });

  test('contract dates are zero padded', () {
    expect(contractDate(DateTime(2026, 3, 7)), '2026-03-07');
  });

  test('node url accepts host:port and fills the default port', () {
    expect(parseNodeUrl('192.168.1.5:8365').toString(), 'http://192.168.1.5:8365');
    expect(parseNodeUrl('192.168.1.5').toString(), 'http://192.168.1.5:8365');
    expect(parseNodeUrl('http://pi.local:9000/').toString(), 'http://pi.local:9000/');
    expect(parseNodeUrl('  '), isNull);
    expect(parseNodeUrl('ftp://x'), isNull);
  });
}
