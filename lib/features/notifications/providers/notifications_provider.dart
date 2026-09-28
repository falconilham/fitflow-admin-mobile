import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/models.dart';
import '../../../data/repositories/api_repository.dart';
import '../../auth/providers/auth_provider.dart';

class NotificationsNotifier extends AsyncNotifier<List<InAppNotification>> {
  @override
  Future<List<InAppNotification>> build() async {
    return _fetchNotifications();
  }

  Future<List<InAppNotification>> _fetchNotifications() async {
    final gymId = ref.watch(authProvider).valueOrNull?.activeGymId;
    final api = ref.read(apiRepositoryProvider);
    return await api.getNotifications(gymId: gymId);
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _fetchNotifications());
  }

  Future<void> markAsRead(int id) async {
    final api = ref.read(apiRepositoryProvider);
    final success = await api.markNotificationAsRead(id);
    if (success) {
      final currentList = state.value ?? [];
      final newList = currentList.map((notif) {
        if (notif.id == id) {
          return notif.copyWith(isRead: true);
        }
        return notif;
      }).toList();
      state = AsyncValue.data(newList);
    }
  }

  Future<void> markAllAsRead() async {
    final gymId = ref.read(authProvider).valueOrNull?.activeGymId;
    final api = ref.read(apiRepositoryProvider);
    final success = await api.markAllNotificationsAsRead(gymId: gymId);
    if (success) {
      final currentList = state.value ?? [];
      final newList = currentList.map((notif) {
        return notif.copyWith(isRead: true);
      }).toList();
      state = AsyncValue.data(newList);
    }
  }
}

final notificationsProvider =
    AsyncNotifierProvider<NotificationsNotifier, List<InAppNotification>>(() {
  return NotificationsNotifier();
});

final unreadNotificationsCountProvider = Provider<int>((ref) {
  final notificationsAsync = ref.watch(notificationsProvider);
  return notificationsAsync.valueOrNull?.where((n) => !n.isRead).length ?? 0;
});
