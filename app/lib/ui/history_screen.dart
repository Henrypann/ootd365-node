import 'package:flutter/material.dart';

import '../contract/models.dart';
import '../state/wardrobe_store.dart';
import 'widgets.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key, required this.store});

  final WardrobeStore store;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final events = store.events;
        if (events.isEmpty) return const Center(child: Text('还没有记录。'));
        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: events.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final event = events[i];
            final items = [for (final id in event.itemIds) store.index.byId(id)];
            return ListTile(
              leading: Icon(event.type == EventType.wear ? Icons.checkroom_outlined : Icons.local_laundry_service_outlined),
              title: Text('${event.date} · ${event.type.label}'),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: SizedBox(
                  height: 48,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      if (event.lookKey != null) _Thumb(child: NodeImage(client: store.client, objectKey: event.lookKey!.key)),
                      for (final item in items)
                        _Thumb(
                          child: item?.coverKey != null
                              ? NodeImage(client: store.client, objectKey: item!.coverKey!)
                              : Center(child: Text(item?.fields.color ?? '?', style: const TextStyle(fontSize: 10))),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        width: 48,
        margin: const EdgeInsets.only(right: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
        ),
        clipBehavior: Clip.antiAlias,
        child: child,
      );
}
