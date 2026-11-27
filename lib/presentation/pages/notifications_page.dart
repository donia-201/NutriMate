import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../core/app_theme.dart';
import '../../core/app_widgets.dart';
import '../cubit/notifications_cubit.dart';
import '../cubit/notifications_state.dart';

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: Colors.transparent,
        actions: [
          TextButton(
            onPressed: () => context.read<NotificationsCubit>().markAllRead(),
            child: const Text('Mark all read'),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: BlocBuilder<NotificationsCubit, NotificationsState>(
          builder: (context, state) {
            if (state.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (state.errorMessage != null) {
              return Center(
                child: AppCard(
                  padding: const EdgeInsets.all(20),
                  child: Text(state.errorMessage!, textAlign: TextAlign.center),
                ),
              );
            }
            if (state.notifications.isEmpty) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.notifications_off_outlined,
                      size: 48,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No meal notifications yet',
                      style: AppTheme.label.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              );
            }
            return RefreshIndicator(
              onRefresh: () => context.read<NotificationsCubit>().load(),
              child: ListView.separated(
                padding: const EdgeInsets.all(20),
                itemCount: state.notifications.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final notification = state.notifications[index];
                  return AppCard(
                    padding: EdgeInsets.zero,
                    child: Material(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(AppTheme.cardRadius),
                      child: ListTile(
                        tileColor: Theme.of(context).colorScheme.surface,
                        onTap: notification.isRead
                            ? null
                            : () => context.read<NotificationsCubit>().markRead(
                                notification,
                              ),
                        leading: CircleAvatar(
                          backgroundColor: notification.isRead
                              ? Theme.of(
                                  context,
                                ).colorScheme.surfaceContainerHighest
                              : Theme.of(
                                  context,
                                ).colorScheme.primary.withValues(alpha: 0.18),
                          child: Icon(
                            notification.isRead
                                ? Icons.notifications_none
                                : Icons.notifications_active,
                            color: notification.isRead
                                ? Theme.of(context).colorScheme.onSurfaceVariant
                                : Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        title: Text(notification.title),
                        subtitle: Text(
                          '${notification.body}\n${DateFormat('EEE, MMM d - hh:mm a').format(notification.triggeredAt)}',
                        ),
                        trailing: notification.isRead
                            ? null
                            : Icon(
                                Icons.circle,
                                size: 10,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}