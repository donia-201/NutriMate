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

  ProfileCubit(SharedPreferencesWithCache prefs, {FirebaseAuth? auth})
      : _prefs = prefs,
        _auth = auth ?? FirebaseAuth.instance,
        super(_load(prefs, auth ?? FirebaseAuth.instance));

  /// Picks the best name to show: display name, then email prefix, then Guest.
  static String nameFor(User? user) {
    final displayName = user?.displayName?.trim();
    if (displayName != null && displayName.isNotEmpty) return displayName;

    final email = user?.email;
    if (email != null && email.contains('@')) return email.split('@').first;

    return 'Guest';
  }

  static ProfileState _load(SharedPreferencesWithCache prefs, FirebaseAuth auth) {
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
    final user = _auth.currentUser;
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