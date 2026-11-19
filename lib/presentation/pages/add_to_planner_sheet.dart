import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../core/app_widgets.dart';
import '../../data/models/meal.model.dart';
import '../cubit/planner_cubit.dart';

Future<bool?> showAddToPlannerSheet(
  BuildContext context,
  MealModel meal, {
  DateTime? initialDay,
  PlannerCubit? cubit,
}) {
  final plannerCubit = cubit ?? PlannerCubit();
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _PlannerSheet(
      meal: meal,
      initialDay: initialDay ?? DateTime.now(),
      cubit: plannerCubit,
      ownsCubit: cubit == null,
    ),
  );
}

class _PlannerSheet extends StatefulWidget {
  final MealModel meal;
  final DateTime initialDay;
  final PlannerCubit cubit;
  final bool ownsCubit;

  const _PlannerSheet({
    required this.meal,
    required this.initialDay,
    required this.cubit,
    required this.ownsCubit,
  });

  @override
  State<_PlannerSheet> createState() => _PlannerSheetState();
}

class _PlannerSheetState extends State<_PlannerSheet> {
  late DateTime _day;
  String _slot = plannerSlots[1];
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _day = DateTime(
      widget.initialDay.year,
      widget.initialDay.month,
      widget.initialDay.day,
    );
  }

  @override
  void dispose() {
    if (widget.ownsCubit) widget.cubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final weekStart = _day.subtract(Duration(days: _day.weekday - 1));
    final days = List.generate(
      7,
      (index) => weekStart.add(Duration(days: index)),
    );
    return SafeArea(
      child: Container(
        constraints: const BoxConstraints(maxHeight: 680),
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppTheme.sheetRadius),
          ),
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Add to Planner',
                style: AppTheme.titleBold.copyWith(
                  fontSize: 26,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Choose a day and meal type. This does not log food as eaten.',
                style: AppTheme.subTitle.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              _mealPreview(),
              const SizedBox(height: 20),
              _sectionLabel('Day'),
              const SizedBox(height: 8),
              _daySelector(days),
              const SizedBox(height: 20),
              _sectionLabel('Meal slot'),
              const SizedBox(height: 8),
              Wrap(spacing: 8, children: plannerSlots.map(_slotChip).toList()),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: AppButton(
                  label: _isSaving ? 'Saving...' : 'Add meal',
                  onPressed: _isSaving ? null : _confirm,
                  isLoading: _isSaving,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _isSaving
                      ? null
                      : () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _mealPreview() => AppCard(
    padding: const EdgeInsets.all(10),
    child: Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppTheme.smallRadius),
          child: Image.network(
            widget.meal.strMealThumb,
            width: 76,
            height: 76,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => const SizedBox(
              width: 76,
              height: 76,
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
                widget.meal.strMeal,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTheme.label.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${widget.meal.strCategory ?? 'Meal'} • ${widget.meal.strArea ?? 'International'}',
              ),
              const SizedBox(height: 4),
              Text(
                'Nutrition calculation pending',
                style: AppTheme.small.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _sectionLabel(String label) => Text(
    label,
    style: AppTheme.label.copyWith(
      color: Theme.of(context).colorScheme.onSurface,
    ),
  );

  Widget _daySelector(List<DateTime> days) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      children: days.map((day) {
        final selected = _sameDay(day, _day);
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: ChoiceChip(
            selected: selected,
            label: Text('${_weekday(day)} ${day.day}'),
            labelStyle: AppTheme.label.copyWith(
              fontSize: 12,
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
            onSelected: (_) => setState(() => _day = day),
          ),
        );
      }).toList(),
    ),
  );

  Widget _slotChip(String slot) => ChoiceChip(
    selected: _slot == slot,
    label: Text(slot),
    labelStyle: AppTheme.label.copyWith(
      color: _slot == slot
          ? Theme.of(context).colorScheme.onPrimary
          : Theme.of(context).colorScheme.onSurface,
    ),
    selectedColor: Theme.of(context).colorScheme.primary,
    backgroundColor: Theme.of(context).colorScheme.surface,
    side: BorderSide(
      color: _slot == slot
          ? Theme.of(context).colorScheme.primary
          : Theme.of(context).colorScheme.outline,
    ),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppTheme.cardRadius),
    ),
    onSelected: (_) => setState(() => _slot = slot),
  );

  Future<void> _confirm() async {
    final existing = await widget.cubit.plannedMeal(_day, _slot);
    if (!mounted) return;
    if (existing != null) {
      final replace = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Replace planned meal?'),
          content: Text(
            '$_slot already has ${existing.strMeal}. Replace it with ${widget.meal.strMeal}?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Replace'),
            ),
          ],
        ),
      );
      if (replace != true || !mounted) return;
    }
    setState(() => _isSaving = true);
    await widget.cubit.saveMeal(meal: widget.meal, day: _day, slot: _slot);
    if (!mounted) return;
    if (widget.cubit.state.errorMessage != null) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(widget.cubit.state.errorMessage!)));
      return;
    }
    Navigator.pop(context, true);
  }

  String _weekday(DateTime day) =>
      const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][day.weekday - 1];

  bool _sameDay(DateTime first, DateTime second) =>
      first.year == second.year &&
      first.month == second.month &&
      first.day == second.day;
}
