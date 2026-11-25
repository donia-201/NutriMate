import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nutri_mate/core/app_theme.dart';
import 'package:nutri_mate/core/app_widgets.dart';
import 'package:nutri_mate/presentation/cubit/profile_cubit.dart';
import 'package:nutri_mate/presentation/pages/edit_profile_screen.dart';
import 'package:nutri_mate/presentation/pages/about_screen.dart';
import 'package:nutri_mate/presentation/pages/favorites_screen.dart';
import 'package:nutri_mate/presentation/pages/planner_page.dart';
import 'package:nutri_mate/core/guest_guard.dart';
import 'package:nutri_mate/presentation/widgets/meal_reminder_times_card.dart';

final Set<String> _pendingProfileActions = {};

class ProfileScreen extends StatelessWidget {
  final ValueChanged<int>? onDestinationChanged;

  const ProfileScreen({super.key, this.onDestinationChanged});

  void _soon(BuildContext context) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(const SnackBar(content: Text('Coming soon')));

  void _openEditProfile(BuildContext context) => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const EditProfileScreen()),
  );

  Future<void> _logout(BuildContext context) async {
    if (!_pendingProfileActions.add('logout')) return;
    try {
      final confirmed = await showActionConfirmationDialog(
        context,
        title: 'Log out?',
        message: 'Are you sure you want to log out of NutriMate?',
        confirmLabel: 'Log out',
        icon: Icons.logout,
        accentColor: Theme.of(context).colorScheme.error,
      );
      if (!confirmed || !context.mounted) return;

      // لازم نرجع للـ root الأول، وإلا الشاشة هتفضل فوق الـ AuthGate
      Navigator.of(context).popUntil((route) => route.isFirst);
      await FirebaseAuth.instance.signOut();
    } finally {
      _pendingProfileActions.remove('logout');
    }
  }

  Future<void> _setDarkMode(BuildContext context, bool enabled) async {
    if (!_pendingProfileActions.add('theme')) return;
    try {
      if (!enabled) {
        final confirmed = await showActionConfirmationDialog(
          context,
          title: 'Disable dark mode?',
          message: 'Switch NutriMate to its light theme?',
          confirmLabel: 'Disable',
          icon: Icons.dark_mode_outlined,
        );
        if (!confirmed || !context.mounted) return;
      }
      await context.read<ProfileCubit>().setDarkMode(enabled);
    } finally {
      _pendingProfileActions.remove('theme');
    }
  }

  Future<void> _setNotifications(BuildContext context, bool enabled) async {
    if (!_pendingProfileActions.add('notifications')) return;
    try {
      if (!enabled) {
        final confirmed = await showActionConfirmationDialog(
          context,
          title: 'Disable meal notifications?',
          message: 'Pause meal reminders?',
          confirmLabel: 'Disable',
          icon: Icons.notifications_outlined,
        );
        if (!confirmed || !context.mounted) return;
      }

      final granted = await context
          .read<ProfileCubit>()
          .setNotificationsEnabled(enabled);
      if (!context.mounted) return;
      if (enabled && !granted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Notification permission is disabled. Enable it in system settings.',
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              enabled
                  ? 'Meal notifications turned on.'
                  : 'Meal notifications turned off.',
            ),
          ),
        );
      }
    } finally {
      _pendingProfileActions.remove('notifications');
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final profile = context.watch<ProfileCubit>().state;
    final isDark =
        profile.themeMode == ThemeMode.dark ||
        (profile.themeMode == ThemeMode.system &&
            MediaQuery.platformBrightnessOf(context) == Brightness.dark);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Your little corner'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: SafeArea(
        top: false,
        child: ListView(
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

            // ---------- Menu (meals + dark mode + about + logout) ----------
            AppCard(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                children: [
                  _MenuTile(Icons.favorite_border, 'Favorite Meals', () async {
                    if (!await requireSignedIn(context, feature: 'Favorites')) {
                      return;
                    }
                    if (!context.mounted) return;
                    if (onDestinationChanged != null) {
                      Navigator.of(context).pop();
                      onDestinationChanged!(1);
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const FavoritesScreen(),
                        ),
                      );
                    }
                  }),
                  _MenuTile(
                    Icons.calendar_today_outlined,
                    'Planned Meals',
                    () async {
                      if (!await requireSignedIn(
                        context,
                        feature: 'Meal planning',
                      )) {
                        return;
                      }
                      if (!context.mounted) return;
                      if (onDestinationChanged != null) {
                        Navigator.of(context).pop();
                        onDestinationChanged!(3);
                      } else {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => PlannerPage()),
                        );
                      }
                    },
                  ),
                  _MenuTile(
                    Icons.history,
                    'Meal History',
                    () => _soon(context),
                  ),
                  SwitchListTile(
                    secondary: Icon(
                      Icons.dark_mode_outlined,
                      color: c.onSurface,
                    ),
                    title: Text(
                      'Dark mode',
                      style: AppTheme.label.copyWith(color: c.onSurface),
                    ),
                    value: isDark,
                    onChanged: (enabled) => _setDarkMode(context, enabled),
                  ),
                  SwitchListTile(
                    secondary: Icon(
                      Icons.notifications_outlined,
                      color: c.onSurface,
                    ),
                    title: Text(
                      'Notifications',
                      style: AppTheme.label.copyWith(color: c.onSurface),
                    ),
                    subtitle: Text(
                      profile.notificationsEnabled
                          ? 'Reminders on - Breakfast, lunch, and dinner'
                          : 'Reminders off - Notifications are paused',
                      style: AppTheme.small.copyWith(color: c.onSurfaceVariant),
                    ),
                    value: profile.notificationsEnabled,
                    onChanged: (enabled) => _setNotifications(context, enabled),
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
                    Icons.logout,
                    'Logout',
                    () => _logout(context),
                    trailing: false,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            const MealReminderTimesCard(),
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
                      'Synced across devices - Simulated sync status',
                      style: AppTheme.small.copyWith(color: c.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
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
      leading: Icon(icon, color: c.onSurface),
      title: Text(title, style: AppTheme.label.copyWith(color: c.onSurface)),
      trailing: trailing ? Icon(Icons.chevron_right, color: c.onSurface) : null,
      onTap: onTap,
    );
  }
}
