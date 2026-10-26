import 'package:flutter/material.dart';

import '../contract/models.dart';
import '../state/wardrobe_store.dart';
import 'item_editor_screen.dart';
import 'widgets.dart';

class ItemDetailScreen extends StatefulWidget {
  const ItemDetailScreen({super.key, required this.store, required this.itemId});

  final WardrobeStore store;
  final String itemId;

  @override
  State<ItemDetailScreen> createState() => _ItemDetailScreenState();
}

class _ItemDetailScreenState extends State<ItemDetailScreen> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action, String done) async {
    setState(() => _busy = true);
    try {
      await action();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(done)));
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.store,
      builder: (context, _) {
        final item = widget.store.index.byId(widget.itemId);
        if (item == null) {
          return Scaffold(appBar: AppBar(), body: const Center(child: Text('节点上没有这件单品了。')));
        }
        final f = item.fields;
        final lastWorn = widget.store.events
            .where((e) => e.type == EventType.wear && e.itemIds.contains(item.id))
            .map((e) => e.date)
            .firstOrNull;
        return Scaffold(
          appBar: AppBar(
            title: Text('${f.color} ${f.category.label}'),
            actions: [
              IconButton(
                tooltip: '编辑',
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(builder: (_) => ItemEditorScreen(store: widget.store, item: item)),
                ),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (item.cosKeys.isNotEmpty)
                SizedBox(
                  height: 240,
                  child: PageView(
                    children: [
                      for (final key in item.cosKeys)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: NodeImage(client: widget.store.client, objectKey: key.key, fit: BoxFit.contain),
                        ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              _Row('分类', f.category.label),
              _Row('季节', f.season.isEmpty ? '没填' : [for (final s in Season.values) if (f.season.contains(s)) s.label].join('、')),
              _Row('入手', f.acquiredAt ?? '没填'),
              _Row('状态', f.status.label),
              _Row('穿着次数', '${item.wearCount}'),
              _Row('洗涤次数', '${item.washCount}'),
              _Row('最近一次穿', lastWorn ?? '没有记录'),
              const SizedBox(height: 24),
              FilledButton.tonalIcon(
                onPressed: _busy
                    ? null
                    : () => _run(
                          () => widget.store.logWash(day: DateTime.now(), itemIds: [item.id]),
                          '记下今天洗了',
                        ),
                icon: const Icon(Icons.local_laundry_service_outlined),
                label: const Text('今天洗了'),
              ),
              const SizedBox(height: 8),
              if (f.status == ItemStatus.active)
                OutlinedButton.icon(
                  onPressed: _busy ? null : () => _retire(item),
                  icon: const Icon(Icons.archive_outlined),
                  label: const Text('退役'),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _retire(Item item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('退役这件？'),
        content: const Text('它会从「今天穿了什么」里消失，记录和照片都保留。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('退役')),
        ],
      ),
    );
    if (ok != true) return;
    final f = item.fields;
    await _run(
      () => widget.store.saveItem(
        item.id,
        ItemFields(category: f.category, season: f.season, color: f.color, status: ItemStatus.retired, acquiredAt: f.acquiredAt),
        const [],
      ),
      '已退役',
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          SizedBox(width: 96, child: Text(label, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey))),
          Expanded(child: Text(value)),
        ]),
      );
}
