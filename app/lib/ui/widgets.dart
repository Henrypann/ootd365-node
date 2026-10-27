import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../contract/models.dart';
import '../node/node_client.dart';
import 'design/components.dart';
import 'design/tokens.dart';

/// A photo stored on the node, loaded with the pairing token. Fades in over sand.
class NodeImage extends StatelessWidget {
  const NodeImage({super.key, required this.client, required this.objectKey, this.fit = BoxFit.cover});

  final NodeClient client;
  final String objectKey;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) => ColoredBox(
        color: OColors.sand,
        child: Image.network(
          client.objectUrl(objectKey).toString(),
          headers: client.authHeaders,
          fit: fit,
          width: double.infinity,
          height: double.infinity,
          frameBuilder: (context, child, frame, synchronous) => synchronous
              ? child
              : AnimatedOpacity(opacity: frame == null ? 0 : 1, duration: OMotion.standard, child: child),
          errorBuilder: (context, _, _) =>
              const Center(child: Icon(CupertinoIcons.photo, size: 22, color: OColors.inkFaint)),
        ),
      );
}

/// An item's cover photo, or its monogram when it has none yet.
class ItemImage extends StatelessWidget {
  const ItemImage({super.key, required this.client, required this.item, this.monogramSize = 36});

  final NodeClient client;
  final Item? item;
  final double monogramSize;

  @override
  Widget build(BuildContext context) {
    final key = item?.coverKey;
    if (key != null) return NodeImage(client: client, objectKey: key);
    return OMonogram(text: item?.fields.color ?? '?', size: monogramSize);
  }
}

/// Asks camera or library, then returns the exact bytes to upload.
Future<PhotoUpload?> pickPhoto(BuildContext context, {ImagePicker? picker}) async {
  final source = await showModalBottomSheet<ImageSource>(
    context: context,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(OSpace.gutter, 0, OSpace.gutter, OSpace.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('ADD A PHOTO', style: OType.overline),
            const SizedBox(height: OSpace.md),
            OButton(
              label: '拍照',
              icon: CupertinoIcons.camera,
              onPressed: () => Navigator.pop(context, ImageSource.camera),
            ),
            const SizedBox(height: OSpace.sm),
            OButton(
              label: '从相册选',
              icon: CupertinoIcons.photo_on_rectangle,
              kind: OButtonKind.secondary,
              onPressed: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    ),
  );
  if (source == null) return null;
  final file = await (picker ?? ImagePicker()).pickImage(source: source, maxWidth: 2048, imageQuality: 85);
  if (file == null) return null;
  return PhotoUpload(bytes: await file.readAsBytes(), contentType: photoContentType(file.mimeType, file.name));
}

/// image_picker re-encodes to JPEG when it resizes; fall back on the file name.
String photoContentType(String? mimeType, String name) {
  if (mimeType != null && mimeType.startsWith('image/')) return mimeType == 'image/jpg' ? 'image/jpeg' : mimeType;
  final lower = name.toLowerCase();
  if (lower.endsWith('.png')) return 'image/png';
  if (lower.endsWith('.webp')) return 'image/webp';
  if (lower.endsWith('.heic')) return 'image/heic';
  return 'image/jpeg';
}

void showError(BuildContext context, Object error) {
  final message = error is NodeException ? error.userMessage : error.toString();
  showMessage(context, message);
}

void showMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// English section words for the editorial overlines; the Chinese label stays the primary name.
String categoryOverline(Category c) => switch (c) {
      Category.top => 'Tops',
      Category.bottom => 'Bottoms',
      Category.shoes => 'Shoes',
      Category.outer => 'Outerwear',
      Category.other => 'Accessories',
    };

/// "藏青 · 上装" style label used across cards.
String itemTitle(Item item) => item.fields.color;
String itemSubtitle(Item item) => '${item.fields.category.label} · 穿 ${item.wearCount} 次';
