import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import '../node/node_client.dart';
import '../node/node_settings.dart';
import 'design/components.dart';
import 'design/tokens.dart';

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
    final canPop = Navigator.canPop(context);
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(OSpace.gutter, OSpace.md, OSpace.gutter, OSpace.xl),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: canPop
                  ? OIconButton(icon: CupertinoIcons.chevron_back, tooltip: '返回', filled: false, onPressed: () => Navigator.maybePop(context))
                  : const SizedBox(height: 40),
            ),
            const SizedBox(height: OSpace.xl),
            const Text('ootd365', style: TextStyle(fontFamily: OType.serif, fontSize: 56, height: 1, color: OColors.ink, letterSpacing: -1)),
            const SizedBox(height: OSpace.sm),
            Text('Your wardrobe, your days,\nkept at home.', style: OType.serifItalic.copyWith(fontSize: 22, height: 1.3)),
            const SizedBox(height: OSpace.lg),
            const Text('照片和记录都存在你家里的电脑或 Pi 上。在那台机器运行 npm run serve，把它打印的地址和令牌填在这里，手机和它连同一个 Wi-Fi。', style: OType.bodyMuted),
            const SizedBox(height: OSpace.xl),
            TextField(
              controller: _url,
              keyboardType: TextInputType.url,
              autocorrect: false,
              style: OType.body.copyWith(fontSize: 17),
              decoration: const InputDecoration(labelText: 'NODE ADDRESS  地址', hintText: '192.168.1.5:8365'),
            ),
            const SizedBox(height: OSpace.lg),
            TextField(
              controller: _token,
              autocorrect: false,
              enableSuggestions: false,
              style: OType.body.copyWith(fontSize: 17),
              decoration: const InputDecoration(labelText: 'PAIRING TOKEN  令牌'),
            ),
            if (_error != null) ...[
              const SizedBox(height: OSpace.md),
              Text(_error!, style: OType.label.copyWith(color: OColors.error, height: 1.45)),
            ],
            const SizedBox(height: OSpace.xl),
            OButton(label: '连接', busy: _busy, onPressed: _connect),
            const SizedBox(height: OSpace.md),
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.lock, size: 13, color: OColors.inkFaint),
                SizedBox(width: 6),
                Text('令牌只存在这台手机的钥匙串里', style: OType.caption),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
