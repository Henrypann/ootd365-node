// Typed calls to the home node. The endpoints are documented in docs/node-api.md.

import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:http/http.dart' as http;

import '../contract/models.dart';

class NodeException implements Exception {
  const NodeException(this.status, this.message, [this.details = const []]);

  /// 0 when the node could not be reached at all.
  final int status;
  final String message;
  final List<String> details;

  String get userMessage => switch (status) {
        0 => '连不上节点：$message',
        401 => '令牌不对，去「连接节点」重新填。',
        409 => '节点拒绝覆盖已有的对象：$message',
        422 => '没通过契约校验：${details.isEmpty ? message : details.join('；')}',
        _ => '节点返回 $status：$message',
      };

  @override
  String toString() => 'NodeException($status, $message)';
}

/// A photo ready to upload: the exact bytes the node will hash.
class PhotoUpload {
  const PhotoUpload({required this.bytes, required this.contentType});

  final Uint8List bytes;
  final String contentType;

  String get sha256 => crypto.sha256.convert(bytes).toString();
}

class NodeClient {
  NodeClient({required this.baseUrl, required this.token, http.Client? client}) : _http = client ?? http.Client();

  final Uri baseUrl;
  final String token;
  final http.Client _http;

  Map<String, String> get authHeaders => {'Authorization': 'Bearer $token'};

  Uri _uri(String path) => baseUrl.replace(path: '${baseUrl.path.replaceAll(RegExp(r'/$'), '')}$path');

  /// URL for `Image.network`; pass [authHeaders] as its headers.
  Uri objectUrl(String key) => _uri('/v1/objects/$key');

  Future<void> ping() => _send('GET', '/v1/ping');

  Future<WardrobeIndex> fetchIndex() async => WardrobeIndex.fromJson(await _send('GET', '/v1/index'));

  Future<EventLog> fetchEvents() async => EventLog.fromJson(await _send('GET', '/v1/events'));

  Future<Item> putItem(String id, ItemFields fields) async {
    if (!ContractIds.pattern.hasMatch(id)) throw ContractError('id', 'Invalid item id $id.');
    fields.check();
    return Item.fromJson(await _send('PUT', '/v1/items/$id', json: fields.toJson()));
  }

  Future<CosKey> uploadItemPhoto(String itemId, PhotoUpload photo) async =>
      CosKey.fromJson(await _send('POST', '/v1/items/$itemId/photos', photo: photo));

  Future<WardrobeEvent> postEvent({required EventType type, required String date, required List<String> itemIds}) async =>
      WardrobeEvent.fromJson(
          await _send('POST', '/v1/events', json: {'type': type.name, 'date': date, 'item_ids': itemIds}));

  Future<CosKey> uploadLook(String eventId, PhotoUpload photo) async =>
      CosKey.fromJson(await _send('POST', '/v1/events/$eventId/look', photo: photo));

  void close() => _http.close();

  Future<Map<String, dynamic>> _send(String method, String path,
      {Map<String, dynamic>? json, PhotoUpload? photo}) async {
    final request = http.Request(method, _uri(path))..headers.addAll(authHeaders);
    if (json != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(json);
    } else if (photo != null) {
      request.headers['Content-Type'] = photo.contentType;
      request.headers['X-Sha256'] = photo.sha256;
      request.bodyBytes = photo.bytes;
    }

    final http.Response response;
    try {
      response = await http.Response.fromStream(await _http.send(request).timeout(const Duration(seconds: 30)));
    } on Exception catch (e) {
      throw NodeException(0, e.toString());
    }

    Object? body;
    try {
      body = jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      body = null;
    }
    if (response.statusCode >= 200 && response.statusCode < 300 && body is Map<String, dynamic>) {
      return body;
    }
    if (body is Map<String, dynamic>) {
      final details = [
        for (final d in (body['details'] as List?) ?? const [])
          if (d is Map) '${d['path']}: ${d['message']}',
      ];
      throw NodeException(response.statusCode, '${body['error'] ?? 'unknown error'}', details);
    }
    throw NodeException(response.statusCode, 'Unexpected response.');
  }
}
