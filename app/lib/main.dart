import 'package:flutter/material.dart';

import 'node/node_client.dart';
import 'node/node_settings.dart';
import 'state/wardrobe_store.dart';
import 'ui/connect_screen.dart';
import 'ui/home_shell.dart';

void main() {
  runApp(const OotdApp());
}

class OotdApp extends StatelessWidget {
  const OotdApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ootd365',
      theme: ThemeData(colorSchemeSeed: const Color(0xFF3B4A6B)),
      darkTheme: ThemeData(colorSchemeSeed: const Color(0xFF3B4A6B), brightness: Brightness.dark),
      home: const _Root(),
    );
  }
}

/// Shows Connect until a node is paired, then the three tabs.
class _Root extends StatefulWidget {
  const _Root();

  @override
  State<_Root> createState() => _RootState();
}

class _RootState extends State<_Root> {
  final _settings = NodeSettings();
  NodeConnection? _connection;
  WardrobeStore? _store;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _settings.load().then((connection) {
      if (!mounted) return;
      setState(() {
        _loaded = true;
        if (connection != null) _use(connection);
      });
    });
  }

  void _use(NodeConnection connection) {
    _store?.client.close();
    _store?.dispose();
    _connection = connection;
    _store = WardrobeStore(NodeClient(baseUrl: connection.url, token: connection.token));
  }

  Future<void> _connected(NodeConnection connection) async {
    await _settings.save(connection);
    if (!mounted) return;
    setState(() => _use(connection));
  }

  void _openConnect() {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (context) => ConnectScreen(
          initial: _connection,
          onConnected: (connection) {
            Navigator.pop(context);
            _connected(connection);
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    _store?.client.close();
    _store?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final store = _store;
    if (store == null) return ConnectScreen(onConnected: _connected);
    // A new key per connection so the shell reloads from the new node.
    return HomeShell(key: ObjectKey(store), store: store, onOpenConnect: _openConnect);
  }
}
