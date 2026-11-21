import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/dataresource/local_database_service.dart';
import '../../data/models/meal_model.dart';
import 'favorites_state.dart';

/// مصدر واحد لمفضلة اليوزر الحالي.
/// بيتعمل مرة واحدة فوق الـ MaterialApp (في main.dart) عشان الـ Home
/// والـ Profile وصفحة الـ AI كلهم يشوفوا نفس الداتا.
class FavoritesCubit extends Cubit<FavoritesState> {
  FavoritesCubit({
    LocalDatabaseService? databaseService,
    FirebaseAuth? auth,
  })  : _database = databaseService ?? LocalDatabaseService.instance,
        _auth = auth ?? FirebaseAuth.instance,
        super(FavoritesState(uid: (auth ?? FirebaseAuth.instance).currentUser?.uid)) {
    // نفس نمط PlannerCubit: لما الحساب يتغير نفضّي ونحمّل بتاع الحساب الجديد.
    _authSub = _auth.authStateChanges().listen((user) {
      if (user?.uid == _uid) return;
      _switchTo(user?.uid);
    });
    load();
  }

  final LocalDatabaseService _database;
  final FirebaseAuth _auth;
  StreamSubscription<User?>? _authSub;

  // بيتغير مع كل switch؛ بنستخدمه نتجاهل أي رد جاي متأخر لحساب قديم.
  int _generation = 0;

  String? get _uid => state.uid;

  void _switchTo(String? uid) {
    _generation++;
    emit(FavoritesState(uid: uid, isLoading: uid != null));
    if (uid != null) load();
  }

  Future<void> load() async {
    final uid = _uid;
    if (uid == null) {
      emit(const FavoritesState());
      return;
    }

    final generation = _generation;
    emit(state.copyWith(isLoading: true, clearError: true));

    try {
      final meals = await _database.getFavorites(uid);
      if (isClosed || generation != _generation) return;
      emit(state.copyWith(meals: meals, isLoading: false));
    } catch (_) {
      if (isClosed || generation != _generation) return;
      emit(
        state.copyWith(
          isLoading: false,
          errorMessage: 'Could not load your favorite meals.',
        ),
      );
    }
  }

  bool isFavorite(String idMeal) => state.ids.contains(idMeal);

  /// بترجع true لو العملية نجحت.
  Future<bool> toggle(MealModel meal) async {
    final uid = _uid;
    // الجيست (anonymous) ممنوع يعمل favorite. الـ UI بيطلب منه يسجّل،
    // وده خط دفاع تاني لو حد نادى toggle من مكان تاني.
    if (uid == null || (_auth.currentUser?.isAnonymous ?? true)) {
      emit(state.copyWith(errorMessage: 'Sign in to save favorites.'));
      return false;
    }

    final generation = _generation;
    final makeFavorite = !isFavorite(meal.idMeal);

    try {
      await _database.setFavorite(uid, meal, makeFavorite);
      if (isClosed || generation != _generation) return false;

      final meals = await _database.getFavorites(uid);
      if (isClosed || generation != _generation) return false;

      emit(state.copyWith(meals: meals, clearError: true));
      return true;
    } catch (_) {
      if (isClosed || generation != _generation) return false;
      emit(
        state.copyWith(
          errorMessage: 'Could not update favorites. Please try again.',
        ),
      );
      return false;
    }
  }

  @override
  Future<void> close() async {
    await _authSub?.cancel();
    return super.close();
  }
}