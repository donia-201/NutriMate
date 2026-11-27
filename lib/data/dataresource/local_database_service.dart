import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/meal_model.dart';
import '../models/planned_meal.dart';
import '../models/nutrition_model.dart';
import '../models/app_notification.dart';

enum LocalDatabaseErrorType { open, read, write, delete }

class LocalDatabaseException implements Exception {
  final LocalDatabaseErrorType type;
  final String message;

  const LocalDatabaseException({required this.type, required this.message});

  @override
  String toString() => message;
}

class LocalDatabaseService {
  LocalDatabaseService._();

  static final LocalDatabaseService instance = LocalDatabaseService._();

  /// Increases every time a meal is logged, so screens that show nutrition
  /// totals (like Insights) can reload by themselves.
  final ValueNotifier<int> mealLogsRevision = ValueNotifier<int>(0);

  Database? _db;
  Future<Database>? _dbFuture;

  Future<Database> get database async {
    if (_db != null) return _db!;

    final pending = _dbFuture;
    if (pending != null) return pending;

    _dbFuture = _openDatabase();

    try {
      _db = await _dbFuture!;
      return _db!;
    } catch (_) {
      throw const LocalDatabaseException(
        type: LocalDatabaseErrorType.open,
        message: 'Could not open local storage.',
      );
    } finally {
      _dbFuture = null;
    }
  }

