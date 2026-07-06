import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/notification_item.dart';
import '../../../core/services/notification_service.dart';

class NotificationHistoryNotifier extends Notifier<List<NotificationItem>> {
  @override
  List<NotificationItem> build() {
    return NotificationService.instance.getHistory();
  }

  void refresh() {
    state = NotificationService.instance.getHistory();
  }

  Future<void> markRead(String id) async {
    await NotificationService.instance.markAsRead(id);
    refresh();
  }

  Future<void> markAllRead() async {
    await NotificationService.instance.markAllAsRead();
    refresh();
  }

  Future<void> delete(String id) async {
    final previous = state;
    state = state.where((n) => n.id != id).toList();
    try {
      await NotificationService.instance.deleteNotification(id);
    } catch (_) {
      state = previous;
    }
  }

  Future<void> clearAll() async {
    final previous = state;
    state = [];
    try {
      await NotificationService.instance.clearAll();
    } catch (_) {
      state = previous;
    }
  }
}

final notificationHistoryProvider =
NotifierProvider<NotificationHistoryNotifier, List<NotificationItem>>(
  NotificationHistoryNotifier.new,
);

final unreadNotificationCountProvider = Provider<int>((ref) {
  final items = ref.watch(notificationHistoryProvider);
  return items.where((n) => !n.isRead).length;
});