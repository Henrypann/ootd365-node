import 'package:flutter/material.dart';

import '../contract/models.dart';
import '../node/node_client.dart';
import '../state/wardrobe_store.dart';
import 'widgets.dart';

/// Registers a new item, or edits the human fields of an existing one.
/// Photos already on the node are never replaced; new ones are added.
class ItemEditorScreen extends StatefulWidget {
  const ItemEditorScreen({super.key, required this.store, this.item});

  final WardrobeStore store;
  final Item? item;

  @override
  State<ItemEditorScreen> createState() => _ItemEditorScreenState();
}

class _ItemEditorScreenState extends State<ItemEditorScreen> {
  static const _maxNewPhotos = 3;

  // Allocated once, so a retry after a failed photo upload updates the same item.
  late final String _id = widget.item?.id ?? ContractIds.newItemId();
  late Category _category = widget.item?.fields.category ?? Category.top;
  late final Set<Season> _seasons = {...?widget.item?.fields.season};
  late final _color = TextEditingController(text: widget.item?.fields.color ?? '');
  late ItemStatus _status = widget.item?.fields.status ?? ItemStatus.active;
  late String? _acquiredAt = widget.item?.fields.acquiredAt;
  final _photos = <PhotoUpload>[];
  bool _saving = false;

  bool get _isNew => widget.item == null;

  @override
  void dispose() {
    _color.dispose();
    super.dispose();
  }

  Future<void> _addPhoto() async {
    final photo = await pickPhoto(context);
    if (photo != null) setState(() => _photos.add(photo));
  }

  Future<void> _pickAcquired() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(1950),
      lastDate: now,
      helpText: '什么时候买的（不确定就别填）',
    );
    if (picked != null) setState(() => _acquiredAt = contractDate(picked));
  }

  Future<void> _save() async {
    final fields = ItemFields(
      category: _category,
      season: _seasons,
      color: _color.text,
      status: _status,
      acquiredAt: _acquiredAt,
    );
    try {
      fields.check();
    } on ContractError catch (e) {
      showError(context, e.message);
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.store.saveItem(_id, fields, List.of(_photos));
      if (mounted) Navigator.pop(context);
    } catch (e) {
      // Photos that did upload are on the node now; drop them so a retry doesn't send duplicates.
      await widget.store.refresh();
      final uploaded = widget.store.index.byId(_id)?.cosKeys.map((k) => k.sha256).toSet() ?? {};
      _photos.removeWhere((p) => uploaded.contains(p.sha256));
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final existing = widget.item?.cosKeys ?? const <CosKey>[];
    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? '登记单品' : '编辑单品'),
        actions: [
          TextButton(onPressed: _saving ? null : _save, child: Text(_saving ? '保存中…' : '保存')),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SizedBox(
            height: 112,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final key in existing)
                  _PhotoBox(child: NodeImage(client: widget.store.client, objectKey: key.key)),
                for (final (i, photo) in _photos.indexed)
                  _PhotoBox(
                    child: Stack(fit: StackFit.expand, children: [
                      Image.memory(photo.bytes, fit: BoxFit.cover),
                      Positioned(
                        top: 0,
                        right: 0,
                        child: IconButton.filledTonal(
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.close, size: 16),
                          onPressed: () => setState(() => _photos.removeAt(i)),
                        ),
                      ),
                    ]),
                  ),
                if (_photos.length < _maxNewPhotos)
                  _PhotoBox(
                    child: InkWell(
                      onTap: _addPhoto,
                      child: const Center(child: Icon(Icons.add_a_photo_outlined, size: 32)),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text('平铺、光线均匀、背景干净。以后识别要用这些照片当底库。', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 20),
          const _Label('分类'),
          Wrap(spacing: 8, children: [
            for (final c in Category.values)
              ChoiceChip(label: Text(c.label), selected: _category == c, onSelected: (_) => setState(() => _category = c)),
          ]),
          const SizedBox(height: 16),
          const _Label('季节（可多选，可不填）'),
          Wrap(spacing: 8, children: [
            for (final s in Season.values)
              FilterChip(
                label: Text(s.label),
                selected: _seasons.contains(s),
                onSelected: (on) => setState(() => on ? _seasons.add(s) : _seasons.remove(s)),
              ),
          ]),
          const SizedBox(height: 16),
          TextField(
            controller: _color,
            maxLength: 64,
            decoration: const InputDecoration(labelText: '颜色', hintText: '藏青'),
          ),
          const _Label('入手日期（可选）'),
          Row(children: [
            TextButton.icon(
              onPressed: _pickAcquired,
              icon: const Icon(Icons.event_outlined),
              label: Text(_acquiredAt ?? '没填'),
            ),
            if (_acquiredAt != null)
              IconButton(
                tooltip: '清掉',
                icon: const Icon(Icons.clear),
                onPressed: () => setState(() => _acquiredAt = null),
              ),
          ]),
          const SizedBox(height: 8),
          const _Label('状态'),
          Wrap(spacing: 8, children: [
            for (final s in ItemStatus.values)
              ChoiceChip(label: Text(s.label), selected: _status == s, onSelected: (_) => setState(() => _status = s)),
          ]),
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) =>
      Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(text, style: Theme.of(context).textTheme.labelLarge));
}

class _PhotoBox extends StatelessWidget {
  const _PhotoBox({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        width: 84,
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
        ),
        clipBehavior: Clip.antiAlias,
        child: child,
      );
}
