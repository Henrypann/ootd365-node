import 'package:flutter/material.dart';

import '../contract/models.dart';
import '../state/wardrobe_store.dart';
import 'item_detail_screen.dart';
import 'item_editor_screen.dart';
import 'widgets.dart';

class WardrobeScreen extends StatefulWidget {
  const WardrobeScreen({super.key, required this.store});

  final WardrobeStore store;

  @override
  State<WardrobeScreen> createState() => _WardrobeScreenState();
}

class _WardrobeScreenState extends State<WardrobeScreen> {
  Category? _category;
  ItemStatus _status = ItemStatus.active;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.store,
      builder: (context, _) {
        final items = [
          for (final item in widget.store.index.items)
            if (item.fields.status == _status && (_category == null || item.fields.category == _category)) item,
        ];
        return Scaffold(
          body: Column(
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Row(
                  spacing: 8,
                  children: [
                    for (final status in ItemStatus.values)
                      ChoiceChip(
                        label: Text(status.label),
                        selected: _status == status,
                        onSelected: (_) => setState(() => _status = status),
                      ),
                    const SizedBox(width: 8),
                    for (final category in Category.values)
                      FilterChip(
                        label: Text(category.label),
                        selected: _category == category,
                        onSelected: (on) => setState(() => _category = on ? category : null),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: items.isEmpty
                    ? const Center(child: Text('这里还没有单品。'))
                    : GridView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 140,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                        ),
                        itemCount: items.length,
                        itemBuilder: (context, i) {
                          final item = items[i];
                          return ItemTile(
                            client: widget.store.client,
                            coverKey: item.coverKey,
                            caption: '${item.fields.color} ${item.fields.category.label} · 穿 ${item.wearCount}',
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute<void>(
                                builder: (_) => ItemDetailScreen(store: widget.store, itemId: item.id),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            heroTag: 'wardrobe-add',
            tooltip: '登记单品',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(builder: (_) => ItemEditorScreen(store: widget.store)),
            ),
            child: const Icon(Icons.add),
          ),
        );
      },
    );
  }
}
