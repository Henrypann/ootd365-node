import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../contract/models.dart';
import '../node/node_client.dart';
import '../state/wardrobe_store.dart';
import 'widgets.dart';

typedef PhotoPicker = Future<PhotoUpload?> Function(BuildContext context);

/// The daily loop: optional mirror photo, tap what you wore, save. Aim for under 30 seconds.
class LogScreen extends StatefulWidget {
  const LogScreen({super.key, required this.store, this.pickPhotoOverride, this.today});

  final WardrobeStore store;

  /// Tests swap out the camera.
  final PhotoPicker? pickPhotoOverride;
  final DateTime Function()? today;

  @override
  State<LogScreen> createState() => _LogScreenState();
}

class _LogScreenState extends State<LogScreen> {
  final _selected = <String>{};
  late DateTime _day = _today();
  PhotoUpload? _look;
  bool _saving = false;

  DateTime _today() {
    final now = (widget.today ?? DateTime.now)();
    return DateTime(now.year, now.month, now.day);
  }

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

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await widget.store.logWear(day: _day, itemIds: _selected.toList(), look: _look);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('记下了 ${_selected.length} 件，${contractDate(_day)}')));
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
        final isToday = _day == _today();
        return Scaffold(
          body: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    children: [
                      _LookButton(bytes: _look?.bytes, onTap: _pickLook),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(isToday ? '今天穿了什么' : '那天穿了什么', style: Theme.of(context).textTheme.titleLarge),
                            TextButton.icon(
                              onPressed: _pickDay,
                              icon: const Icon(Icons.event_outlined),
                              label: Text(contractDate(_day)),
                            ),
                            Text(_look == null ? '镜子照片可选' : '已选镜子照片',
                                style: Theme.of(context).textTheme.bodySmall),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (items.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: Text('衣橱还是空的。先去「衣橱」登记几件。')),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                  sliver: SliverGrid.builder(
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 120,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                    ),
                    itemCount: items.length,
                    itemBuilder: (context, i) {
                      final item = items[i];
                      final selected = _selected.contains(item.id);
                      return ItemTile(
                        key: ValueKey(item.id),
                        client: widget.store.client,
                        coverKey: item.coverKey,
                        caption: '${item.fields.color} ${item.fields.category.label}',
                        selected: selected,
                        onTap: () => setState(() => selected ? _selected.remove(item.id) : _selected.add(item.id)),
                      );
                    },
                  ),
                ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            // The tabs live in one IndexedStack, so each FAB needs its own hero tag.
            heroTag: 'log-save',
            onPressed: _selected.isEmpty || _saving ? null : _save,
            icon: const Icon(Icons.check),
            label: Text(_saving ? '保存中…' : '记下 ${_selected.length} 件'),
          ),
        );
      },
    );
  }
}

class _LookButton extends StatelessWidget {
  const _LookButton({required this.bytes, required this.onTap});

  final Uint8List? bytes;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 84,
        height: 112,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
        ),
        clipBehavior: Clip.antiAlias,
        child: bytes == null
            ? const Icon(Icons.add_a_photo_outlined, size: 32)
            : Image.memory(bytes!, fit: BoxFit.cover),
      ),
    );
  }
}
