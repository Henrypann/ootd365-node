import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import '../contract/models.dart';
import '../node/node_client.dart';
import '../state/wardrobe_store.dart';
import 'design/components.dart';
import 'design/tokens.dart';
import 'home_shell.dart';
import 'widgets.dart';

typedef PhotoPicker = Future<PhotoUpload?> Function(BuildContext context);

/// Today: the daily loop. Optional photo, tap what you wore by category, record. Aim for under 30 seconds.
class LogScreen extends StatefulWidget {
  const LogScreen({super.key, required this.store, this.pickPhotoOverride, this.today, this.settings, this.onOpenCloset});

  final WardrobeStore store;

  /// Tests swap out the camera.
  final PhotoPicker? pickPhotoOverride;
  final DateTime Function()? today;
  final Widget? settings;
  final VoidCallback? onOpenCloset;

  @override
  State<LogScreen> createState() => _LogScreenState();
}

class _LogScreenState extends State<LogScreen> {
  final _selected = <String>[];
  late DateTime _day = _today();
  PhotoUpload? _look;
  bool _saving = false;

  DateTime _today() {
    final now = (widget.today ?? DateTime.now)();
    return DateTime(now.year, now.month, now.day);
  }

  bool get _isToday => _day == _today();

  Future<void> _pickLook() async {
    final photo = await (widget.pickPhotoOverride ?? pickPhoto)(context);
    if (photo != null) setState(() => _look = photo);
  }