  Future<Database> _openDatabase() async {
    final path = await getDatabasesPath();

    return openDatabase(
      p.join(path, 'nutrimate_home.db'),
      version: 6,

      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE meals (
            idMeal TEXT PRIMARY KEY,
            strMeal TEXT NOT NULL,
            strCategory TEXT,
            strArea TEXT,
            strMealThumb TEXT,
            strInstructions TEXT,
            strYoutube TEXT,
            detailsLoaded INTEGER NOT NULL DEFAULT 0,
            isFavorite INTEGER NOT NULL DEFAULT 0,
            cachedAt INTEGER NOT NULL
          )
        ''');

        await _createPlannedMealsTable(db);
        await _createFavoritesTable(db);
        await _createLoggedMealsTable(db);
        await _createMealLogsTable(db);
        await _createAppNotificationsTable(db);
      },

      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _createPlannedMealsTable(db);
        }

        if (oldVersion < 3) {
          // الجدول القديم UNIQUE(day, slot) من غير uid،
          // فلازم نبنيه من جديد.
          await db.execute('DROP TABLE IF EXISTS planned_meals');

          await _createPlannedMealsTable(db);
        }

        if (oldVersion < 5) {
          // Favorites are stored per user; the shared meals.isFavorite flag is ignored.
          await _createFavoritesTable(db);
          await _createLoggedMealsTable(db);
          await _createMealLogsTable(db);
        }
        if (oldVersion < 6) {
          await _createAppNotificationsTable(db);
        }
      },
    );
  }

  Future<void> cacheMeals(Iterable<MealModel> meals) async {
    try {
      final db = await database;
      final batch = db.batch();
      final now = DateTime.now().millisecondsSinceEpoch;

      for (final meal in meals) {
        if (meal.idMeal.isEmpty) continue;

        batch.rawInsert(
          '''
          INSERT INTO meals (
            idMeal,
            strMeal,
            strCategory,
            strArea,
            strMealThumb,
            strInstructions,
            strYoutube,
            detailsLoaded,
            isFavorite,
            cachedAt
          )
          VALUES (?, ?, ?, ?, ?, ?, ?, ?,
            COALESCE(
              (SELECT isFavorite FROM meals WHERE idMeal = ?),
              0
            ),
            ?
          )
          ON CONFLICT(idMeal) DO UPDATE SET
            strMeal = excluded.strMeal,

            strCategory = COALESCE(
              excluded.strCategory,
              meals.strCategory
            ),

            strArea = COALESCE(
              excluded.strArea,
              meals.strArea
            ),

            strMealThumb = COALESCE(
              NULLIF(excluded.strMealThumb, ''),
              meals.strMealThumb
            ),

            strInstructions = COALESCE(
              NULLIF(excluded.strInstructions, ''),
              meals.strInstructions
            ),

            strYoutube = COALESCE(
              NULLIF(excluded.strYoutube, ''),
              meals.strYoutube
            ),

            detailsLoaded = MAX(
              excluded.detailsLoaded,
              meals.detailsLoaded
            ),

            cachedAt = excluded.cachedAt
        ''',
          [
            meal.idMeal,
            meal.strMeal,
            meal.strCategory,
            meal.strArea,
            meal.strMealThumb,
            meal.strInstructions,
            meal.strYoutube,
            meal.detailsLoaded ? 1 : 0,
            meal.idMeal,
            now,
          ],
        );
      }

      await batch.commit(noResult: true);
    } on LocalDatabaseException {
      rethrow;
    } catch (_) {
      throw const LocalDatabaseException(
        type: LocalDatabaseErrorType.write,
        message: 'Could not cache recipes locally.',
      );
    }
  }

  // ============================================================
  // FAVORITES (per user)
  // ============================================================

  /// Adds/removes [meal] from the favorites of [uid] only.
  /// Meal details live in the shared `meals` cache table; ownership lives
  /// in the `favorites` table.
  Future<void> setFavorite(String uid, MealModel meal, bool favorite) async {
    try {
      final db = await database;

      await db.transaction((txn) async {
        if (!favorite) {
          await txn.delete(
            'favorites',
            where: 'uid = ? AND idMeal = ?',
            whereArgs: [uid, meal.idMeal],
          );
          return;
        }

        final now = DateTime.now().millisecondsSinceEpoch;
        final rows = await txn.query(
          'meals',
          where: 'idMeal = ?',
          whereArgs: [meal.idMeal],
          limit: 1,
        );

        final preserved = rows.isEmpty
            ? meal
            : MealModel.fromDbMap(rows.first).mergeDetails(meal);

        await txn.insert('meals', {
          ...preserved.toDbMap(),
          'cachedAt': now,
        }, conflictAlgorithm: ConflictAlgorithm.replace);

        await txn.insert('favorites', {
          'uid': uid,
          'idMeal': meal.idMeal,
          'addedAt': now,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      });
    } on LocalDatabaseException {
      rethrow;
    } catch (_) {
      throw const LocalDatabaseException(
        type: LocalDatabaseErrorType.write,
        message: 'Could not update favorites locally.',
      );
    }
  }

  /// Favorites of [uid], newest first.
  Future<List<MealModel>> getFavorites(String uid) async {
    try {
      final rows = await (await database).rawQuery(
        '''
        SELECT m.*
        FROM favorites f
        INNER JOIN meals m ON m.idMeal = f.idMeal
        WHERE f.uid = ?
        ORDER BY f.addedAt DESC
        ''',
        [uid],
      );
      return rows.map(MealModel.fromDbMap).toList();
    } catch (_) {
      throw const LocalDatabaseException(
        type: LocalDatabaseErrorType.read,
        message: 'Could not read favorite meals.',
      );
    }
  }

  Future<bool> isFavorite(String uid, String mealId) async {
    final rows = await (await database).query(
      'favorites',
      columns: ['idMeal'],
      where: 'uid = ? AND idMeal = ?',
      whereArgs: [uid, mealId],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<void> logMeal(
    String uid,
    MealModel meal, {
    NutritionModel? nutrition,
    DateTime? eatenAt,
  }) async {
    if (uid.isEmpty || uid == 'guest') {
      throw const LocalDatabaseException(
        type: LocalDatabaseErrorType.write,
        message: 'Sign in to save meals to your nutrition insights.',
      );
    }

    try {
      final db = await database;
      final loggedAt = (eatenAt ?? DateTime.now()).millisecondsSinceEpoch;
      await db.transaction((txn) async {
        await txn.insert('logged_meals', {
          'uid': uid,
          ...meal.toDbMap(),
          'loggedAt': loggedAt,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
        await txn.insert('meal_logs', {
          'uid': uid,
          'idMeal': meal.idMeal,
          'strMeal': meal.strMeal,
          'strCategory': meal.strCategory,
          'strArea': meal.strArea,
          'strMealThumb': meal.strMealThumb,
          'loggedAt': loggedAt,
          'calories': nutrition?.calories,
          'protein': nutrition?.protein,
          'carbohydrates': nutrition?.carbohydrates,
          'fat': nutrition?.fat,
          'isEstimated': nutrition?.isEstimated == true ? 1 : 0,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      });
      mealLogsRevision.value++;
    } catch (_) {
      throw const LocalDatabaseException(
        type: LocalDatabaseErrorType.write,
        message: 'Could not log this meal.',
      );
    }
  }

  Future<List<Map<String, Object?>>> getMealLogs(
    String uid, {
    required DateTime start,
    required DateTime end,
  }) async {
    if (uid.isEmpty || uid == 'guest') return [];
    try {
      final startMs = DateTime(
        start.year,
        start.month,
        start.day,
      ).millisecondsSinceEpoch;
      final endMs = DateTime(
        end.year,
        end.month,
        end.day,
        23,
        59,
        59,
        999,
      ).millisecondsSinceEpoch;
      return await (await database).query(
        'meal_logs',
        where: 'uid = ? AND loggedAt >= ? AND loggedAt <= ?',
        whereArgs: [uid, startMs, endMs],
        orderBy: 'loggedAt ASC',
      );
    } catch (_) {
      throw const LocalDatabaseException(
        type: LocalDatabaseErrorType.read,
        message: 'Could not load nutrition insights.',
      );
    }
  }

  Future<void> _createMealLogsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS meal_logs (
        logId INTEGER PRIMARY KEY AUTOINCREMENT,
        uid TEXT NOT NULL,
        idMeal TEXT NOT NULL,
        strMeal TEXT NOT NULL,
        strCategory TEXT,
        strArea TEXT,
        strMealThumb TEXT,
        loggedAt INTEGER NOT NULL,
        calories REAL,
        protein REAL,
        carbohydrates REAL,
        fat REAL,
        isEstimated INTEGER NOT NULL DEFAULT 1
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_meal_logs_uid_date '
      'ON meal_logs(uid, loggedAt)',
    );
  }

  Future<void> _createLoggedMealsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS logged_meals (
        uid TEXT NOT NULL,
        idMeal TEXT NOT NULL,
        strMeal TEXT NOT NULL,
        strCategory TEXT,
        strArea TEXT,
        strMealThumb TEXT,
        strInstructions TEXT,
        strYoutube TEXT,
        detailsLoaded INTEGER NOT NULL DEFAULT 0,
        loggedAt INTEGER NOT NULL,
        PRIMARY KEY(uid, idMeal, loggedAt)
      )
    ''');
  }

