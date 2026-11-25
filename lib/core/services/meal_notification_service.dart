import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../../data/models/planned_meal.dart';
import '../../data/dataresource/local_database_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MealNotificationService with WidgetsBindingObserver {
  MealNotificationService._();

  static final MealNotificationService instance = MealNotificationService._();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  final LocalDatabaseService _database = LocalDatabaseService.instance;
  bool _initialized = false;
  bool _enabled = true;
  int _syncGeneration = 0;
  Map<String, TimeOfDay> _slotTimes = {...defaultSlotTimes};

  static const channelId = 'nutrimate_meal_reminders';
  static const channelName = 'Meal reminders';
  static const _channelDescription = 'Reminders for planned meals';
  static const defaultSlotTimes = <String, TimeOfDay>{
    'Breakfast': TimeOfDay(hour: 8, minute: 0),
    'Lunch': TimeOfDay(hour: 13, minute: 0),
    'Dinner': TimeOfDay(hour: 19, minute: 0),
  };

  bool get isEnabled => _enabled;

  Future<bool> initialize({
    required bool enabled,
    Map<String, TimeOfDay>? reminderTimes,
  }) async {
    if (reminderTimes != null) {
      _slotTimes = {...defaultSlotTimes, ...reminderTimes};
    }
    _enabled = enabled;
    if (_initialized) {
      if (!_enabled) return true;
      final permitted = await hasPermission();
      if (!permitted) {
        _enabled = false;
        await cancelAll();
      }
      return permitted;
    }

    try {
      tzdata.initializeTimeZones();
      final timezoneName =
          (await FlutterTimezone.getLocalTimezone()).identifier;
      tz.setLocalLocation(tz.getLocation(timezoneName));

      const androidSettings = AndroidInitializationSettings(
        '@mipmap/ic_launcher',
      );
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      const settings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );
      await _notifications.initialize(settings: settings);
      if (!kIsWeb && Platform.isAndroid) {
        final android = _notifications
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
        await android?.createNotificationChannel(
          const AndroidNotificationChannel(
            channelId,
            channelName,
            description: _channelDescription,
            importance: Importance.high,
          ),
        );
      }
      _initialized = true;
      WidgetsBinding.instance.addObserver(this);
      if (_enabled) {
        final permitted = await hasPermission();
        if (!permitted) {
          _enabled = false;
          await cancelAll();
          return false;
        }
      }
      return true;
    } catch (_) {
      _initialized = false;
      return false;
    }
  }

  Future<bool> setEnabled(bool enabled) async {
    _enabled = enabled;
    if (!enabled) {
      ++_syncGeneration;
      await cancelAll();
      return false;
    }

    if (!await requestPermission()) {
      _enabled = false;
      await cancelAll();
      return false;
    }
    await syncScheduledMeals();
    return _enabled;
  }

  Future<bool> setReminderTime(String slot, TimeOfDay time) async {
    if (!defaultSlotTimes.containsKey(slot)) {
      throw ArgumentError.value(slot, 'slot', 'Unknown meal reminder slot');
    }
    _slotTimes[slot] = time;
    if (_enabled && _initialized) {
      await syncScheduledMeals(onlySlot: slot);
    }
    return _enabled;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _enabled && _initialized) {
      unawaited(_syncAfterResume());
    }
  }

  Future<void> _syncAfterResume() async {
    try {
      await syncScheduledMeals();
    } catch (error, stackTrace) {
      debugPrint('Could not refresh scheduled meal reminders: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<bool> requestPermission() async {
    if (!_initialized) return false;
    if (kIsWeb) {
      _enabled = true;
      return true;
    }
    bool granted;
    if (Platform.isAndroid) {
      final android = _notifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      granted = await android?.requestNotificationsPermission() ?? false;
    } else if (Platform.isIOS || Platform.isMacOS) {
      final ios = _notifications
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      granted =
          await ios?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
    } else {
      granted = true;
    }
    _enabled = granted;
    return granted;
  }

  Future<bool> hasPermission() async {
    if (!_initialized) return false;
    if (kIsWeb) return true;
    if (Platform.isAndroid) {
      final android = _notifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      return await android?.areNotificationsEnabled() ?? false;
    }
    if (Platform.isIOS || Platform.isMacOS) {
      final ios = _notifications
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      final options = await ios?.checkPermissions();
      return options?.isEnabled ?? false;
    }
    return true;
  }

  Future<void> cancelAll() async {
    if (!_initialized) return;
    try {
      await _notifications.cancelAll();
    } catch (_) {
      // Notification access can be unavailable while the OS restricts alarms.
    }
  }

  Future<void> syncScheduledMeals({String? onlySlot}) async {
    if (onlySlot != null && !defaultSlotTimes.containsKey(onlySlot)) {
      throw ArgumentError.value(
        onlySlot,
        'onlySlot',
        'Unknown meal reminder slot',
      );
    }
    final generation = ++_syncGeneration;
    if (onlySlot == null) {
      await cancelAll();
    } else {
      await _cancelSlotNotifications(onlySlot);
    }
    if (!_enabled || !_initialized) return;
    bool permitted;
    try {
      permitted = await hasPermission();
    } catch (_) {
      permitted = false;
    }
    if (generation != _syncGeneration) return;
    if (!permitted) {
      _enabled = false;
      await cancelAll();
      return;
    }

    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'guest';
    late final List<PlannedMeal> meals;
    try {
      meals = await _database.getUpcomingPlannedMeals(uid);
    } catch (error, stackTrace) {
      debugPrint('Could not load upcoming meals for reminders: $error');
      debugPrintStack(stackTrace: stackTrace);
      return;
    }
    if (generation != _syncGeneration) return;
    final scheduleMode = await _androidScheduleMode();
    if (generation != _syncGeneration) return;

    final now = tz.TZDateTime.now(tz.local);
    final today = DateTime(now.year, now.month, now.day);
    for (final meal in meals) {
      if (generation != _syncGeneration) return;
      if (onlySlot != null && meal.slot != onlySlot) continue;
      final day = DateTime(meal.day.year, meal.day.month, meal.day.day);
      if (day.isBefore(today)) continue;
      final time = _slotTimes[meal.slot];
      if (time == null) continue;

      final scheduled = tz.TZDateTime(
        tz.local,
        day.year,
        day.month,
        day.day,
        time.hour,
        time.minute,
      );
      if (!scheduled.isAfter(now)) continue;

      final id = _notificationId(day, meal.slot);
      try {
        await _scheduleMealReminder(
          id: id,
          meal: meal,
          scheduled: scheduled,
          mode: scheduleMode,
        );
      } catch (error, stackTrace) {
        debugPrint('Could not schedule ${meal.slot} reminder: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
    }
  }

  Future<void> _cancelSlotNotifications(String slot) async {
    final slotKey = _slotKey(slot);
    final pending = await _notifications.pendingNotificationRequests();
    for (final request in pending) {
      if (request.id % 10 == slotKey) {
        await _notifications.cancel(id: request.id);
      }
    }
  }

  Future<AndroidScheduleMode> _androidScheduleMode() async {
    if (kIsWeb || !Platform.isAndroid) {
      return AndroidScheduleMode.inexactAllowWhileIdle;
    }
    try {
      final android = _notifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      final canScheduleExact =
          await android?.canScheduleExactNotifications() ?? false;
      return canScheduleExact
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle;
    } catch (error, stackTrace) {
      debugPrint(
        'Exact alarm access unavailable; using inexact alarms: $error',
      );
      debugPrintStack(stackTrace: stackTrace);
      return AndroidScheduleMode.inexactAllowWhileIdle;
    }
  }

  Future<void> _scheduleMealReminder({
    required int id,
    required PlannedMeal meal,
    required tz.TZDateTime scheduled,
    required AndroidScheduleMode mode,
  }) async {
    try {
      await _notifications.zonedSchedule(
        id: id,
        title: '${meal.slot} meal reminder',
        body: '${meal.strMeal} is scheduled for ${meal.slot.toLowerCase()}',
        scheduledDate: scheduled,
        notificationDetails: _reminderDetails,
        androidScheduleMode: mode,
        payload: 'meal:${meal.slot}:${meal.dayKey}',
      );
    } on PlatformException catch (error, stackTrace) {
      if (mode != AndroidScheduleMode.exactAllowWhileIdle) rethrow;
      debugPrint('Exact alarm was rejected; retrying inexactly: $error');
      debugPrintStack(stackTrace: stackTrace);
      await _notifications.zonedSchedule(
        id: id,
        title: '${meal.slot} meal reminder',
        body: '${meal.strMeal} is scheduled for ${meal.slot.toLowerCase()}',
        scheduledDate: scheduled,
        notificationDetails: _reminderDetails,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: 'meal:${meal.slot}:${meal.dayKey}',
      );
    }
  }

  static const _reminderDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: _channelDescription,
      importance: Importance.high,
      priority: Priority.high,
    ),
    iOS: DarwinNotificationDetails(),
  );

  int _slotKey(String slot) => switch (slot) {
    'Breakfast' => 1,
    'Lunch' => 2,
    'Dinner' => 3,
    _ => 0,
  };

  int _notificationId(DateTime day, String slot) {
    final dateKey = day.year * 10000 + day.month * 100 + day.day;
    return dateKey * 10 + _slotKey(slot);
  }
}
