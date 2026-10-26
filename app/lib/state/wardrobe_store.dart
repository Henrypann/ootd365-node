import 'package:flutter/foundation.dart';

import '../contract/models.dart';
import '../node/node_client.dart';

/// What the app knows about the wardrobe. The node is the source of truth:
/// every write goes to the node and is followed by a reload.
class WardrobeStore extends ChangeNotifier {
  WardrobeStore(this.client);

  final NodeClient client;

  WardrobeIndex index = WardrobeIndex.empty;
  EventLog log = EventLog.empty;
  bool loading = false;
  String? error;

  List<Item> get activeItems => [
        for (final item in index.items)
          if (item.fields.status == ItemStatus.active) item,
      ];

  /// Newest first.
  List<WardrobeEvent> get events => log.events.reversed.toList();

  Future<void> refresh() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final results = await Future.wait([client.fetchIndex(), client.fetchEvents()]);
      index = results[0] as WardrobeIndex;
      log = results[1] as EventLog;
    } on NodeException catch (e) {
      error = e.userMessage;
    } on ContractError catch (e) {
      error = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  /// Creates or updates an item, then uploads any new photos.
  Future<void> saveItem(String id, ItemFields fields, List<PhotoUpload> newPhotos) async {
    await client.putItem(id, fields);
    for (final photo in newPhotos) {
      await client.uploadItemPhoto(id, photo);
    }
    await refresh();
  }

  Future<void> logWear({required DateTime day, required List<String> itemIds, PhotoUpload? look}) async {
    final event = await client.postEvent(type: EventType.wear, date: contractDate(day), itemIds: itemIds);
    if (look != null) await client.uploadLook(event.id, look);
    await refresh();
  }

  Future<void> logWash({required DateTime day, required List<String> itemIds}) async {
    await client.postEvent(type: EventType.wash, date: contractDate(day), itemIds: itemIds);
    await refresh();
  }
}
