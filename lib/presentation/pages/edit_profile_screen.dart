import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nutri_mate/core/app_theme.dart';
import 'package:nutri_mate/core/app_widgets.dart';
import 'package:nutri_mate/presentation/cubit/profile_cubit.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _email;
  late final TextEditingController _calories;
  late String _dietary;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final p = context.read<ProfileCubit>().state;
    _name = TextEditingController(text: p.name);
    _email = TextEditingController(text: p.email);
    _calories = TextEditingController(text: p.calorieGoal.toString());
    _dietary = p.dietary;
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _calories.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await context.read<ProfileCubit>().save(
        name: _name.text.trim(),
        dietary: _dietary,
        calorieGoal: int.parse(_calories.text.trim()),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile changes saved')));
      Navigator.pop(context);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save changes. Please try again.')));
    }
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
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Row(children: [
              CircleAvatar(
                radius: 32,
                backgroundColor: c.surface,
                child: Icon(Icons.person_outline, size: 32, color: c.onSurface),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppButton(
                  label: 'Choose from gallery',
                  outlined: true,
                  onPressed: () {}, // محتاجة image_picker، نضيفها بعدين
                ),
              ),
            ]),
            const SizedBox(height: 20),
            AppTextField(
              label: 'Name',
              controller: _name,
              validator: (v) =>
              (v == null || v.trim().isEmpty) ? 'Please enter your name' : null,
            ),
            const SizedBox(height: 16),
            AppTextField(
              label: 'Email',
              controller: _email,
              enabled: false, // تغيير الإيميل محتاج verification، فسايباه للعرض بس
            ),
            const SizedBox(height: 16),
            Text('Dietary restrictions',
                style: AppTheme.label.copyWith(color: c.onSurface)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _dietary,
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
                if (n == null || n < 500 || n > 10000) return 'Enter a number between 500 and 10000';
                return null;
              },
            ),
            const SizedBox(height: 24),
            AppButton(label: 'Save changes', isLoading: _saving, onPressed: _save),
            const SizedBox(height: 12),
            AppButton(
              label: 'Cancel',
              outlined: true,
              onPressed: _saving ? null : () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }
}