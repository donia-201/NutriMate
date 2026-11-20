import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/meal_model.dart';
import '../models/planned_meal.dart';

enum LocalDatabaseErrorType { open, read, write, delete }

class LocalDatabaseException implements Exception {
  final LocalDatabaseErrorType type;
  final String message;

  const LocalDatabaseException({
    required this.type,
    required this.message,
  });

  @override
  String toString() => message;
}

class LocalDatabaseService {
  LocalDatabaseService._();

  static final LocalDatabaseService instance = LocalDatabaseService._();

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
      version: 3,

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
      },

      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _createPlannedMealsTable(db);
        }

        if (oldVersion < 3) {
          // الجدول القديم UNIQUE(day, slot) من غير uid،
          // فلازم نبنيه من جديد.
          await db.execute(
            'DROP TABLE IF EXISTS planned_meals',
          );

          await _createPlannedMealsTable(db);
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

  Future<void> setFavorite(
      MealModel meal,
      bool favorite,
      ) async {
    try {
      final db = await database;

      final rows = await db.query(
        'meals',
        where: 'idMeal = ?',
        whereArgs: [meal.idMeal],
        limit: 1,
      );

      final preserved = rows.isEmpty
          ? meal
          : MealModel.fromDbMap(rows.first).mergeDetails(meal);

      await db.insert(
        'meals',
        {
          ...preserved.toDbMap(),
          'isFavorite': favorite ? 1 : 0,
          'cachedAt': DateTime.now().millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } on LocalDatabaseException {
      rethrow;
    } catch (_) {
      throw const LocalDatabaseException(
        type: LocalDatabaseErrorType.write,
        message: 'Could not update favorites locally.',
      );
    }
  }

  Future<List<MealModel>> getFavorites() async {
    try {
      final rows = await (await database).query(
        'meals',
        where: 'isFavorite = ?',
        whereArgs: [1],
        orderBy: 'cachedAt DESC',
      );

      return rows.map(MealModel.fromDbMap).toList();
    } on LocalDatabaseException {
      rethrow;
    } catch (_) {
      throw const LocalDatabaseException(
        type: LocalDatabaseErrorType.read,
        message: 'Could not read favorite meals.',
      );
    }
  }

  Future<List<MealModel>> getCachedMeals({
    int limit = 12,
  }) async {
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
      whereArgs: [
        uid,
        _dayKey(day),
        slot,
      ],
      limit: 1,
    );

    return rows.isEmpty
        ? null
        : PlannedMeal.fromDbMap(rows.first);
  }

  Future<void> savePlannedMeal(
      String uid,
      PlannedMeal meal,
      ) async {
    final db = await database;

    await db.insert(
      'planned_meals',
      {
        ...meal.toDbMap(),
        'slotOrder': _slotOrder(meal.slot),
        'uid': uid,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> removePlannedMeal(
      String uid,
      PlannedMeal meal,
      ) async {
    try {
      await (await database).delete(
        'planned_meals',
        where: 'uid = ? AND day = ? AND slot = ?',
        whereArgs: [
          uid,
          meal.dayKey,
          meal.slot,
        ],
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
      whereArgs: [
        uid,
        _dayKey(start),
        _dayKey(end),
      ],
      orderBy: 'day ASC, slotOrder ASC',
    );

    return rows.map(PlannedMeal.fromDbMap).toList();
  }

  Future<void> _createPlannedMealsTable(
      Database db,
      ) async {
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

  String _dayKey(DateTime value) =>
      DateTime(
        value.year,
        value.month,
        value.day,
      ).toIso8601String();

  int _slotOrder(String slot) =>
      const {
        'Breakfast': 0,
        'Lunch': 1,
        'Dinner': 2,
      }[slot] ?? 3;

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