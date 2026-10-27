import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import '../contract/models.dart';
import '../state/wardrobe_store.dart';
import 'design/components.dart';
import 'design/tokens.dart';
import 'home_shell.dart';
import 'item_detail_screen.dart';
import 'item_editor_screen.dart';
import 'widgets.dart';

/// Closet: an image-first wardrobe in a staggered two-column layout.
class WardrobeScreen extends StatefulWidget {
  const WardrobeScreen({super.key, required this.store, this.settings});

  final WardrobeStore store;
  final Widget? settings;

  @override
  State<WardrobeScreen> createState() => _WardrobeScreenState();
}

class _WardrobeScreenState extends State<WardrobeScreen> {
  Category? _category;
  ItemStatus _status = ItemStatus.active;

  void _add() => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => ItemEditorScreen(store: widget.store)));

  void _open(Item item) => Navigator.push(
        context,
        MaterialPageRoute<void>(builder: (_) => ItemDetailScreen(store: widget.store, itemId: item.id)),
      );

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.store,
      builder: (context, _) {
        final all = widget.store.index.items;
        final active = all.where((i) => i.fields.status == ItemStatus.active).length;
        final retired = all.length - active;
        final items = [
          for (final item in all)
            if (item.fields.status == _status && (_category == null || item.fields.category == _category)) item,
        ];
        return ORefresh(
          onRefresh: widget.store.refresh,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: OMasthead(
                  overline: 'Wardrobe',
                  title: 'Closet',
                  subtitle: retired == 0 ? '$active 件在穿' : '$active 件在穿 · $retired 件已退役',
                  actions: [
                    OIconButton(icon: CupertinoIcons.add, tooltip: '登记单品', onPressed: _add),
                    ?widget.settings,
                  ],
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: OSpace.sm),
                  child: OTextTabs<Category?>(
                    values: const [null, ...Category.values],
                    selected: _category,
                    labelOf: (c) => c?.label ?? '全部',
                    onSelected: (c) => setState(() => _category = c),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(OSpace.gutter, OSpace.sm, OSpace.gutter, OSpace.md),
                  child: Row(
                    children: [
                      Expanded(child: Text('${items.length} PIECES', style: OType.overline)),
                      for (final status in ItemStatus.values) ...[
                        const SizedBox(width: OSpace.xs),
                        OChip(label: status.label, selected: _status == status, onTap: () => setState(() => _status = status)),
                      ],
                    ],
                  ),
                ),
              ),
              if (items.isEmpty)
                SliverToBoxAdapter(
                  child: all.isEmpty
                      ? OEmpty(
                          line: 'Begin with a favourite.',
                          body: '平铺拍一张常穿的单品，光线均匀、背景干净。以后识别会用这些照片。',
                          action: OButton(label: '登记第一件', expand: false, icon: CupertinoIcons.add, onPressed: _add),
                        )
                      : const OEmpty(line: 'Nothing here.', body: '换一个分类或状态看看。'),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(OSpace.gutter, 0, OSpace.gutter, OSpace.xxl),
                  sliver: SliverToBoxAdapter(child: _Stagger(items: items, store: widget.store, onOpen: _open)),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Two columns; the right one starts lower, the way an editorial spread offsets its images.
class _Stagger extends StatelessWidget {
  const _Stagger({required this.items, required this.store, required this.onOpen});

  final List<Item> items;
  final WardrobeStore store;
  final ValueChanged<Item> onOpen;

  @override
  Widget build(BuildContext context) {
    Widget card(Item item) => Padding(
          padding: const EdgeInsets.only(bottom: OSpace.lg),
          child: OAssetCard(
            image: ItemImage(client: store.client, item: item, monogramSize: 56),
            title: itemTitle(item),
            subtitle: itemSubtitle(item),
            onTap: () => onOpen(item),
          ),
        );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: Column(children: [for (var i = 0; i < items.length; i += 2) card(items[i])])),
        const SizedBox(width: OSpace.md),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: OSpace.xl + OSpace.xs),
            child: Column(children: [for (var i = 1; i < items.length; i += 2) card(items[i])]),
          ),
        ),
      ],
    );
  }
}
