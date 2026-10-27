import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import '../contract/models.dart';
import '../node/node_client.dart';
import '../state/wardrobe_store.dart';
import 'design/components.dart';
import 'design/tokens.dart';
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
  static const _tileWidth = 96.0;

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
      initialDate: _acquiredAt == null ? now : ODate.parse(_acquiredAt!),
      firstDate: DateTime(1950),
      lastDate: now,
      helpText: '什么时候入手的（不确定就别填）',
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
      showMessage(context, e.message);
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
    const sectionPadding = EdgeInsets.fromLTRB(0, OSpace.xl, 0, OSpace.sm);
    return Scaffold(
      appBar: AppBar(
        leading: Center(
          child: OIconButton(icon: CupertinoIcons.xmark, tooltip: '关闭', filled: false, onPressed: () => Navigator.maybePop(context)),
        ),
        title: Text(_isNew ? '登记单品' : '编辑单品'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(OSpace.gutter, OSpace.xs, OSpace.gutter, OSpace.xl),
        children: [
          SizedBox(
            height: _tileWidth / OAspect.asset,
            child: ListView(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              children: [
                for (final key in existing) _Tile(child: NodeImage(client: widget.store.client, objectKey: key.key)),
                for (final (i, photo) in _photos.indexed)
                  _Tile(
                    child: Stack(fit: StackFit.expand, children: [
                      Image.memory(photo.bytes, fit: BoxFit.cover),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: Transform.scale(
                          scale: 0.8,
                          child: OIconButton(icon: CupertinoIcons.xmark, tooltip: '去掉', onPressed: () => setState(() => _photos.removeAt(i))),
                        ),
                      ),
                    ]),
                  ),
                if (_photos.length < _maxNewPhotos)
                  _Tile(
                    child: InkWell(
                      onTap: _addPhoto,
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(CupertinoIcons.camera, size: 22, color: OColors.inkSoft),
                          SizedBox(height: OSpace.xs),
                          Text('添加照片', style: OType.caption),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: OSpace.sm),
          const Text('平铺拍，光线均匀，背景干净。以后识别会用这些照片作底库。', style: OType.caption),
          const OSectionHeader('Category  分类', padding: sectionPadding),
          Wrap(spacing: OSpace.xs, runSpacing: OSpace.xs, children: [
            for (final c in Category.values)
              OChip(label: c.label, selected: _category == c, onTap: () => setState(() => _category = c)),
          ]),
          const OSectionHeader('Season  季节', trailing: '可多选，可不填', padding: sectionPadding),
          Wrap(spacing: OSpace.xs, runSpacing: OSpace.xs, children: [
            for (final s in Season.values)
              OChip(
                label: s.label,
                selected: _seasons.contains(s),
                onTap: () => setState(() => _seasons.contains(s) ? _seasons.remove(s) : _seasons.add(s)),
              ),
          ]),
          const OSectionHeader('Colour  颜色', padding: sectionPadding),
          TextField(
            controller: _color,
            maxLength: 64,
            style: OType.body.copyWith(fontSize: 17),
            decoration: const InputDecoration(hintText: '用你自己的话，比如「藏青」「燕麦色」', counterText: ''),
          ),
          const OSectionHeader('Acquired  入手', trailing: '可选', padding: sectionPadding),
          Row(children: [
            OButton(
              label: _acquiredAt ?? '选择日期',
              icon: CupertinoIcons.calendar,
              kind: OButtonKind.secondary,
              expand: false,
              onPressed: _pickAcquired,
            ),
            if (_acquiredAt != null)
              OIconButton(icon: CupertinoIcons.xmark, tooltip: '清掉日期', filled: false, onPressed: () => setState(() => _acquiredAt = null)),
          ]),
          const OSectionHeader('Status  状态', padding: sectionPadding),
          Wrap(spacing: OSpace.xs, children: [
            for (final s in ItemStatus.values)
              OChip(label: s.label, selected: _status == s, onTap: () => setState(() => _status = s)),
          ]),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(OSpace.gutter, OSpace.xs, OSpace.gutter, OSpace.md),
          child: OButton(label: _isNew ? '放进衣橱' : '保存', busy: _saving, onPressed: _save),
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        width: _ItemEditorScreenState._tileWidth,
        margin: const EdgeInsets.only(right: OSpace.sm),
        decoration: BoxDecoration(color: OColors.sand, borderRadius: BorderRadius.circular(ORadius.tile)),
        clipBehavior: Clip.antiAlias,
        child: child,
      );
}
