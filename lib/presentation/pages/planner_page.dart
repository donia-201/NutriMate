import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../core/app_theme.dart';
import '../../core/app_widgets.dart';
import '../../data/models/meal_model.dart';
import '../../data/models/planned_meal.dart';
import '../cubit/planner_cubit.dart';
import '../cubit/planner_state.dart';
import 'add_to_planner_sheet.dart';
import '../../core/guest_guard.dart';
import '../cubit/favorites_cubit.dart';
import '../cubit/search_cubit.dart';
import '../cubit/search_state.dart';
import 'search_page.dart';
import 'meal_details_page.dart';

class PlannerPage extends StatelessWidget {
  final PlannerCubit? cubit;
  final bool embedded;

  /// Called by the back arrow. When the planner is a tab inside the home
  /// shell there is nothing to pop, so the shell passes its own action.
  final VoidCallback? onBack;
  final ValueChanged<int>? onBottomNavTap;
  final VoidCallback? onAddMeal;

  const PlannerPage({
    super.key,
    this.cubit,
    this.embedded = false,
    this.onBack,
    this.onBottomNavTap,
    this.onAddMeal,
  });

  @override
  Widget build(BuildContext context) {
    if (cubit != null) {
      return BlocProvider.value(
        value: cubit!,
        child: _PlannerView(
          embedded: embedded,
          onBack: onBack,
          onBottomNavTap: onBottomNavTap,
          onAddMeal: onAddMeal,
        ),
      );
    }
    return BlocProvider(
      create: (_) => PlannerCubit()..initialize(),
      child: _PlannerView(
        embedded: embedded,
        onBack: onBack,
        onBottomNavTap: onBottomNavTap,
        onAddMeal: onAddMeal,
      ),
    );
  }
}

class _PlannerView extends StatelessWidget {
  final bool embedded;
  final VoidCallback? onBack;
  final ValueChanged<int>? onBottomNavTap;
  final VoidCallback? onAddMeal;
  const _PlannerView({
    required this.embedded,
    this.onBack,
    this.onBottomNavTap,
    this.onAddMeal,
  });

