import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/local_storage_service.dart';

class NotificationSettingsState {
  final bool masterEnabled;
  final bool chatEnabled;
  final bool streakEnabled;

  const NotificationSettingsState({
    required this.masterEnabled,
    required this.chatEnabled,
    required this.streakEnabled,
  });

  NotificationSettingsState copyWith({
    bool? masterEnabled,
    bool? chatEnabled,
    bool? streakEnabled,
  }) {
    return NotificationSettingsState(
      masterEnabled: masterEnabled ?? this.masterEnabled,
      chatEnabled: chatEnabled ?? this.chatEnabled,
      streakEnabled: streakEnabled ?? this.streakEnabled,
    );
  }
}

class NotificationSettingsNotifier extends Notifier<NotificationSettingsState> {
  @override
  NotificationSettingsState build() {
    return NotificationSettingsState(
      masterEnabled: LocalStorageService.getNotificationsEnabled(),
      chatEnabled: LocalStorageService.getChatNotificationsEnabled(),
      streakEnabled: LocalStorageService.getStreakNotificationsEnabled(),
    );
  }

  Future<void> setMaster(bool value) async {
    await LocalStorageService.setNotificationsEnabled(value);
    state = state.copyWith(masterEnabled: value);
  }

  Future<void> setChat(bool value) async {
    await LocalStorageService.setChatNotificationsEnabled(value);
    state = state.copyWith(chatEnabled: value);
  }

  Future<void> setStreak(bool value) async {
    await LocalStorageService.setStreakNotificationsEnabled(value);
    state = state.copyWith(streakEnabled: value);
  }

  bool shouldFireChatNotification() => state.masterEnabled && state.chatEnabled;

  bool shouldFireStreakNotification() => state.masterEnabled && state.streakEnabled;
}

final notificationSettingsProvider =
NotifierProvider<NotificationSettingsNotifier, NotificationSettingsState>(
  NotificationSettingsNotifier.new,
);