  Future<void> _pickDay() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _day,
      firstDate: DateTime(2000),
      lastDate: _today(),
    );
    if (picked != null) setState(() => _day = picked);
  }

  void _toggle(String id) => setState(() => _selected.contains(id) ? _selected.remove(id) : _selected.add(id));

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await widget.store.logWear(day: _day, itemIds: List.of(_selected), look: _look);
      if (!mounted) return;
      showMessage(context, '已存进档案 · ${_day.month}月${_day.day}日 · ${_selected.length} 件');
      setState(() {
        _selected.clear();
        _look = null;
        _day = _today();
      });
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.store,
      builder: (context, _) {
        final items = widget.store.activeItems;
        // Drop selections for items that were retired elsewhere.
        _selected.removeWhere((id) => !items.any((i) => i.id == id));
        return Stack(
          children: [
            ORefresh(
              onRefresh: widget.store.refresh,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: OMasthead(
                      overline: _isToday ? '${ODate.weekday(_day)} · Today' : '${ODate.weekday(_day)} · ${_day.year}',
                      title: '${ODate.month(_day)} ${_day.day}',
                      subtitle: _isToday ? '今天穿了什么？' : '那天穿了什么？',
                      onTitleTap: _pickDay,
                      actions: [?widget.settings],
                    ),
                  ),
                  SliverToBoxAdapter(child: _LookCard(look: _look, onPick: _pickLook, onClear: () => setState(() => _look = null))),
                  if (items.isEmpty)
                    SliverToBoxAdapter(
                      child: OEmpty(
                        line: 'Your closet is quiet.',
                        body: '先去衣橱登记几件常穿的单品，之后每天点选就能记下来。',
                        action: widget.onOpenCloset == null
                            ? null
                            : OButton(label: '去衣橱', kind: OButtonKind.secondary, expand: false, onPressed: widget.onOpenCloset),
                      ),
                    )
                  else
                    for (final category in Category.values)
                      if (items.any((i) => i.fields.category == category))
                        SliverToBoxAdapter(
                          child: _CategoryRail(
                            category: category,
                            items: [for (final i in items) if (i.fields.category == category) i],
                            selected: _selected,
                            client: widget.store.client,
                            onToggle: _toggle,
                          ),
                        ),
                  const SliverToBoxAdapter(child: SizedBox(height: 120)),
                ],
              ),
            ),
            if (items.isNotEmpty)
              Positioned(
                left: OSpace.md,
                right: OSpace.md,
                bottom: OSpace.md,
                child: _RecordBar(
                  selected: [for (final id in _selected) widget.store.index.byId(id)],
                  client: widget.store.client,
                  isToday: _isToday,
                  saving: _saving,
                  onSave: _save,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _LookCard extends StatelessWidget {
  const _LookCard({required this.look, required this.onPick, required this.onClear});

  final PhotoUpload? look;
  final VoidCallback onPick;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final photo = look;
    return Padding(
      padding: const EdgeInsets.fromLTRB(OSpace.gutter, OSpace.md, OSpace.gutter, 0),
      child: AnimatedSwitcher(
        duration: OMotion.standard,
        child: photo == null
            ? Material(
                key: const ValueKey('empty'),
                color: OColors.surface,
                borderRadius: BorderRadius.circular(ORadius.card),
                child: InkWell(
                  borderRadius: BorderRadius.circular(ORadius.card),
                  onTap: onPick,
                  child: Padding(
                    padding: const EdgeInsets.all(OSpace.sm),
                    child: Row(
                      children: [
                        Container(
                          width: 56,
                          height: 70,
                          decoration: BoxDecoration(color: OColors.sand, borderRadius: BorderRadius.circular(ORadius.tile - 4)),
                          child: const Icon(CupertinoIcons.camera, size: 20, color: OColors.inkSoft),
                        ),
                        const SizedBox(width: OSpace.md),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('今日照片', style: OType.title),
                              SizedBox(height: 2),
                              Text('可选 · 一张镜子照，只存在你家里', style: OType.caption),
                            ],
                          ),
                        ),
                        const Icon(CupertinoIcons.add, size: 18, color: OColors.inkMuted),
                        const SizedBox(width: OSpace.xs),
                      ],
                    ),
                  ),
                ),
              )
            : ClipRRect(
                key: const ValueKey('photo'),
                borderRadius: BorderRadius.circular(ORadius.card),
                child: AspectRatio(
                  aspectRatio: OAspect.look,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.memory(photo.bytes, fit: BoxFit.cover),
                      Positioned(
                        top: OSpace.sm,
                        right: OSpace.sm,
                        child: Row(children: [
                          OIconButton(icon: CupertinoIcons.arrow_2_circlepath, tooltip: '换一张', onPressed: onPick),
                          const SizedBox(width: OSpace.xs),
                          OIconButton(icon: CupertinoIcons.xmark, tooltip: '去掉照片', onPressed: onClear),
                        ]),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}

class _CategoryRail extends StatelessWidget {
  const _CategoryRail({required this.category, required this.items, required this.selected, required this.client, required this.onToggle});

  final Category category;
  final List<Item> items;
  final List<String> selected;
  final NodeClient client;
  final ValueChanged<String> onToggle;

  static const _cardWidth = 112.0;

  @override
  Widget build(BuildContext context) {
    final picked = items.where((i) => selected.contains(i.id)).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OSectionHeader(
          '${categoryOverline(category)}  ${category.label}',
          trailing: picked == 0 ? '${items.length}' : '已选 $picked',
        ),
        SizedBox(
          height: _cardWidth / OAspect.asset + 30,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: OSpace.gutter),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(width: OSpace.sm),
            itemBuilder: (context, i) {
              final item = items[i];
              return SizedBox(
                width: _cardWidth,
                child: OAssetCard(
                  key: ValueKey(item.id),
                  image: ItemImage(client: client, item: item),
                  title: itemTitle(item),
                  semanticLabel: '${item.fields.color} ${item.fields.category.label}',
                  selected: selected.contains(item.id),
                  onTap: () => onToggle(item.id),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Floating record bar: what you picked, and one understated action.
class _RecordBar extends StatelessWidget {
  const _RecordBar({required this.selected, required this.client, required this.isToday, required this.saving, required this.onSave});

  final List<Item?> selected;
  final NodeClient client;
  final bool isToday;
  final bool saving;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final count = selected.length;
    return Container(
      padding: const EdgeInsets.fromLTRB(OSpace.md, OSpace.xs, OSpace.xs, OSpace.xs),
      decoration: BoxDecoration(
        color: OColors.surface,
        borderRadius: BorderRadius.circular(ORadius.pill),
        boxShadow: const [BoxShadow(color: Color(0x1A2A2420), blurRadius: 24, offset: Offset(0, 8))],
      ),
      child: Row(
        children: [
          if (count > 0) ...[
            SizedBox(
              width: 28.0 + 16.0 * (count.clamp(1, 3) - 1),
              height: 32,
              child: Stack(
                children: [
                  for (final (i, item) in selected.take(3).indexed)
                    Positioned(
                      left: i * 16.0,
                      child: Container(
                        width: 28,
                        height: 32,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: OColors.surface, width: 2),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: ItemImage(client: client, item: item, monogramSize: 12),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: OSpace.sm),
          ],
          Expanded(
            child: AnimatedSwitcher(
              duration: OMotion.quick,
              layoutBuilder: (current, previous) =>
                  Stack(alignment: Alignment.centerLeft, children: [...previous, ?current]),
              child: Text(
                count == 0 ? '点选今天穿的单品' : '已选 $count 件',
                key: ValueKey(count),
                style: count == 0 ? OType.bodyMuted : OType.label.copyWith(fontSize: 15),
              ),
            ),
          ),
          OButton(
            label: isToday ? '记下今天' : '记下那天',
            expand: false,
            busy: saving,
            onPressed: count == 0 ? null : onSave,
          ),
        ],
      ),
    );
  }
}
