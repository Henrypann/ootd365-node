import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ootd365/node/node_client.dart';
import 'package:ootd365/state/wardrobe_store.dart';
import 'package:ootd365/ui/design/components.dart';
import 'package:ootd365/ui/design/tokens.dart';
import 'package:ootd365/ui/home_shell.dart';
import 'package:ootd365/ui/log_screen.dart';

Map<String, dynamic> _item(String id, String color, {String status = 'active'}) => {
      'id': id,
      'category': 'top',
      'season': [],
      'color': color,
      'status': status,
      'wear_count': 0,
      'wash_count': 0,
      'cos_keys': [],
      'updated_at': '2026-10-26T08:00:00Z',
    };

/// A tiny in-memory node: two active items, one retired, records posted events.
class _FakeNode {
  final posted = <Map<String, dynamic>>[];

  Future<http.Response> handle(http.Request request) async {
    final path = request.url.path;
    Object body;
    if (path == '/v1/index') {
      body = {
        'schema_version': 'wardrobe-v1',
        'items': [_item('item_tee', 'navy'), _item('item_shirt', 'white'), _item('item_old', 'red', status: 'retired')],
      };
    } else if (path == '/v1/events' && request.method == 'GET') {
      body = {'schema_version': 'wardrobe-events-v1', 'events': []};
    } else if (path == '/v1/events' && request.method == 'POST') {
      final event = jsonDecode(request.body) as Map<String, dynamic>;
      posted.add(event);
      body = {...event, 'id': 'ev_000000000001', 'source': 'manual', 'recorded_at': '2026-10-26T08:00:00Z'};
    } else {
      return http.Response('{"error":"not found"}', 404);
    }
    return http.Response.bytes(utf8.encode(jsonEncode(body)), 200);
  }
}

void main() {
  testWidgets('log screen: pick items, save one wear event for today', (tester) async {
    final node = _FakeNode();
    final store = WardrobeStore(
      NodeClient(baseUrl: Uri.parse('http://node:8365'), token: 't', client: MockClient(node.handle)),
    );
    await tester.runAsync(store.refresh);

    await tester.pumpWidget(MaterialApp(
      theme: buildTheme(),
      home: Scaffold(body: LogScreen(store: store, today: () => DateTime(2026, 10, 26, 7, 30))),
    ));

    expect(find.text('October 26'), findsOneWidget);

    // Retired items are not offered.
    expect(find.text('navy'), findsOneWidget);
    expect(find.text('white'), findsOneWidget);
    expect(find.text('red'), findsNothing);

    // Nothing selected: record is disabled.
    final save = find.widgetWithText(OButton, '记下今天');
    expect(tester.widget<OButton>(save).onPressed, isNull);
    expect(find.text('点选今天穿的单品'), findsOneWidget);

    await tester.tap(find.text('navy'));
    await tester.tap(find.text('white'));
    await tester.pump();
    expect(find.text('已选 2 件'), findsOneWidget);
    expect(tester.widget<OButton>(save).onPressed, isNotNull);

    await tester.runAsync(() async {
      await tester.tap(save);
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump();

    expect(node.posted, [
      {
        'type': 'wear',
        'date': '2026-10-26',
        'item_ids': ['item_tee', 'item_shirt'],
      },
    ]);
    expect(find.text('点选今天穿的单品'), findsOneWidget);
  });

  // All three tabs stay alive in one IndexedStack; pushing a route from one of them must not
  // trip over widgets the others keep (this once threw "multiple heroes share the same tag").
  testWidgets('pushing a route from the tabs works', (tester) async {
    final store = WardrobeStore(
      NodeClient(baseUrl: Uri.parse('http://node:8365'), token: 't', client: MockClient(_FakeNode().handle)),
    );
    await tester.runAsync(store.refresh);
    await tester.pumpWidget(MaterialApp(home: HomeShell(store: store, onOpenConnect: () {})));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump();

    await tester.tap(find.text('衣橱').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('登记单品'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('登记单品'), findsOneWidget);
  });
}
