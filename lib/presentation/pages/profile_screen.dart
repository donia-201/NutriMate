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

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  void _soon(BuildContext context) => ScaffoldMessenger.of(context)
      .showSnackBar(const SnackBar(content: Text('Coming soon')));

  void _openEditProfile(BuildContext context) => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const EditProfileScreen()),
  );

  void _logout(BuildContext context) {
    // لازم نرجع للـ root الأول، وإلا الشاشة هتفضل فوق الـ AuthGate
    Navigator.of(context).popUntil((route) => route.isFirst);
    FirebaseAuth.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final profile = context.watch<ProfileCubit>().state;
    final isDark = profile.themeMode == ThemeMode.dark;

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
            child: Row(children: [
              CircleAvatar(
                radius: 36,
                backgroundColor: c.outline.withValues(alpha: .4),
                child: Icon(Icons.person_outline, size: 36, color: c.onSurface),
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
                      style: AppTheme.titleBold
                          .copyWith(fontSize: 20, color: c.onSurface),
                    ),
                    if (profile.email.isNotEmpty)
                      Text(
                        profile.email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTheme.small.copyWith(color: c.onSurfaceVariant),
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
            ]),
          ),
          const SizedBox(height: 16),

          // ---------- Menu (meals + dark mode + about + logout) ----------
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(children: [
              _MenuTile(
                Icons.favorite_border,
                'Favorite Meals',
                    () async {
                  if (!await requireSignedIn(context, feature: 'Favorites')) return;
                  if (!context.mounted) return;
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const FavoritesScreen()),
                  );
                },
              ),
              _MenuTile(
                Icons.calendar_today_outlined,
                'Planned Meals',
                    () async {
                  if (!await requireSignedIn(context, feature: 'Meal planning')) return;
                  if (!context.mounted) return;
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => PlannerPage()),
                  );
                },
              ),
              _MenuTile(Icons.history, 'Meal History', () => _soon(context)),
              SwitchListTile(
                secondary: Icon(Icons.dark_mode_outlined, color: c.onSurface),
                title: Text(
                  'Dark mode',
                  style: AppTheme.label.copyWith(color: c.onSurface),
                ),
                value: isDark,
                onChanged: (v) => context.read<ProfileCubit>().setDarkMode(v),
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
            ]),
          ),
          const SizedBox(height: 16),



          // ---------- Sync status ----------
          AppCard(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              Icon(Icons.sync, size: 18, color: c.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Synced across devices · Simulated sync status',
                  style: AppTheme.small.copyWith(color: c.onSurfaceVariant),
                ),
              ),
            ]),
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
      leading: Icon(icon, color: c.onSurface),
      title: Text(title, style: AppTheme.label.copyWith(color: c.onSurface)),
      trailing: trailing ? Icon(Icons.chevron_right, color: c.onSurface) : null,
      onTap: onTap,
    );
  }
}