import 'package:flutter/material.dart';

import '../state/wardrobe_store.dart';
import 'history_screen.dart';
import 'log_screen.dart';
import 'wardrobe_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.store, required this.onOpenConnect});

  final WardrobeStore store;
  final VoidCallback onOpenConnect;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  static const _titles = ['今天', '衣橱', '记录'];
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    widget.store.refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_tab]),
        actions: [
          IconButton(tooltip: '刷新', icon: const Icon(Icons.refresh), onPressed: widget.store.refresh),
          IconButton(tooltip: '连接节点', icon: const Icon(Icons.settings_outlined), onPressed: widget.onOpenConnect),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(2),
          child: ListenableBuilder(
            listenable: widget.store,
            builder: (context, _) =>
                widget.store.loading ? const LinearProgressIndicator(minHeight: 2) : const SizedBox(height: 2),
          ),
        ),
      ),
      body: Column(
        children: [
          ListenableBuilder(
            listenable: widget.store,
            builder: (context, _) => widget.store.error == null
                ? const SizedBox.shrink()
                : MaterialBanner(
                    content: Text(widget.store.error!),
                    actions: [TextButton(onPressed: widget.store.refresh, child: const Text('重试'))],
                  ),
          ),
          Expanded(
            child: IndexedStack(
              index: _tab,
              children: [
                LogScreen(store: widget.store),
                WardrobeScreen(store: widget.store),
                HistoryScreen(store: widget.store),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.today_outlined), label: '今天'),
          NavigationDestination(icon: Icon(Icons.checkroom_outlined), label: '衣橱'),
          NavigationDestination(icon: Icon(Icons.history), label: '记录'),
        ],
      ),
    );
  }
}
