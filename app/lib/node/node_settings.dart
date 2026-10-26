import 'package:flutter_secure_storage/flutter_secure_storage.dart';

typedef NodeConnection = ({Uri url, String token});

/// Node address and pairing token, kept in the platform keychain/keystore.
class NodeSettings {
  NodeSettings([FlutterSecureStorage? storage]) : _storage = storage ?? const FlutterSecureStorage();

  static const _urlKey = 'node_url';
  static const _tokenKey = 'node_token';

  final FlutterSecureStorage _storage;

  Future<NodeConnection?> load() async {
    final url = await _storage.read(key: _urlKey);
    final token = await _storage.read(key: _tokenKey);
    if (url == null || token == null) return null;
    final parsed = Uri.tryParse(url);
    return parsed == null ? null : (url: parsed, token: token);
  }

  Future<void> save(NodeConnection connection) async {
    await _storage.write(key: _urlKey, value: connection.url.toString());
    await _storage.write(key: _tokenKey, value: connection.token);
  }

  Future<void> clear() async {
    await _storage.delete(key: _urlKey);
    await _storage.delete(key: _tokenKey);
  }
}

/// Accepts `192.168.1.5:8365` or a full `http://` URL. Returns null when it can't be a node address.
Uri? parseNodeUrl(String input) {
  var text = input.trim();
  if (text.isEmpty) return null;
  if (!text.contains('://')) text = 'http://$text';
  final uri = Uri.tryParse(text);
  if (uri == null || uri.host.isEmpty || (uri.scheme != 'http' && uri.scheme != 'https')) return null;
  return uri.hasPort ? uri : uri.replace(port: 8365);
}
