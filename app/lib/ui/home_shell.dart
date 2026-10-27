import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import '../state/wardrobe_store.dart';
import 'design/components.dart';
import 'design/tokens.dart';
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
  static const _nav = [
    ONavItem(icon: CupertinoIcons.sun_max, activeIcon: CupertinoIcons.sun_max_fill, label: '今天'),
    ONavItem(icon: CupertinoIcons.square_grid_2x2, activeIcon: CupertinoIcons.square_grid_2x2_fill, label: '衣橱'),
    ONavItem(icon: CupertinoIcons.book, activeIcon: CupertinoIcons.book_fill, label: '档案'),
  ];

  int _tab = 0;

  @override
  void initState() {
    super.initState();
    widget.store.refresh();
  }

  @override
  Widget build(BuildContext context) {
    final settings = OIconButton(
      icon: CupertinoIcons.slider_horizontal_3,
      tooltip: '连接节点',
      filled: false,
      onPressed: widget.onOpenConnect,
    );
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            ListenableBuilder(
              listenable: widget.store,
              builder: (context, _) => AnimatedSize(
                duration: OMotion.standard,
                curve: OMotion.curve,
                child: widget.store.error == null
                    ? const SizedBox(width: double.infinity)
                    : ONotice(message: widget.store.error!, actionLabel: '重试', onAction: widget.store.refresh),
              ),
            ),
            Expanded(
              child: IndexedStack(
                index: _tab,
                children: [
                  LogScreen(store: widget.store, settings: settings, onOpenCloset: () => setState(() => _tab = 1)),
                  WardrobeScreen(store: widget.store, settings: settings),
                  HistoryScreen(store: widget.store, settings: settings),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: ONavBar(items: _nav, index: _tab, onSelected: (i) => setState(() => _tab = i)),
    );
  }
}

/// Pull-to-refresh styled to the system: ink spinner on paper.
class ORefresh extends StatelessWidget {
  const ORefresh({super.key, required this.onRefresh, required this.child});

  final Future<void> Function() onRefresh;
  final Widget child;

  @override
  Widget build(BuildContext context) => RefreshIndicator(
        onRefresh: onRefresh,
        color: OColors.ink,
        backgroundColor: OColors.surface,
        strokeWidth: 1.6,
        child: child,
      );
}
