import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nutri_mate/core/app_theme.dart';
import 'package:nutri_mate/core/app_widgets.dart';
import 'package:nutri_mate/presentation/cubit/profile_cubit.dart';
import 'package:nutri_mate/presentation/cubit/settings_cubit.dart';
import 'package:nutri_mate/presentation/pages/edit_profile_screen.dart';
import 'package:nutri_mate/presentation/pages/settings_screen.dart';
import 'package:nutri_mate/presentation/pages/about_screen.dart';

class ProfileScreen extends StatelessWidget {
  final FirebaseAuth? auth;
  const ProfileScreen({super.key, this.auth});

  void _soon(BuildContext context) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(const SnackBar(content: Text('Coming soon')));

  Future<void> _openEditProfile(BuildContext context) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => const EditProfileScreen()),
    );
  }

  Future<void> _openSettings(BuildContext context) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );
  }

  Future<void> _logout(BuildContext context) async {
    try {
      try {
        await GoogleSignIn().signOut();
      } catch (_) {}
      await (auth ?? FirebaseAuth.instance).signOut();
      if (!context.mounted) return;
    } on FirebaseAuthException catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message ?? 'Could not sign out.')),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not sign out. Please try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final profile = context.watch<ProfileCubit>().state;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Your little corner'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ---------- Header ----------
          AppCard(
            child: Row(
              children: [
                CircleAvatar(
                  radius: 36,
                  backgroundColor: c.outline.withValues(alpha: .4),
                  child: Icon(
                    Icons.person_outline,
                    size: 36,
                    color: c.onSurface,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTheme.titleBold.copyWith(
                          fontSize: 20,
                          color: c.onSurface,
                        ),
                      ),
                      if (profile.email.isNotEmpty)
                        Text(
                          profile.email,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTheme.small.copyWith(
                            color: c.onSurfaceVariant,
                          ),
                        ),
                      const SizedBox(height: 4),
                      GestureDetector(
                        onTap: () => _openEditProfile(context),
                        child: Text(
                          'Edit Profile',
                          style: AppTheme.label.copyWith(color: c.primary),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ---------- Meals ----------
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              children: [
                _MenuTile(
                  Icons.favorite_border,
                  'Favorite Meals',
                  () => _soon(context),
                ),
                _MenuTile(
                  Icons.calendar_today_outlined,
                  'Planned Meals',
                  () => _soon(context),
                ),
                _MenuTile(Icons.history, 'Meal History', () => _soon(context)),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ---------- Settings ----------
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              children: [
                SwitchListTile(
                  secondary: Icon(Icons.dark_mode_outlined, color: c.onSurface),
                  title: Text(
                    'Dark mode',
                    style: AppTheme.label.copyWith(color: c.onSurface),
                  ),
                  value: isDark,
                  onChanged: (v) =>
                      context.read<SettingsCubit>().setDarkMode(v),
                ),
                _MenuTile(
                  Icons.info_outline,
                  'About',
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AboutScreen()),
                  ),
                ),
                _MenuTile(
                  Icons.settings_outlined,
                  'Settings',
                  () => _openSettings(context),
                ),
                _MenuTile(
                  Icons.logout,
                  'Logout',
                  () => _logout(context),
                  trailing: false,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ---------- Diet, goals & sync ----------
          AppButton(
            label: 'Diet, goals & sync',
            outlined: true,
            onPressed: () => _openEditProfile(context),
          ),
          const SizedBox(height: 16),

          // ---------- Sync status ----------
          AppCard(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(Icons.sync, size: 18, color: c.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Synced across devices · Simulated sync status',
                    style: AppTheme.small.copyWith(color: c.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final bool trailing;

  const _MenuTile(this.icon, this.title, this.onTap, {this.trailing = true});

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return ListTile(
      tileColor: c.surface,
      splashColor: c.primary.withValues(alpha: 0.16),
      hoverColor: c.primary.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
      ),
      leading: Icon(icon, color: c.onSurface),
      title: Text(title, style: AppTheme.label.copyWith(color: c.onSurface)),
      trailing: trailing ? Icon(Icons.chevron_right, color: c.onSurface) : null,
      onTap: onTap,
    );
  }
}
