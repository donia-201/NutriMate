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

class PlannerPage extends StatelessWidget {
  final PlannerCubit? cubit;
  final bool embedded;

  const PlannerPage({super.key, this.cubit, this.embedded = false});

  @override
  Widget build(BuildContext context) {
    if (cubit != null) {
      return BlocProvider.value(
        value: cubit!,
        child: _PlannerView(embedded: embedded),
      );
    }
    return BlocProvider(
      create: (_) => PlannerCubit()..initialize(),
      child: _PlannerView(embedded: embedded),
    );
  }
}

class _PlannerView extends StatelessWidget {
  final bool embedded;
  const _PlannerView({required this.embedded});

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
        onPressed: () => Navigator.maybePop(context),
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
      IconButton(onPressed: () {}, icon: const Icon(Icons.more_horiz)),
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
    return SliverList(
      delegate: SliverChildListDelegate([
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
          child: Text(
            '${DateFormat('EEE, MMM d').format(state.selectedDay)} â€¢ Planned, not consumed',
            style: AppTheme.subTitle.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
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
  ) => AppCard(
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
            Icon(Icons.favorite, color: Theme.of(context).colorScheme.primary),
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
                    '${meal.calories} kcal â€¢ ${meal.servings} serving${meal.servings == 1 ? '' : 's'}',
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
                onPressed: () => showAddToPlannerSheet(
                  context,
                  _asMeal(meal),
                  initialDay: meal.day,
                  cubit: cubit,
                ),
                child: const Text('Replace'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton(
                onPressed: () => _remove(context, cubit, meal),
                child: const Text('Remove'),
              ),
            ),
          ],
        ),
      ],
    ),
  );

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
                'Add a recipe to keep your week organized.',
                textAlign: TextAlign.center,
                style: AppTheme.body.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              _addButton(context, cubit, day),
            ],
          ),
        ),
      );

  // TODO: Add reminder scheduling when the notification service is available.
  Widget _addButton(BuildContext context, PlannerCubit cubit, DateTime day) =>
      ElevatedButton(
        onPressed: () => _chooseMeal(context, cubit, day),
        child: const Text('Add meal'),
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

  Future<void> _chooseMeal(
    BuildContext context,
    PlannerCubit cubit,
    DateTime day,
  ) async {
    final meals = await cubit.cachedMeals();
    if (!context.mounted) return;
    if (meals.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Search for a recipe first, then add it to your planner.',
          ),
        ),
      );
      return;
    }
    final meal = await showModalBottomSheet<MealModel>(
      context: context,
      showDragHandle: true,
      builder: (context) => ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Choose a meal',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
          ),
          const SizedBox(height: 12),
          ...meals.map(
            (meal) => ListTile(
              leading: CircleAvatar(
                backgroundImage: NetworkImage(meal.strMealThumb),
              ),
              title: Text(meal.strMeal),
              subtitle: Text(meal.strCategory ?? 'Meal'),
              onTap: () => Navigator.pop(context, meal),
            ),
          ),
        ],
      ),
    );
    if (meal != null && context.mounted) {
      await showAddToPlannerSheet(context, meal, initialDay: day, cubit: cubit);
    }
  }

  Future<void> _remove(
    BuildContext context,
    PlannerCubit cubit,
    PlannedMeal meal,
  ) async {
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
    return '${DateFormat('MMMM d').format(monday)}â€“${DateFormat('d, yyyy').format(sunday)}';
  }

  bool _sameDay(DateTime first, DateTime second) =>
      first.year == second.year &&
      first.month == second.month &&
      first.day == second.day;
}
