import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../node/node_client.dart';

/// A photo stored on the node, loaded with the pairing token.
class NodeImage extends StatelessWidget {
  const NodeImage({super.key, required this.client, required this.objectKey, this.fit = BoxFit.cover});

  final NodeClient client;
  final String objectKey;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) => Image.network(
        client.objectUrl(objectKey).toString(),
        headers: client.authHeaders,
        fit: fit,
        errorBuilder: (context, _, _) => const ColoredBox(
          color: Colors.black12,
          child: Center(child: Icon(Icons.broken_image_outlined)),
        ),
      );
}

/// Square tile for an item: its first photo, or a placeholder.
class ItemTile extends StatelessWidget {
  const ItemTile({
    super.key,
    required this.client,
    required this.coverKey,
    required this.caption,
    this.selected = false,
    this.onTap,
  });

  final NodeClient client;
  final String? coverKey;
  final String caption;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? scheme.primary : scheme.outlineVariant, width: selected ? 3 : 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (coverKey != null)
              NodeImage(client: client, objectKey: coverKey!)
            else
              ColoredBox(color: scheme.surfaceContainerHighest, child: const Icon(Icons.checkroom_outlined, size: 40)),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                color: Colors.black54,
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                child: Text(caption,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 12)),
              ),
            ),
            if (selected)
              Positioned(top: 6, right: 6, child: Icon(Icons.check_circle, color: scheme.primary)),
          ],
        ),
      ),
    );
  }
}

/// Asks camera or library, then returns the exact bytes to upload.
Future<PhotoUpload?> pickPhoto(BuildContext context, {ImagePicker? picker}) async {
  final source = await showModalBottomSheet<ImageSource>(
    context: context,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text('拍照'),
            onTap: () => Navigator.pop(context, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('从相册选'),
            onTap: () => Navigator.pop(context, ImageSource.gallery),
          ),
        ],
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
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}
