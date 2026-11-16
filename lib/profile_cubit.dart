import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfileState {
  final String name;
  final String email;
  final String dietary;
  final int calorieGoal;

  const ProfileState({
    required this.name,
    required this.email,
    required this.dietary,
    required this.calorieGoal,
  });
}

class ProfileCubit extends Cubit<ProfileState> {
  static const _dietKey = 'dietary';
  static const _calorieKey = 'calorieGoal';
  static const keys = {_dietKey, _calorieKey}; // للـ allowList
  static const dietOptions = ['None', 'Vegetarian', 'Vegan', 'Gluten-free', 'Dairy-free'];

  final SharedPreferencesWithCache _prefs;

  ProfileCubit(this._prefs) : super(_load(_prefs));

  static ProfileState _load(SharedPreferencesWithCache p) {
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email ?? '';
    final name = (user?.displayName?.trim().isNotEmpty ?? false)
        ? user!.displayName!.trim()
        : (email.contains('@') ? email.split('@').first : 'Guest');
    return ProfileState(
      name: name,
      email: email,
      dietary: p.getString(_dietKey) ?? 'None',
      calorieGoal: p.getInt(_calorieKey) ?? 2000,
    );
  }

  Future<void> save({
    required String name,
    required String dietary,
    required int calorieGoal,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && name != state.name) {
      await user.updateDisplayName(name);
      await user.reload();
    }
    await _prefs.setString(_dietKey, dietary);
    await _prefs.setInt(_calorieKey, calorieGoal);
    emit(ProfileState(
      name: name,
      email: state.email,
      dietary: dietary,
      calorieGoal: calorieGoal,
    ));
  }
}