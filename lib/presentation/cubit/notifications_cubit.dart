import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/dataresource/local_database_service.dart';
import '../../data/models/app_notification.dart';
import 'notifications_state.dart';

class NotificationsCubit extends Cubit<NotificationsState> {
  NotificationsCubit({
    LocalDatabaseService? databaseService,
    FirebaseAuth? auth,
  }) : _database = databaseService ?? LocalDatabaseService.instance,
       _auth = auth ?? FirebaseAuth.instance,
       super(const NotificationsState()) {
    _authSub = _auth.authStateChanges().listen((user) {
      if (isClosed) return;
      load();
    });
  }

  final LocalDatabaseService _database;
  final FirebaseAuth _auth;
  StreamSubscription? _authSub;

  String get _uid => _auth.currentUser?.uid ?? 'guest';

  Future<void> load() async {
    if (isClosed) return;
    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      final notifications = await _database.getAppNotifications(_uid);
      if (isClosed) return;
      emit(
        state.copyWith(
          notifications: notifications,
          isLoading: false,
          clearError: true,
        ),
      );
    } catch (_) {
      if (isClosed) return;
      emit(
        state.copyWith(
          isLoading: false,
          errorMessage: 'Could not load notifications.',
        ),
      );
    }
  }

  Future<void> markRead(AppNotification notification) async {
    if (notification.id == null) return;
    try {
      await _database.markAppNotificationRead(_uid, notification.id!);
      if (isClosed) return;
      await load();
    } catch (_) {
      if (isClosed) return;
      emit(state.copyWith(errorMessage: 'Could not update this notification.'));
    }
  }

  Future<void> markAllRead() async {
    try {
      await _database.markAllAppNotificationsRead(_uid);
      if (isClosed) return;
      await load();
    } catch (_) {
      if (isClosed) return;
      emit(
        state.copyWith(errorMessage: 'Could not mark notifications as read.'),
      );
    }
  }

  @override
  Future<void> close() async {
    await _authSub?.cancel();
    return super.close();
  }
}
