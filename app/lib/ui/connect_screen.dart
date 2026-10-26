import 'package:flutter/material.dart';

import '../node/node_client.dart';
import '../node/node_settings.dart';

/// Pairs the app with a node: address plus the token `npm run serve` prints.
class ConnectScreen extends StatefulWidget {
  const ConnectScreen({super.key, required this.onConnected, this.initial});

  final ValueChanged<NodeConnection> onConnected;
  final NodeConnection? initial;

  @override
  State<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends State<ConnectScreen> {
  late final _url = TextEditingController(text: widget.initial?.url.toString() ?? '');
  late final _token = TextEditingController(text: widget.initial?.token ?? '');
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _url.dispose();
    _token.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    final url = parseNodeUrl(_url.text);
    final token = _token.text.trim();
    if (url == null || token.isEmpty) {
      setState(() => _error = '地址和令牌都要填。');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final client = NodeClient(baseUrl: url, token: token);
    try {
      await client.ping();
      widget.onConnected((url: url, token: token));
    } on NodeException catch (e) {
      if (mounted) setState(() => _error = e.userMessage);
    } finally {
      client.close();
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('连接节点')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('在家里的电脑或 Pi 上运行 npm run serve，把它打印的地址和令牌填在这里。手机要和它在同一个 Wi-Fi。'),
          const SizedBox(height: 16),
          TextField(
            controller: _url,
            keyboardType: TextInputType.url,
            autocorrect: false,
            decoration: const InputDecoration(labelText: '地址', hintText: 'http://192.168.1.5:8365'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _token,
            autocorrect: false,
            enableSuggestions: false,
            decoration: const InputDecoration(labelText: '令牌'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _busy ? null : _connect,
            child: Text(_busy ? '连接中…' : '连接'),
          ),
        ],
      ),
    );
  }
}
