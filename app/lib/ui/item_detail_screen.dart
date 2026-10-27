import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import '../contract/models.dart';
import '../state/wardrobe_store.dart';
import 'design/components.dart';
import 'design/tokens.dart';
import 'item_editor_screen.dart';
import 'widgets.dart';

/// One wardrobe asset: full-bleed photos, its numbers in serif, and the two things you do to it.
class ItemDetailScreen extends StatefulWidget {
  const ItemDetailScreen({super.key, required this.store, required this.itemId});

  final WardrobeStore store;
  final String itemId;

  @override
  State<ItemDetailScreen> createState() => _ItemDetailScreenState();
}

class _ItemDetailScreenState extends State<ItemDetailScreen> {
  bool _busy = false;
  int _page = 0;

  Future<void> _run(Future<void> Function() action, String done) async {
    setState(() => _busy = true);
    try {
      await action();
      if (mounted) showMessage(context, done);
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
          return Scaffold(
            appBar: AppBar(),
            body: const OEmpty(line: 'Gone from the closet.', body: '节点上已经没有这件单品了。'),
          );
        }
        final f = item.fields;
        final lastWorn = widget.store.events
            .where((e) => e.type == EventType.wear && e.itemIds.contains(item.id))
            .map((e) => e.date)
            .firstOrNull;
        final top = MediaQuery.paddingOf(context).top;
        return Scaffold(
          body: Stack(
            children: [
              ListView(
                padding: EdgeInsets.zero,
                children: [
                  _Gallery(item: item, store: widget.store, page: _page, onPage: (p) => setState(() => _page = p)),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(OSpace.gutter, OSpace.lg, OSpace.gutter, OSpace.xxl),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${categoryOverline(f.category)} · ${f.category.label}'.toUpperCase(), style: OType.overline),
                        const SizedBox(height: OSpace.xs),
                        Text(f.color, style: OType.heading),
                        const SizedBox(height: OSpace.lg),
                        _Stats(stats: [
                          ('${item.wearCount}', '穿着'),
                          ('${item.washCount}', '洗涤'),
                          (lastWorn == null ? '—' : _short(lastWorn), '最近一次'),
                        ]),
                        const SizedBox(height: OSpace.lg),
                        _Detail('季节', f.season.isEmpty ? '未记录' : [for (final s in Season.values) if (f.season.contains(s)) s.label].join(' · ')),
                        _Detail('入手', f.acquiredAt ?? '未记录'),
                        _Detail('状态', f.status.label),
                        const SizedBox(height: OSpace.xl),
                        OButton(
                          label: '今天洗了',
                          icon: CupertinoIcons.drop,
                          kind: OButtonKind.secondary,
                          busy: _busy,
                          onPressed: () => _run(
                            () => widget.store.logWash(day: DateTime.now(), itemIds: [item.id]),
                            '已记下今天洗了',
                          ),
                        ),
                        if (f.status == ItemStatus.active) ...[
                          const SizedBox(height: OSpace.xs),
                          OButton(
                            label: '退役这件',
                            kind: OButtonKind.quiet,
                            onPressed: _busy ? null : () => _retire(item),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              Positioned(
                top: top + OSpace.xs,
                left: OSpace.md,
                child: OIconButton(icon: CupertinoIcons.chevron_back, tooltip: '返回', onPressed: () => Navigator.maybePop(context)),
              ),
              Positioned(
                top: top + OSpace.xs,
                right: OSpace.md,
                child: OIconButton(
                  icon: CupertinoIcons.pencil,
                  tooltip: '编辑',
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(builder: (_) => ItemEditorScreen(store: widget.store, item: item)),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// `2026-10-26` → `10.26`
  static String _short(String date) {
    final d = ODate.parse(date);
    return '${d.month}.${d.day}';
  }

  Future<void> _retire(Item item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('退役这件？'),
        content: const Text('它会从「今天」的选择里消失，档案里的记录和照片都保留。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(foregroundColor: OColors.inkMuted),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: OColors.ink),
            child: const Text('退役'),
          ),
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
      '已退役，记录都还在',
    );
  }
}

class _Gallery extends StatelessWidget {
  const _Gallery({required this.item, required this.store, required this.page, required this.onPage});

  final Item item;
  final WardrobeStore store;
  final int page;
  final ValueChanged<int> onPage;

  @override
  Widget build(BuildContext context) {
    final keys = item.cosKeys;
    return AspectRatio(
      aspectRatio: OAspect.look,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (keys.isEmpty)
            OMonogram(text: item.fields.color, size: 120)
          else
            PageView(
              onPageChanged: onPage,
              children: [for (final k in keys) NodeImage(client: store.client, objectKey: k.key)],
            ),
          if (keys.length > 1)
            Positioned(
              bottom: OSpace.md,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < keys.length; i++)
                    AnimatedContainer(
                      duration: OMotion.quick,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: i == page ? 16 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: i == page ? OColors.surface : OColors.surface.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(ORadius.pill),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Stats extends StatelessWidget {
  const _Stats({required this.stats});

  final List<(String, String)> stats;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: OSpace.md),
        decoration: BoxDecoration(color: OColors.surface, borderRadius: BorderRadius.circular(ORadius.card)),
        child: IntrinsicHeight(
          child: Row(
            children: [
              for (final (i, (value, label)) in stats.indexed) ...[
                if (i > 0) const VerticalDivider(width: 1, thickness: 0.5, color: OColors.line),
                Expanded(
                  child: Column(
                    children: [
                      Text(value, style: OType.numeral.copyWith(fontSize: 32)),
                      const SizedBox(height: OSpace.xxs),
                      Text(label, style: OType.caption),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      );
}

class _Detail extends StatelessWidget {
  const _Detail(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: OColors.line, width: 0.5))),
        child: Row(children: [
          Expanded(child: Text(label, style: OType.bodyMuted)),
          Text(value, style: OType.body),
        ]),
      );
}
