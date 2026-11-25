import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/app_theme.dart';
import '../../core/app_widgets.dart';
import '../cubit/profile_cubit.dart';

class MealReminderTimesCard extends StatefulWidget {
  const MealReminderTimesCard({super.key});

  @override
  State<MealReminderTimesCard> createState() => _MealReminderTimesCardState();
}

class _MealReminderTimesCardState extends State<MealReminderTimesCard> {
  final Set<String> _pendingSlots = {};

  Future<void> _selectTime(String slot, TimeOfDay currentTime) async {
    if (!_pendingSlots.add(slot)) return;
    setState(() {});

    try {
      final theme = Theme.of(context);
      final colors = theme.colorScheme;
      final selectedTime = await showTimePicker(
        context: context,
        initialTime: currentTime,
        builder: (_, child) => Theme(
          data: theme.copyWith(
            timePickerTheme: TimePickerThemeData(
              backgroundColor: colors.surface,
              dialBackgroundColor: colors.primary.withValues(alpha: 0.12),
              dialHandColor: colors.primary,
              dialTextColor: colors.onSurface,
              entryModeIconColor: colors.primary,
            ),
          ),
          child: child!,
        ),
      );
      if (!mounted || selectedTime == null) return;

      final cubit = context.read<ProfileCubit>();
      final remindersWereEnabled = cubit.state.notificationsEnabled;
      final remindersAvailable = await cubit.setReminderTime(
        slot,
        selectedTime,
      );
      if (!mounted) return;
      if (remindersWereEnabled && !remindersAvailable) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Time saved, but notification permission is unavailable. '
              'Enable notifications in system settings.',
            ),
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save this reminder time.')),
      );
    } finally {
      if (mounted) {
        setState(() => _pendingSlots.remove(slot));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final profile = context.watch<ProfileCubit>().state;

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Meal reminder times',
            style: AppTheme.titleBold.copyWith(
              fontSize: 18,
              color: colors.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Choose when your planned meals should remind you.',
            style: AppTheme.small.copyWith(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          for (final slot in ProfileCubit.reminderSlots)
            _timeRow(slot, profile.reminderTimes[slot]!, colors),
        ],
      ),
    );
  }

  Widget _timeRow(String slot, TimeOfDay time, ColorScheme colors) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Expanded(
          child: Text(
            slot,
            style: AppTheme.label.copyWith(color: colors.onSurface),
          ),
        ),
        TextButton.icon(
          onPressed: _pendingSlots.contains(slot)
              ? null
              : () => _selectTime(slot, time),
          icon: const Icon(Icons.access_time),
          label: Text(time.format(context)),
        ),
      ],
    ),
  );
}
