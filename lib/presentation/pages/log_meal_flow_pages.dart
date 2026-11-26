import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../core/app_widgets.dart';
import '../../core/guest_guard.dart';
import '../../core/utils/app_colors.dart';
import '../../core/utils/app_text_style.dart';
import '../../data/models/meal_model.dart';
import '../cubit/favorites_cubit.dart';
import '../cubit/favorites_state.dart';
import '../cubit/meal_log_session.dart';
import '../cubit/search_cubit.dart';
import '../cubit/search_state.dart';
import '../widgets/bottom_nav.dart';
import 'insights_page.dart';
import 'search_page.dart';

class LogMealPage extends StatefulWidget {
  final MealLogSession session;
  final ValueChanged<int>? onBottomNavTap;

  const LogMealPage({
    super.key,
    required this.session,
    this.onBottomNavTap,
  });

  @override
  State<LogMealPage> createState() => _LogMealPageState();
}

class _LogMealPageState extends State<LogMealPage> {
  final Set<String> _pendingFavoriteIds = {};

  Future<void> _toggleFavorite(MealModel meal) async {
    if (!_pendingFavoriteIds.add(meal.idMeal)) return;
    try {
      if (!await requireSignedIn(context, feature: 'Saving favorites')) return;
      if (!mounted) return;

      final favorites = context.read<FavoritesCubit>();
      final isFavorite = favorites.isFavorite(meal.idMeal);
      if (isFavorite) {
        final confirmed = await showActionConfirmationDialog(
          context,
          title: 'Remove from favorites?',
          message: 'Remove ${meal.strMeal} from your favorites?',
          confirmLabel: 'Remove',
          icon: Icons.favorite_border,
          accentColor: Theme.of(context).colorScheme.error,
        );
        if (!confirmed || !mounted) return;
      }

      await favorites.toggle(meal);
    } finally {
      _pendingFavoriteIds.remove(meal.idMeal);
    }
  }

