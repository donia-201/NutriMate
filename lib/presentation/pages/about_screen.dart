import 'package:flutter/material.dart';
import 'package:nutri_mate/core/app_theme.dart';
import 'package:nutri_mate/core/app_widgets.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('About NutriMate'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(28),
              ),
              child: Icon(Icons.eco_outlined, size: 52, color: c.primary),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              'NutriMate',
              style: AppTheme.titleBold.copyWith(
                fontSize: 30,
                color: c.onSurface,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Center(
            child: Text(
              'Eat smart. Plan better.',
              style: AppTheme.subTitle.copyWith(color: c.onSurfaceVariant),
            ),
          ),
          const SizedBox(height: 24),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Discover recipes, plan meals and review meal history.',
                  style: AppTheme.body.copyWith(color: c.onSurface),
                ),
                const Divider(height: 28),
                _InfoRow(Icons.code, 'Developer', ''),
                const SizedBox(height: 12),
                _InfoRow(Icons.info_outline, 'Version', '1.0.0'),
                const SizedBox(height: 16),
                Text(
                  '(c) 2026 NutriMate',
                  style: AppTheme.small.copyWith(color: c.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow(this.icon, this.label, this.value);

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 20, color: c.onSurface),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: AppTheme.label.copyWith(color: c.onSurface),
          ),
        ),
        Text(value, style: AppTheme.body.copyWith(color: c.onSurfaceVariant)),
      ],
    );
  }
}