  @override
  Widget build(BuildContext context) => BlocBuilder<PlannerCubit, PlannerState>(
    builder: (context, state) {
      final cubit = context.read<PlannerCubit>();
      final content = SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              sliver: SliverToBoxAdapter(child: _header(context, state)),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverToBoxAdapter(
                child: _daySelector(context, state, cubit),
              ),
            ),
            if (state.isLoading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (state.errorMessage != null)
              SliverToBoxAdapter(
                child: _message(context, cubit, state.errorMessage!),
              )
            else if (state.meals.isEmpty)
              SliverToBoxAdapter(
                child: _emptyState(context, cubit, state.selectedDay),
              )
            else
              _mealCards(context, state, cubit),
            if (!state.isLoading &&
                state.errorMessage == null &&
                state.meals.isNotEmpty &&
                !PlannerCubit.isPastDay(state.selectedDay))
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                sliver: SliverToBoxAdapter(
                  child: _addButton(context, cubit, state.selectedDay),
                ),
              ),
          ],
        ),
      );
      return embedded ? content : Scaffold(body: content);
    },
  );

  Widget _header(BuildContext context, PlannerState state) => Row(
    children: [
      IconButton(
        onPressed: () {
          if (onBack != null) {
            onBack!();
          } else {
            Navigator.maybePop(context);
          }
        },
        icon: const Icon(Icons.arrow_back),
      ),
      const SizedBox(width: 4),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your weekly plan',
              style: AppTheme.titleBold.copyWith(
                fontSize: 26,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            Text(
              _weekLabel(state.selectedDay),
              style: AppTheme.subTitle.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    ],
  );

  Widget _daySelector(
    BuildContext context,
    PlannerState state,
    PlannerCubit cubit,
  ) {
    final monday = state.selectedDay.subtract(
      Duration(days: state.selectedDay.weekday - 1),
    );
    return Row(
      children: [
        IconButton(
          tooltip: 'Previous week',
          onPressed: () =>
              cubit.loadDay(monday.subtract(const Duration(days: 7))),
          icon: const Icon(Icons.chevron_left),
        ),
        Expanded(
          child: Row(
            children: List.generate(7, (index) {
              final day = monday.add(Duration(days: index));
              final selected = _sameDay(day, state.selectedDay);
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: index == 6 ? 0 : 6),
                  child: ChoiceChip(
                    selected: selected,
                    label: Text(
                      '${_weekday(day)}\n${day.day}',
                      textAlign: TextAlign.center,
                    ),
                    onSelected: (_) => cubit.loadDay(day),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    labelStyle: AppTheme.small.copyWith(
                      color: selected
                          ? Theme.of(context).colorScheme.onPrimary
                          : Theme.of(context).colorScheme.onSurface,
                    ),
                    selectedColor: Theme.of(context).colorScheme.primary,
                    backgroundColor: Theme.of(context).colorScheme.surface,
                    side: BorderSide(
                      color: selected
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.outline,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.cardRadius),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
        IconButton(
          tooltip: 'Next week',
          onPressed: () => cubit.loadDay(monday.add(const Duration(days: 7))),
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }

  SliverList _mealCards(
    BuildContext context,
    PlannerState state,
    PlannerCubit cubit,
  ) {
    final grouped = <String, PlannedMeal>{
      for (final meal in state.meals) meal.slot: meal,
    };
    final isPast = PlannerCubit.isPastDay(state.selectedDay);
    return SliverList(
      delegate: SliverChildListDelegate([
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${DateFormat('EEE, MMM d').format(state.selectedDay)} - Planned, not consumed',
                style: AppTheme.subTitle.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              if (isPast) ...[
                const SizedBox(height: 8),
                Text(
                  'Past date: view-only. Meals cannot be added, replaced, or removed.',
                  style: AppTheme.small.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ],
            ],
          ),
        ),
        ...plannerSlots
            .where(grouped.containsKey)
            .map(
              (slot) => Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 6,
                ),
                child: _plannedCard(context, grouped[slot]!, cubit),
              ),
            ),
      ]),
    );
  }

  Widget _plannedCard(
    BuildContext context,
    PlannedMeal meal,
    PlannerCubit cubit,
  ) {
    final isPast = PlannerCubit.isPastDay(meal.day);
    final favorites = context.watch<FavoritesCubit>();
    final isFavorite = favorites.isFavorite(meal.idMeal);
    return InkWell(
      borderRadius: BorderRadius.circular(AppTheme.cardRadius),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) => MealDetailsPage(meal: _asMeal(meal)),
          ),
        );
      },
      child: AppCard(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _slotIcon(meal.slot),
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(meal.slot, style: AppTheme.label.copyWith(fontSize: 18)),
                const Spacer(),
                IconButton(
                  tooltip: isFavorite
                      ? 'Remove from favorites'
                      : 'Add to favorites',
                  onPressed: () => _toggleFavorite(context, meal),
                  icon: Icon(
                    isFavorite ? Icons.favorite : Icons.favorite_border,
                    color: isFavorite
                        ? AppColors.accentHeart
                        : Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppTheme.smallRadius),
                  child: Image.network(
                    meal.strMealThumb,
                    width: 90,
                    height: 90,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const SizedBox(
                      width: 90,
                      height: 90,
                      child: Icon(Icons.restaurant),
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
                        style: AppTheme.label.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${meal.calories} kcal - ${meal.servings} serving${meal.servings == 1 ? '' : 's'}',
                        style: AppTheme.body.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Planned, not consumed',
                        style: AppTheme.small.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: isPast
                        ? null
                        : () async {
                            if (!await requireSignedIn(
                              context,
                              feature: 'Meal planning',
                            )) {
                              return;
                            }
                            if (!context.mounted) return;
                            showAddToPlannerSheet(
                              context,
                              _asMeal(meal),
                              initialDay: meal.day,
                              cubit: cubit,
                            );
                          },
                    child: const Text('Replace'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: isPast
                        ? null
                        : () => _remove(context, cubit, meal),
                    child: const Text('Remove'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyState(BuildContext context, PlannerCubit cubit, DateTime day) =>
      Padding(
        padding: const EdgeInsets.all(20),
        child: AppCard(
          child: Column(
            children: [
              Icon(
                Icons.event_note_outlined,
                size: 44,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 12),
              Text('No meals planned for this day.', style: AppTheme.label),
              const SizedBox(height: 6),
              Text(
                PlannerCubit.isPastDay(day)
                    ? 'Past dates are view-only. No meals can be added.'
                    : 'Add a recipe to keep your week organized.',
                textAlign: TextAlign.center,
                style: AppTheme.body.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              if (!PlannerCubit.isPastDay(day)) ...[
                const SizedBox(height: 16),
                _addButton(context, cubit, day),
              ],
            ],
          ),
        ),
      );

  // TODO: Add reminder scheduling when the notification service is available.
  Widget _addButton(BuildContext context, PlannerCubit cubit, DateTime day) =>
      ElevatedButton(
        onPressed: PlannerCubit.isPastDay(day)
            ? () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Past dates are view-only. Choose today or a future day.',
                    ),
                  ),
                );
              }
            : () => _openSearch(context),
        child: Text(isGuestUser() ? 'Sign in to plan meals' : 'Add meal'),
      );

  Widget _message(BuildContext context, PlannerCubit cubit, String message) =>
      Padding(
        padding: const EdgeInsets.all(20),
        child: AppCard(
          child: Column(
            children: [
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              TextButton(
                onPressed: cubit.retry,
                child: const Text('Try again'),
              ),
            ],
          ),
        ),
      );

  Future<void> _toggleFavorite(
    BuildContext context,
    PlannedMeal plannedMeal,
  ) async {
    if (!await requireSignedIn(context, feature: 'Favorites')) return;
    if (!context.mounted) return;

    final favorites = context.read<FavoritesCubit>();
    final ok = await favorites.toggle(_asMeal(plannedMeal));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? (favorites.isFavorite(plannedMeal.idMeal)
                    ? 'Added to your favorites.'
                    : 'Removed from favorites.')
              : (favorites.state.errorMessage ??
                    'Could not update favorites. Please try again.'),
        ),
      ),
    );
  }

  Future<void> _openSearch(BuildContext context) async {
    if (!await requireSignedIn(context, feature: 'Meal planning')) return;
    if (!context.mounted) return;

    if (onAddMeal != null) {
      onAddMeal!();
      return;
    }

    final searchCubit = context.read<SearchCubit>();
    searchCubit.setMode(SearchMode.search);
    searchCubit.clear();

    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: searchCubit,
          child: SearchPage(
            embedded: false,
            onBottomNavTap: (index) {
              Navigator.of(context).pop();
              onBottomNavTap?.call(index);
            },
          ),
        ),
      ),
    );
  }

  Future<void> _remove(
    BuildContext context,
    PlannerCubit cubit,
    PlannedMeal meal,
  ) async {
    if (PlannerCubit.isPastDay(meal.day)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Past planned meals cannot be changed or removed.'),
        ),
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove planned meal?'),
        content: Text('Remove ${meal.strMeal} from ${meal.slot}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) await cubit.removeMeal(meal);
  }

  MealModel _asMeal(PlannedMeal meal) => MealModel(
    idMeal: meal.idMeal,
    strMeal: meal.strMeal,
    strMealThumb: meal.strMealThumb,
    strCategory: meal.strCategory,
    strArea: meal.strArea,
  );

  IconData _slotIcon(String slot) => switch (slot) {
    'Breakfast' => Icons.wb_sunny_outlined,
    'Lunch' => Icons.wb_sunny,
    'Dinner' => Icons.nightlight_outlined,
    _ => Icons.restaurant,
  };

  String _weekday(DateTime day) =>
      const ['M', 'T', 'W', 'T', 'F', 'S', 'S'][day.weekday - 1];

  String _weekLabel(DateTime day) {
    final monday = day.subtract(Duration(days: day.weekday - 1));
    final sunday = monday.add(const Duration(days: 6));
    return '${DateFormat('MMMM d').format(monday)}-${DateFormat('d, yyyy').format(sunday)}';
  }

  bool _sameDay(DateTime first, DateTime second) =>
      first.year == second.year &&
      first.month == second.month &&
      first.day == second.day;
}
