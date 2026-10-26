import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ootd365/contract/models.dart';
import 'package:ootd365/node/node_client.dart';

void main() {
  final base = Uri.parse('http://192.168.1.5:8365');

  NodeClient clientFor(Future<http.Response> Function(http.Request request) handler) =>
      NodeClient(baseUrl: base, token: 'secret', client: MockClient(handler));

  http.Response json(Object body, [int status = 200]) =>
      http.Response.bytes(utf8.encode(jsonEncode(body)), status, headers: {'content-type': 'application/json'});

  test('sends the bearer token and item fields', () async {
    late http.Request seen;
    final client = clientFor((request) async {
      seen = request;
      return json({
        'id': 'item_tee',
        'category': 'top',
        'season': [],
        'color': 'navy',
        'status': 'active',
        'wear_count': 0,
        'wash_count': 0,
        'cos_keys': [],
        'updated_at': '2026-10-26T08:00:00Z',
      }, 201);
    });
    final item = await client.putItem(
      'item_tee',
      const ItemFields(category: Category.top, season: {}, color: 'navy', status: ItemStatus.active),
    );
    expect(seen.method, 'PUT');
    expect(seen.url.toString(), 'http://192.168.1.5:8365/v1/items/item_tee');
    expect(seen.headers['Authorization'], 'Bearer secret');
    expect(jsonDecode(seen.body)['color'], 'navy');
    expect(item.id, 'item_tee');
  });

  test('photo uploads carry the sha256 of the exact bytes', () async {
    final bytes = Uint8List.fromList(utf8.encode('fake jpeg'));
    late http.Request seen;
    final client = clientFor((request) async {
      seen = request;
      return json({'key': 'wardrobe/v1/items/item_tee/a_000000000000.jpg', 'sha256': request.headers['X-Sha256']}, 201);
    });
    final key = await client.uploadItemPhoto('item_tee', PhotoUpload(bytes: bytes, contentType: 'image/jpeg'));
    expect(seen.headers['Content-Type'], 'image/jpeg');
    expect(seen.headers['X-Sha256'], crypto.sha256.convert(bytes).toString());
    expect(seen.bodyBytes, bytes);
    expect(key.sha256, crypto.sha256.convert(bytes).toString());
  });

  test('422 details become a readable message', () async {
    final client = clientFor((_) async => json({
          'error': 'contract',
          'details': [
            {'path': '/events/3/item_ids/0', 'message': 'missing'},
          ],
        }, 422));
    await expectLater(
      client.postEvent(type: EventType.wear, date: '2026-10-26', itemIds: ['item_missing']),
      throwsA(isA<NodeException>()
          .having((e) => e.status, 'status', 422)
          .having((e) => e.userMessage, 'userMessage', contains('/events/3/item_ids/0: missing'))),
    );
  });

  test('network failure becomes status 0', () async {
    final client = clientFor((_) async => throw http.ClientException('connection refused'));
    await expectLater(client.ping(), throwsA(isA<NodeException>().having((e) => e.status, 'status', 0)));
  });

  test('rejects a malformed item id before sending', () async {
    final client = clientFor((_) async => fail('should not send'));
    expect(
      () => client.putItem('Bad Id', const ItemFields(category: Category.top, season: {}, color: 'x', status: ItemStatus.active)),
      throwsA(isA<ContractError>()),
    );
  });

  test('object urls keep the key path', () {
    final client = clientFor((_) async => json({}));
    expect(client.objectUrl('wardrobe/v1/items/a/b.jpg').toString(),
        'http://192.168.1.5:8365/v1/objects/wardrobe/v1/items/a/b.jpg');
  });
}
