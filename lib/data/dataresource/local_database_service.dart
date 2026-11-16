import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/meal_model.dart';

class LocalDatabaseService {
  LocalDatabaseService._();

  static final LocalDatabaseService instance =
      LocalDatabaseService._();

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;

    final path = await getDatabasesPath();

    _db = await openDatabase(
      p.join(path, 'nutrimate_home.db'),
      version: 1,
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
      },
    );

    return _db!;
  }

  Future<void> cacheMeals(Iterable<MealModel> meals) async {
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
  }

  Future<void> setFavorite(
    MealModel meal,
    bool favorite,
  ) async {
    if (meal.idMeal.isEmpty) return;

    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;

    await db.transaction((txn) async {
      final existing = await txn.query(
        'meals',
        columns: ['idMeal'],
        where: 'idMeal = ?',
        whereArgs: [meal.idMeal],
        limit: 1,
      );

      if (existing.isEmpty) {
        await txn.insert('meals', {
          ...meal.toDbMap(),
          'isFavorite': favorite ? 1 : 0,
          'cachedAt': now,
        });
      } else {
        await txn.update(
          'meals',
          {
            'isFavorite': favorite ? 1 : 0,
            'cachedAt': now,
          },
          where: 'idMeal = ?',
          whereArgs: [meal.idMeal],
        );
      }
    });
  }

  Future<List<MealModel>> getFavorites() async {
    final db = await database;

    final rows = await db.query(
      'meals',
      where: 'isFavorite = ?',
      whereArgs: [1],
      orderBy: 'cachedAt DESC',
    );

    return rows.map(MealModel.fromDbMap).toList();
  }
 Future<List<MealModel>> getCachedMeals({
    int limit = 12,
  }) async {
    final db = await database;

    final rows = await db.query(
      'meals',
      orderBy: 'cachedAt DESC',
      limit: limit,
    );

    return rows.map(MealModel.fromDbMap).toList();
  }
}