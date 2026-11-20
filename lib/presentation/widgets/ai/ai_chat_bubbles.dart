import 'package:flutter/material.dart';

import '../../../core/utils/app_colors.dart';

/// Chat bubble that shows a message from the assistant.
class AssistantBubble extends StatelessWidget {
  final String title;
  final String message;

  const AssistantBubble({
    super.key,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.auto_awesome,
                color: AppColors.primaryGreen,
                size: 19,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textDark,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            message,
            style: const TextStyle(
              fontSize: 12.5,
              height: 1.5,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

/// Chat bubble that shows what the user typed.
class UserBubble extends StatelessWidget {
  final String text;
  final String time;

  const UserBubble({
    super.key,
    required this.text,
    required this.time,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.85,
        ),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: const BoxDecoration(
            color: Color(0xFFE9DEC9),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
              bottomLeft: Radius.circular(20),
              bottomRight: Radius.circular(6),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                time.isEmpty ? 'You' : 'You · $time',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                text,
                style: const TextStyle(
                  fontSize: 13.5,
                  height: 1.4,
                  color: AppColors.textDark,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Small notice shown above AI results.
class AiNoticeBanner extends StatelessWidget {
  final String message;

  const AiNoticeBanner({
    super.key,
    this.message =
        'AI estimate: values are approximate and not medical advice. '
            'Check ingredients for allergy safety.',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: AppColors.primaryGreen.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(
              Icons.info_outline,
              size: 16,
              color: AppColors.primaryGreen,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 11,
                height: 1.4,
                color: AppColors.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
