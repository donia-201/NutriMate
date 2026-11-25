import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/app_theme.dart';
import '../../core/app_widgets.dart';
import '../../core/guest_guard.dart';
import '../../data/models/meal_model.dart';
import '../cubit/planner_cubit.dart';

Future<bool?> showAddToPlannerSheet(
  BuildContext context,
  MealModel meal, {
  DateTime? initialDay,
  required PlannerCubit cubit,
  int calories = 0,
}) async {
  final requestedDay = initialDay ?? DateTime.now();
  if (PlannerCubit.isPastDay(requestedDay)) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Past dates are view-only. Choose today or a future day.',
        ),
      ),
    );
    return false;
  }
  if (!await requireSignedIn(context, feature: 'Meal planning')) {
    return false;
  }
  if (!context.mounted) return false;
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _PlannerSheet(
      meal: meal,
      initialDay: initialDay ?? DateTime.now(),
      cubit: cubit,
      calories: calories,
    ),
  );
}

class _PlannerSheet extends StatefulWidget {
  final MealModel meal;
  final DateTime initialDay;
  final PlannerCubit cubit;
  final int calories;

  const _PlannerSheet({
    required this.meal,
    required this.initialDay,
    required this.cubit,
    required this.calories,
  });

  @override
  State<_PlannerSheet> createState() => _PlannerSheetState();
}

class _PlannerSheetState extends State<_PlannerSheet> {
  late DateTime _day;
  String _slot = plannerSlots[1];
  bool _isSaving = false;
  bool _isConfirming = false;

  @override
  void initState() {
    super.initState();
    final initialDay = DateTime(
      widget.initialDay.year,
      widget.initialDay.month,
      widget.initialDay.day,
    );
    _day = PlannerCubit.isPastDay(initialDay)
        ? PlannerCubit.dateOnly(DateTime.now())
        : initialDay;
  }

  @override
  Widget build(BuildContext context) {
    final weekStart = _day.subtract(Duration(days: _day.weekday - 1));
    final isPast = PlannerCubit.isPastDay(_day);
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
              if (isPast) ...[
                const SizedBox(height: 8),
                Text(
                  'Past dates are view-only.',
                  style: AppTheme.small.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ],
              const SizedBox(height: 20),
              _sectionLabel('Meal slot'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: plannerSlots
                    .map((slot) => _slotChip(slot, disabled: isPast))
                    .toList(),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: AppButton(
                  label: isPast
                      ? 'Past date - view only'
                      : _isSaving
                      ? 'Saving...'
                      : _isConfirming
                      ? 'Confirming...'
                      : 'Add meal',
                  onPressed: (_isSaving || _isConfirming || isPast)
                      ? null
                      : _confirm,
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
                '${widget.meal.strCategory ?? 'Meal'} - ${widget.meal.strArea ?? 'International'}',
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
        final past = PlannerCubit.isPastDay(day);
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: ChoiceChip(
            selected: selected,
            label: Text('${_weekday(day)} ${day.day}'),
            labelStyle: AppTheme.label.copyWith(
              fontSize: 12,
              color: selected
                  ? Theme.of(context).colorScheme.onPrimary
                  : past
                  ? Theme.of(context).colorScheme.onSurfaceVariant
                  : Theme.of(context).colorScheme.onSurface,
            ),
            selectedColor: past
                ? Theme.of(context).colorScheme.surfaceContainerHighest
                : Theme.of(context).colorScheme.primary,
            backgroundColor: past
                ? Theme.of(context).colorScheme.surfaceContainerHighest
                : Theme.of(context).colorScheme.surface,
            side: BorderSide(
              color: selected
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.outline,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.cardRadius),
            ),
            onSelected: past ? null : (_) => setState(() => _day = day),
          ),
        );
      }).toList(),
    ),
  );

  Widget _slotChip(String slot, {required bool disabled}) => ChoiceChip(
    selected: _slot == slot,
    label: Text(slot),
    labelStyle: AppTheme.label.copyWith(
      color: disabled
          ? Theme.of(context).colorScheme.onSurfaceVariant
          : _slot == slot
          ? Theme.of(context).colorScheme.onPrimary
          : Theme.of(context).colorScheme.onSurface,
    ),
    selectedColor: disabled
        ? Theme.of(context).colorScheme.surfaceContainerHighest
        : Theme.of(context).colorScheme.primary,
    backgroundColor: disabled
        ? Theme.of(context).colorScheme.surfaceContainerHighest
        : Theme.of(context).colorScheme.surface,
    side: BorderSide(
      color: _slot == slot
          ? Theme.of(context).colorScheme.primary
          : Theme.of(context).colorScheme.outline,
    ),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppTheme.cardRadius),
    ),
    onSelected: disabled ? null : (_) => setState(() => _slot = slot),
  );

  Future<void> _confirm() async {
    if (_isSaving || _isConfirming) return;
    if (PlannerCubit.isPastDay(_day)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Past dates are view-only. Choose today or a future day.',
          ),
        ),
      );
      return;
    }
    setState(() => _isConfirming = true);
    try {
      final existing = await widget.cubit.plannedMeal(_day, _slot);
      if (!mounted) return;

      final date = DateFormat('EEE, MMM d').format(_day);
      final replacing = existing != null;
      if (replacing) {
        final confirmed = await showActionConfirmationDialog(
          context,
          title: 'Replace planned meal?',
          message:
              'Replace ${existing.strMeal} in $_slot on $date with ${widget.meal.strMeal}?',
          confirmLabel: 'Replace',
          icon: Icons.swap_horiz,
          accentColor: Theme.of(context).colorScheme.error,
        );
        if (!confirmed || !mounted) return;
      }

      setState(() {
        _isConfirming = false;
        _isSaving = true;
      });
      await widget.cubit.saveMeal(
        meal: widget.meal,
        day: _day,
        slot: _slot,
        calories: widget.calories,
      );
      if (!mounted) return;
      if (widget.cubit.state.errorMessage != null) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.cubit.state.errorMessage!)),
        );
        return;
      }
      Navigator.pop(context, true);
    } finally {
      if (mounted && _isConfirming) {
        setState(() => _isConfirming = false);
      }
    }
  }

  String _weekday(DateTime day) =>
      const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][day.weekday - 1];

  bool _sameDay(DateTime first, DateTime second) =>
      first.year == second.year &&
      first.month == second.month &&
      first.day == second.day;
}
