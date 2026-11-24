import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../../data/models/planned_meal.dart';
import '../../data/models/app_notification.dart';
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
  List<PlannedMeal> _latestMeals = const [];

  static const channelId = 'nutrimate_meal_reminders';
  static const channelName = 'Meal reminders';

  // TODO: Replace these default slot times with user-configurable reminder preferences.
  static const Map<String, int> slotHours = {
    'Breakfast': 8,
    'Lunch': 13,
    'Dinner': 19,
  };

  bool get isEnabled => _enabled;

  Future<bool> initialize({required bool enabled}) async {
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
    if (_latestMeals.isNotEmpty) {
      await syncScheduledMeals(_latestMeals);
    }
    return true;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _enabled && _initialized) {
      syncScheduledMeals(_latestMeals);
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

  Future<void> syncScheduledMeals(List<PlannedMeal> meals) async {
    _latestMeals = List.unmodifiable(meals);
    final generation = ++_syncGeneration;
    await cancelAll();
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

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    for (final meal in meals) {
      if (generation != _syncGeneration) return;
      final day = DateTime(meal.day.year, meal.day.month, meal.day.day);
      if (day.isBefore(today)) continue;
      final hour = slotHours[meal.slot];
      if (hour == null) continue;

      var scheduled = DateTime(day.year, day.month, day.day, hour);
      if (!scheduled.isAfter(now)) continue;

      final id = _notificationId(day, meal.slot);
      try {
        await _notifications.zonedSchedule(
          id: id,
          title: '${meal.slot} meal reminder',
          body: '${meal.strMeal} is scheduled for ${meal.slot.toLowerCase()}',
          scheduledDate: tz.TZDateTime.from(scheduled, tz.local),
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails(
              channelId,
              channelName,
              channelDescription: 'Reminders for planned meals',
              importance: Importance.high,
              priority: Priority.high,
            ),
            iOS: DarwinNotificationDetails(),
          ),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          payload: 'meal:${meal.slot}:${meal.dayKey}',
        );
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid != null && uid.isNotEmpty) {
          await _database.addAppNotification(
            AppNotification(
              uid: uid,
              title: '${meal.slot} meal reminder',
              body:
                  '${meal.strMeal} is scheduled for ${meal.slot.toLowerCase()}',
              triggeredAt: scheduled,
            ),
          );
        }
      } catch (_) {
        // Keep planner operations usable if platform notification scheduling fails.
      }
    }
  }

  int _notificationId(DateTime day, String slot) {
    final dateKey = day.year * 10000 + day.month * 100 + day.day;
    final slotKey = switch (slot) {
      'Breakfast' => 1,
      'Lunch' => 2,
      'Dinner' => 3,
      _ => 0,
    };
    return dateKey * 10 + slotKey;
  }
}
