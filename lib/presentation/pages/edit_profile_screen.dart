import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nutri_mate/core/app_theme.dart';
import 'package:nutri_mate/core/app_widgets.dart';
import 'package:nutri_mate/presentation/cubit/profile_cubit.dart';
import 'package:firebase_auth/firebase_auth.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _calories;
  late final bool _canChangePassword;
  late final TextEditingController _currentPassword;
  late final TextEditingController _newPassword;
  late final TextEditingController _confirmPassword;
  late String _dietary;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final cubit = context.read<ProfileCubit>();
    final p = cubit.state;
    _canChangePassword = cubit.canChangePassword;
    _name = TextEditingController(text: p.name);
    _calories = TextEditingController(text: p.calorieGoal.toString());
    _currentPassword = TextEditingController();
    _newPassword = TextEditingController();
    _confirmPassword = TextEditingController();
    _dietary = p.dietary;
  }

  @override
  void dispose() {
    _name.dispose();
    _calories.dispose();
    _currentPassword.dispose();
    _newPassword.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    try {
      final cubit = context.read<ProfileCubit>();

      if (_canChangePassword && _newPassword.text.isNotEmpty) {
        await cubit.updatePassword(
          currentPassword: _currentPassword.text,
          newPassword: _newPassword.text,
        );
      }

      await cubit.save(
        name: _name.text.trim(),
        dietary: _dietary,
        calorieGoal: int.parse(_calories.text.trim()),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profile changes saved')));
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_friendlyError(e))));
    }
  }

  String _friendlyError(Object e) {
    if (e is FirebaseAuthException) {
      switch (e.code) {
        case 'wrong-password':
        case 'invalid-credential':
          return 'Current password is incorrect';
        case 'weak-password':
          return 'The new password is too weak';
        case 'requires-recent-login':
          return 'Please log in again, then retry';
        case 'too-many-requests':
          return 'Too many attempts. Try again later';
      }
    }
    return 'Something went wrong. Please try again';
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: SafeArea(
        top: false,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: c.surface,
                    child: Icon(
                      Icons.person_outline,
                      size: 32,
                      color: c.onSurface,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AppButton(
                      label: 'Choose from gallery',
                      outlined: true,
                      onPressed: () {}, // محتاجة image_picker، نضيفها بعدين
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              AppTextField(
                label: 'Name',
                controller: _name,
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Please enter your name'
                    : null,
              ),
              const SizedBox(height: 16),
              if (_canChangePassword) ...[
                AppTextField(
                  label: 'Current password',
                  controller: _currentPassword,
                  isPassword: true,
                  validator: (v) =>
                      _newPassword.text.isNotEmpty && (v == null || v.isEmpty)
                      ? 'Enter your current password to change it'
                      : null,
                ),
                const SizedBox(height: 16),
                AppTextField(
                  label: 'New password (optional)',
                  controller: _newPassword,
                  isPassword: true,
                  validator: (v) => (v != null && v.isNotEmpty && v.length < 6)
                      ? 'Password must be at least 6 characters'
                      : null,
                ),
                const SizedBox(height: 16),
                AppTextField(
                  label: 'Confirm new password',
                  controller: _confirmPassword,
                  isPassword: true,
                  validator: (v) =>
                      v != _newPassword.text ? 'Passwords do not match' : null,
                ),
              ],
              const SizedBox(height: 16),
              Text(
                'Dietary restrictions',
                style: AppTheme.label.copyWith(color: c.onSurface),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _dietary,
                dropdownColor: c.surface,
                style: AppTheme.body.copyWith(color: c.onSurface),
                items: ProfileCubit.dietOptions
                    .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                    .toList(),
                onChanged: (v) => setState(() => _dietary = v ?? _dietary),
              ),
              const SizedBox(height: 16),
              AppTextField(
                label: 'Daily calorie goal (kcal)',
                controller: _calories,
                keyboardType: TextInputType.number,
                validator: (v) {
                  final n = int.tryParse(v?.trim() ?? '');
                  if (n == null || n < 500 || n > 10000)
                    return 'Enter a number between 500 and 10000';
                  return null;
                },
              ),
              const SizedBox(height: 24),
              AppButton(
                label: 'Save changes',
                isLoading: _saving,
                onPressed: _save,
              ),
              const SizedBox(height: 12),
              AppButton(
                label: 'Cancel',
                outlined: true,
                onPressed: _saving ? null : () => Navigator.pop(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