  Future<List<MealModel>> getCachedMeals({int limit = 12}) async {
    try {
      final rows = await (await database).query(
        'meals',
        orderBy: 'cachedAt DESC',
        limit: limit,
      );

      return rows.map(MealModel.fromDbMap).toList();
    } on LocalDatabaseException {
      rethrow;
    } catch (_) {
      throw const LocalDatabaseException(
        type: LocalDatabaseErrorType.read,
        message: 'Could not read cached meals.',
      );
    }
  }

  // ============================================================
  // PLANNED MEALS
  // ============================================================

  Future<PlannedMeal?> getPlannedMeal(
    String uid,
    DateTime day,
    String slot,
  ) async {
    final rows = await (await database).query(
      'planned_meals',
      where: 'uid = ? AND day = ? AND slot = ?',
      whereArgs: [uid, _dayKey(day), slot],
      limit: 1,
    );

    return rows.isEmpty ? null : PlannedMeal.fromDbMap(rows.first);
  }

  Future<void> savePlannedMeal(String uid, PlannedMeal meal) async {
    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);
    final mealDay = DateTime(meal.day.year, meal.day.month, meal.day.day);
    if (mealDay.isBefore(todayOnly)) {
      throw const LocalDatabaseException(
        type: LocalDatabaseErrorType.write,
        message: 'Past dates are view-only.',
      );
    }
    final db = await database;

