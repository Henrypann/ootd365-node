import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import '../contract/models.dart';
import '../state/wardrobe_store.dart';
import 'design/components.dart';
import 'design/tokens.dart';
import 'home_shell.dart';
import 'widgets.dart';

/// Archive: an editorial timeline, grouped by month. Outfits lead with their photo; washes stay quiet.
class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key, required this.store, this.settings});

  final WardrobeStore store;
  final Widget? settings;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final events = store.events;
        final wearDays = {for (final e in events) if (e.type == EventType.wear) e.date}.length;
        final months = <String, List<WardrobeEvent>>{};
        for (final e in events) {
          months.putIfAbsent(e.date.substring(0, 7), () => []).add(e);
        }
        return ORefresh(
          onRefresh: store.refresh,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: OMasthead(
                  overline: 'Life archive',
                  title: 'Archive',
                  subtitle: events.isEmpty ? null : '记下了 $wearDays 天的穿搭',
                  actions: [?settings],
                ),
              ),
              if (events.isEmpty)
                const SliverToBoxAdapter(
                  child: OEmpty(line: 'Your archive begins today.', body: '在「今天」记下第一套穿搭，它会出现在这里。'),
                )
              else
                for (final MapEntry(key: month, value: monthEvents) in months.entries) ...[
                  SliverToBoxAdapter(child: _MonthHeader(month)),
                  SliverList.builder(
                    itemCount: monthEvents.length,
                    itemBuilder: (context, i) {
                      final event = monthEvents[i];
                      return event.type == EventType.wear
                          ? _WearEntry(event: event, store: store)
                          : _WashEntry(event: event, store: store);
                    },
                  ),
                ],
              const SliverToBoxAdapter(child: SizedBox(height: OSpace.xxl)),
            ],
          ),
        );
      },
    );
  }
}

class _MonthHeader extends StatelessWidget {
  const _MonthHeader(this.month);

  /// `YYYY-MM`
  final String month;

  @override
  Widget build(BuildContext context) {
    final date = ODate.parse('$month-01');
    return Padding(
      padding: const EdgeInsets.fromLTRB(OSpace.gutter, OSpace.xl, OSpace.gutter, OSpace.md),
      child: Row(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(ODate.month(date), style: OType.headline),
              const SizedBox(width: OSpace.xs),
              Text('${date.year}', style: OType.serifItalic.copyWith(color: OColors.inkMuted)),
            ],
          ),
          const SizedBox(width: OSpace.md),
          const Expanded(child: Divider()),
        ],
      ),
    );
  }
}

/// Day number in serif with the weekday under it.
class _DateMark extends StatelessWidget {
  const _DateMark(this.date, {this.quiet = false});

  final String date;
  final bool quiet;

  @override
  Widget build(BuildContext context) {
    final day = ODate.parse(date);
    return SizedBox(
      width: 52,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${day.day}',
              style: OType.numeral.copyWith(fontSize: quiet ? 22 : 34, color: quiet ? OColors.inkFaint : OColors.ink)),
          const SizedBox(height: 2),
          Text(ODate.weekdayZh(day), style: OType.caption.copyWith(color: quiet ? OColors.inkFaint : OColors.inkMuted)),
        ],
      ),
    );
  }
}

class _WearEntry extends StatelessWidget {
  const _WearEntry({required this.event, required this.store});

  final WardrobeEvent event;
  final WardrobeStore store;

  @override
  Widget build(BuildContext context) {
    final items = [for (final id in event.itemIds) store.index.byId(id)];
    final names = [for (final i in items) if (i != null) i.fields.color].join('、');
    final look = event.lookKey;
    return Padding(
      padding: const EdgeInsets.fromLTRB(OSpace.gutter, OSpace.sm, OSpace.gutter, OSpace.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DateMark(event.date),
          const SizedBox(width: OSpace.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (look != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(ORadius.card),
                    child: AspectRatio(
                      aspectRatio: OAspect.look,
                      child: NodeImage(client: store.client, objectKey: look.key),
                    ),
                  ),
                  const SizedBox(height: OSpace.sm),
                ],
                Wrap(
                  spacing: OSpace.xs,
                  runSpacing: OSpace.xs,
                  children: [
                    for (final item in items)
                      SizedBox(
                        width: look == null ? 64 : 44,
                        child: AspectRatio(
                          aspectRatio: OAspect.asset,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(ORadius.tile - 6),
                            child: ItemImage(client: store.client, item: item, monogramSize: 16),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: OSpace.xs),
                Text('${items.length} 件 · $names', maxLines: 2, overflow: TextOverflow.ellipsis, style: OType.caption),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WashEntry extends StatelessWidget {
  const _WashEntry({required this.event, required this.store});

  final WardrobeEvent event;
  final WardrobeStore store;

  @override
  Widget build(BuildContext context) {
    final items = [for (final id in event.itemIds) store.index.byId(id)];
    final names = [for (final i in items) if (i != null) i.fields.color].join('、');
    return Padding(
      padding: const EdgeInsets.fromLTRB(OSpace.gutter, OSpace.xs, OSpace.gutter, OSpace.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DateMark(event.date, quiet: true),
          const SizedBox(width: OSpace.sm),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(OSpace.sm),
              decoration: BoxDecoration(color: OColors.surface, borderRadius: BorderRadius.circular(ORadius.tile)),
              child: Row(
                children: [
                  const Icon(CupertinoIcons.drop, size: 16, color: OColors.clay),
                  const SizedBox(width: OSpace.xs),
                  Expanded(
                    child: Text('洗涤 · $names', maxLines: 1, overflow: TextOverflow.ellipsis, style: OType.label),
                  ),
                  for (final item in items.take(4))
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: SizedBox(
                        width: 24,
                        height: 32,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: ItemImage(client: store.client, item: item, monogramSize: 11),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
