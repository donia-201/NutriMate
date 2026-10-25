import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import '../models/meal.model.dart';

class LocalDatabaseService {
  LocalDatabaseService._();
  static final LocalDatabaseService instance = LocalDatabaseService._();
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
      batch.rawInsert('''
        INSERT INTO meals (idMeal, strMeal, strCategory, strArea, strMealThumb,
          strInstructions, strYoutube, detailsLoaded, isFavorite, cachedAt)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?,
          COALESCE((SELECT isFavorite FROM meals WHERE idMeal = ?), 0), ?)
        ON CONFLICT(idMeal) DO UPDATE SET
          strMeal = excluded.strMeal,
          strCategory = COALESCE(excluded.strCategory, meals.strCategory),
          strArea = COALESCE(excluded.strArea, meals.strArea),
          strMealThumb = excluded.strMealThumb,
          strInstructions = COALESCE(excluded.strInstructions, meals.strInstructions),
          strYoutube = COALESCE(excluded.strYoutube, meals.strYoutube),
          detailsLoaded = MAX(excluded.detailsLoaded, meals.detailsLoaded),
          cachedAt = excluded.cachedAt
      ''', [
        meal.idMeal, meal.strMeal, meal.strCategory, meal.strArea, meal.strMealThumb,
        meal.strInstructions, meal.strYoutube, meal.detailsLoaded ? 1 : 0,
        meal.idMeal, now,
      ]);
    }
    await batch.commit(noResult: true);
  }

  Future<void> setFavorite(MealModel meal, bool favorite) async {
    final db = await database;
    final existing = await db.query('meals', where: 'idMeal = ?', whereArgs: [meal.idMeal], limit: 1);
    final oldFavorite = existing.isNotEmpty ? (existing.first['isFavorite'] as int? ?? 0) : 0;
    await db.insert('meals', {
      ...meal.toDbMap(),
      'isFavorite': favorite ? 1 : (oldFavorite == 1 ? 0 : 0),
      'cachedAt': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<MealModel>> getFavorites() async {
    final rows = await (await database).query('meals',
      where: 'isFavorite = ?', whereArgs: [1], orderBy: 'cachedAt DESC');
    return rows.map(MealModel.fromDbMap).toList();
  }

  Future<List<MealModel>> getCachedMeals({int limit = 12}) async {
    final rows = await (await database).query('meals', orderBy: 'cachedAt DESC', limit: limit);
    return rows.map(MealModel.fromDbMap).toList();
  }
}