    await db.insert('planned_meals', {
      ...meal.toDbMap(),
      'slotOrder': _slotOrder(meal.slot),
      'uid': uid,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> removePlannedMeal(String uid, PlannedMeal meal) async {
    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);
    final mealDay = DateTime(meal.day.year, meal.day.month, meal.day.day);
    if (mealDay.isBefore(todayOnly)) {
      throw const LocalDatabaseException(
        type: LocalDatabaseErrorType.delete,
        message: 'Past planned meals cannot be changed or removed.',
      );
    }
    try {
      await (await database).delete(
        'planned_meals',
        where: 'uid = ? AND day = ? AND slot = ?',
        whereArgs: [uid, meal.dayKey, meal.slot],
      );
    } on LocalDatabaseException {
      rethrow;
    } catch (_) {
      throw const LocalDatabaseException(
        type: LocalDatabaseErrorType.delete,
        message: 'Could not remove the planned meal.',
      );
    }
  }

  Future<List<PlannedMeal>> getPlannedMealsBetween(
    String uid,
    DateTime start,
    DateTime end,
  ) async {
    final rows = await (await database).query(
      'planned_meals',
      where: 'uid = ? AND day >= ? AND day <= ?',
      whereArgs: [uid, _dayKey(start), _dayKey(end)],
      orderBy: 'day ASC, slotOrder ASC',
    );

    return rows.map(PlannedMeal.fromDbMap).toList();
  }

  Future<List<PlannedMeal>> getUpcomingPlannedMeals(String uid) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final rows = await (await database).query(
      'planned_meals',
      where: 'uid = ? AND day >= ?',
      whereArgs: [uid, _dayKey(today)],
      orderBy: 'day ASC, slotOrder ASC',
    );

    return rows.map(PlannedMeal.fromDbMap).toList();
  }

  Future<void> _createPlannedMealsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS planned_meals (
        localId INTEGER PRIMARY KEY AUTOINCREMENT,
        idMeal TEXT NOT NULL,
        strMeal TEXT NOT NULL,
        strMealThumb TEXT NOT NULL,
        strCategory TEXT,
        strArea TEXT,
        day TEXT NOT NULL,
        slot TEXT NOT NULL,
        slotOrder INTEGER NOT NULL,
        servings INTEGER NOT NULL DEFAULT 1,
        calories INTEGER NOT NULL DEFAULT 0,
        uid TEXT NOT NULL,
        UNIQUE(uid, day, slot)
      )
    ''');
  }

  Future<void> _createFavoritesTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS favorites (
        uid TEXT NOT NULL,
        idMeal TEXT NOT NULL,
        addedAt INTEGER NOT NULL,
        PRIMARY KEY (uid, idMeal)
      )
    ''');
  }

  String _dayKey(DateTime value) =>
      DateTime(value.year, value.month, value.day).toIso8601String();

  int _slotOrder(String slot) =>
      const {'Breakfast': 0, 'Lunch': 1, 'Dinner': 2}[slot] ?? 3;

  Future<void> _createAppNotificationsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS app_notifications (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        uid TEXT NOT NULL,
        title TEXT NOT NULL,
        body TEXT NOT NULL,
        triggeredAt INTEGER NOT NULL,
        isRead INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_app_notifications_uid '
      'ON app_notifications(uid, triggeredAt DESC)',
    );
  }

  Future<void> addAppNotification(AppNotification notification) async {
    final db = await database;
    final existing = await db.query(
      'app_notifications',
      columns: ['id'],
      where: 'uid = ? AND title = ? AND body = ? AND triggeredAt = ?',
      whereArgs: [
        notification.uid,
        notification.title,
        notification.body,
        notification.triggeredAt.millisecondsSinceEpoch,
      ],
      limit: 1,
    );
    if (existing.isNotEmpty) return;
    await db.insert('app_notifications', notification.toDbMap());
  }

  Future<List<AppNotification>> getAppNotifications(String uid) async {
    final rows = await (await database).query(
      'app_notifications',
      where: 'uid = ?',
      whereArgs: [uid],
      orderBy: 'triggeredAt DESC',
    );
    return rows.map(AppNotification.fromDbMap).toList();
  }

  Future<void> markAppNotificationRead(String uid, int id) async {
    await (await database).update(
      'app_notifications',
      {'isRead': 1},
      where: 'uid = ? AND id = ?',
      whereArgs: [uid, id],
    );
  }

  Future<void> markAllAppNotificationsRead(String uid) async {
    await (await database).update(
      'app_notifications',
      {'isRead': 1},
      where: 'uid = ?',
      whereArgs: [uid],
    );
  }

  Future<void> close() async {
    final db = _db;

    _db = null;
    _dbFuture = null;

    if (db != null) {
      await db.close();
    }
  }

  Future<void> resetForTests() async {
    await close();
  }
}