  Future<void> _pickDateTime() async {
    final current = widget.session.selectedDateTime;
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (pickedDate == null || !mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
    );
    if (pickedTime == null || !mounted) return;

    final combined = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );
    widget.session.updateSelectedDateTime(combined);
  }

  Future<void> _openSearchForLogging() async {
    final searchCubit = context.read<SearchCubit>()..setMode(SearchMode.search);
    final result = await Navigator.of(context).push<Object?>(
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: searchCubit,
          child: SearchPage(
            embedded: false,
            logSession: widget.session,
            onBottomNavTap: (index) {
              Navigator.of(context).pop();
              widget.onBottomNavTap?.call(index);
            },
          ),
        ),
      ),
    );
    if (!mounted) return;
    if (result is StagedMealEntry) {
      widget.session.stageMeal(
        result.meal,
        nutrition: result.nutrition,
        eatenAt: result.eatenAt,
      );
    }
  }

  void _openConfirmation() {
    if (!widget.session.hasEntries) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ConfirmLogMealPage(
          session: widget.session,
          onBottomNavTap: widget.onBottomNavTap,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final formattedDateTime = DateFormat(
      'MMM d, y · h:mm a',
    ).format(widget.session.selectedDateTime);

    return AnimatedBuilder(
      animation: widget.session,
      builder: (context, _) {
        final entries = widget.session.entries;
        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: AppBar(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'What did you eat?',
                  style: AppTextStyles.titleBold.copyWith(
                    fontSize: 20,
                    color: colors.onSurface,
                  ),
                ),
                Text(
                  'Consumed logging · not planning',
                  style: AppTextStyles.subTitle.copyWith(
                    fontSize: 12.5,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          body: SafeArea(
            top: false,
            child: BlocBuilder<FavoritesCubit, FavoritesState>(
              builder: (context, favState) => ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                children: [
                  Text(
                    'Find a recipe',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: colors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: _openSearchForLogging,
                    borderRadius: BorderRadius.circular(18),
                    child: Container(
                      height: 50,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: colors.surface,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: colors.outline.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Search available meals',
                              style: TextStyle(
                                color: colors.onSurfaceVariant,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          Icon(Icons.search, color: colors.onSurface),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (entries.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: colors.surface,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'No meals staged yet. Search for a meal and tap "Log as eaten" to add it here.',
                        style: TextStyle(color: colors.onSurfaceVariant),
                      ),
                    )
                  else
                    ...entries.asMap().entries.map((item) {
                      final index = item.key;
                      final entry = item.value;
                      final meal = entry.meal;
                      final isFav = favState.ids.contains(meal.idMeal);
                      final kcal = entry.nutrition?.calories;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: colors.surface,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: Image.network(
                                  meal.strMealThumb,
                                  width: 68,
                                  height: 68,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => Container(
                                    width: 68,
                                    height: 68,
                                    color: colors.surfaceContainerHighest,
                                    child: const Icon(Icons.restaurant),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      meal.strMeal,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 15,
                                        color: colors.onSurface,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      [
                                        meal.strCategory ?? 'Meal',
                                        meal.strArea ?? 'International',
                                      ].join(' · '),
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        color: colors.onSurfaceVariant,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      kcal == null
                                          ? 'Estimated kcal · serving'
                                          : '${kcal.round()} kcal / serving',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: colors.onSurface,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                onPressed: () => _toggleFavorite(meal),
                                icon: Icon(
                                  isFav
                                      ? Icons.favorite
                                      : Icons.favorite_border,
                                  color: isFav
                                      ? AppColors.accentHeart
                                      : colors.onSurfaceVariant,
                                ),
                              ),
                              IconButton(
                                tooltip: 'Remove from log',
                                onPressed: () =>
                                    widget.session.removeEntryAt(index),
                                icon: Icon(
                                  Icons.close,
                                  size: 20,
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  const SizedBox(height: 12),
                  Text(
                    'Date & time consumed',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: colors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: _pickDateTime,
                    borderRadius: BorderRadius.circular(18),
                    child: Container(
                      height: 52,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: colors.surface,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: colors.outline.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              formattedDateTime,
                              style: TextStyle(
                                color: colors.onSurface,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.calendar_today_outlined,
                            size: 20,
                            color: colors.onSurface,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.primaryGreen.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 20,
                          color: colors.onSurfaceVariant,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Select a meal, then confirm it was eaten. Portion editing is pending approval.',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: entries.isEmpty ? null : _openConfirmation,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryGreen,
                        foregroundColor: AppColors.buttonText,
                        disabledBackgroundColor: AppColors.primaryGreen
                            .withValues(alpha: 0.45),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                      child: const Text(
                        'Continue',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          bottomNavigationBar: BottomNavBar(
            currentIndex: 0,
            onTap: widget.onBottomNavTap ?? (_) => Navigator.of(context).pop(),
          ),
        );
      },
    );
  }
}

class ConfirmLogMealPage extends StatefulWidget {
  final MealLogSession session;
  final ValueChanged<int>? onBottomNavTap;

  const ConfirmLogMealPage({
    super.key,
    required this.session,
    this.onBottomNavTap,
  });

  @override
  State<ConfirmLogMealPage> createState() => _ConfirmLogMealPageState();
}

class _ConfirmLogMealPageState extends State<ConfirmLogMealPage> {
  bool _submitting = false;

  Future<void> _confirmConsumedMeal() async {
    if (_submitting) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      if (!await requireSignedIn(
        context,
        feature: 'Saving nutrition insights',
      )) {
        return;
      }
      if (!mounted) return;
    }

    final activeUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    setState(() => _submitting = true);
    try {
      await widget.session.confirmAll(activeUid);
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => InsightsPage(
            onBottomNavTap: widget.onBottomNavTap,
          ),
        ),
        (route) => route.isFirst,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              e.toString().replaceFirst('Exception: ', ''),
            ),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final entries = widget.session.entries;

    double totalKcal = 0;
    double totalProtein = 0;
    double totalCarbs = 0;
    double totalFat = 0;
    for (final entry in entries) {
      totalKcal += entry.nutrition?.calories ?? 0;
      totalProtein += entry.nutrition?.protein ?? 0;
      totalCarbs += entry.nutrition?.carbohydrates ?? 0;
      totalFat += entry.nutrition?.fat ?? 0;
    }

    final firstTimeText = entries.isEmpty
        ? ''
        : DateFormat('MMM d, y · h:mm a').format(entries.first.eatenAt);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Log as eaten',
          style: AppTextStyles.titleBold.copyWith(
            fontSize: 20,
            color: colors.onSurface,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            ...entries.map((entry) {
              final meal = entry.meal;
              final kcal = entry.nutrition?.calories;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.network(
                          meal.strMealThumb,
                          width: 68,
                          height: 68,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Container(
                            width: 68,
                            height: 68,
                            color: colors.surfaceContainerHighest,
                            child: const Icon(Icons.restaurant),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              meal.strMeal,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                                color: colors.onSurface,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              [
                                meal.strCategory ?? 'Meal',
                                meal.strArea ?? 'International',
                              ].join(' · '),
                              style: TextStyle(
                                fontSize: 12.5,
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              kcal == null
                                  ? 'Estimated kcal · serving'
                                  : '${kcal.round()} kcal / serving',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: colors.onSurface,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: colors.outline.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Icon(
                      Icons.help_outline,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Did you eat this meal?',
                    style: AppTextStyles.titleBold.copyWith(
                      fontSize: 21,
                      color: colors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Log ${entries.length} meal(s) for $firstTimeText. '
                    'Estimated: ${totalKcal.round()} kcal · '
                    '${totalProtein.round()}g protein · '
                    '${totalCarbs.round()}g carbs · '
                    '${totalFat.round()}g fat. '
                    'This updates Insights, not Planner.',
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.45,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _submitting ? null : _confirmConsumedMeal,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryGreen,
                        foregroundColor: AppColors.buttonText,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                      child: Text(
                        _submitting
                            ? 'Saving...'
                            : 'Confirm consumed meal',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton(
                      onPressed:
                          _submitting ? null : () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: 0,
        onTap: widget.onBottomNavTap ?? (_) => Navigator.of(context).pop(),
      ),
    );
  }
}