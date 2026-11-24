import '../../data/models/app_notification.dart';

class NotificationsState {
  final List<AppNotification> notifications;
  final bool isLoading;
  final String? errorMessage;

  const NotificationsState({
    this.notifications = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  int get unreadCount =>
      notifications.where((notification) => !notification.isRead).length;

  NotificationsState copyWith({
    List<AppNotification>? notifications,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) => NotificationsState(
    notifications: notifications ?? this.notifications,
    isLoading: isLoading ?? this.isLoading,
    errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
  );
}
