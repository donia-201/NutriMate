import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfileState {
  final String name;
  final String email;
  final String dietary;
  final int calorieGoal;
  final bool isLoading;
  final String? errorMessage;

  const ProfileState({
    required this.name,
    required this.email,
    required this.dietary,
    required this.calorieGoal,
    this.isLoading = false,
    this.errorMessage,
  });

  ProfileState copyWith({
    String? name,
    String? email,
    String? dietary,
    int? calorieGoal,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) => ProfileState(
    name: name ?? this.name,
    email: email ?? this.email,
    dietary: dietary ?? this.dietary,
    calorieGoal: calorieGoal ?? this.calorieGoal,
    isLoading: isLoading ?? this.isLoading,
    errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
  );
}

class ProfileCubit extends Cubit<ProfileState> {
  static const _dietKey = 'dietary';
  static const _calorieKey = 'calorieGoal';
  static const keys = {_dietKey, _calorieKey}; // for the allowList
  static const dietOptions = [
    'None',
    'Vegetarian',
    'Vegan',
    'Gluten-free',
    'Dairy-free',
  ];

  final SharedPreferencesWithCache _prefs;
  final FirebaseAuth _auth;
  StreamSubscription<User?>? _authSubscription;

  ProfileCubit(SharedPreferencesWithCache prefs, {FirebaseAuth? auth})
    : _prefs = prefs,
      _auth = auth ?? FirebaseAuth.instance,
      super(_load(prefs, auth ?? FirebaseAuth.instance)) {
    try {
      _authSubscription = _auth.authStateChanges().listen(_onAuthChanged);
    } catch (_) {
      // Keep profile usable when auth stream setup fails.
    }
  }

  void _onAuthChanged(User? user) {
    if (isClosed) return;
    emit(
      state.copyWith(
        name: nameFor(user),
        email: user?.email ?? '',
        clearError: true,
      ),
    );
  }

  /// Picks the best name to show: display name, then email prefix, then Guest.
  static String nameFor(User? user) {
    final displayName = user?.displayName?.trim();
    if (displayName != null && displayName.isNotEmpty) return displayName;

    final email = user?.email;
    if (email != null && email.contains('@')) return email.split('@').first;

    return 'Guest';
  }

  static ProfileState _load(
    SharedPreferencesWithCache prefs,
    FirebaseAuth auth,
  ) {
    final user = auth.currentUser;
    return ProfileState(
      name: nameFor(user),
      email: user?.email ?? '',
      dietary: prefs.getString(_dietKey) ?? 'None',
      calorieGoal: prefs.getInt(_calorieKey) ?? 2000,
    );
  }

  Future<void> save({
    required String name,
    required String dietary,
    required int calorieGoal,
  }) async {
    if (isClosed) return;
    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      final user = _auth.currentUser;
      if (user != null && name != state.name) {
        await user.updateDisplayName(name);
        await user.reload();
      }
      if (isClosed) return;
      await _prefs.setString(_dietKey, dietary);
      await _prefs.setInt(_calorieKey, calorieGoal);
      if (isClosed) return;
      emit(
        ProfileState(
          name: name,
          email: _auth.currentUser?.email ?? state.email,
          dietary: dietary,
          calorieGoal: calorieGoal,
          isLoading: false,
        ),
      );
    } catch (_) {
      if (isClosed) return;
      emit(
        state.copyWith(
          isLoading: false,
          errorMessage: 'Could not save profile changes. Please try again.',
        ),
      );
    }
  }

  @override
  Future<void> close() async {
    await _authSubscription?.cancel();
    return super.close();
  }
}
