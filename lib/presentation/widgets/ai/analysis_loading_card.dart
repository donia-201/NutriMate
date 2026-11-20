import 'package:flutter/material.dart';

import '../../../core/utils/app_colors.dart';

/// Assistant card with pulsing placeholder blocks, shown while the AI works.
class AnalysisLoadingCard extends StatefulWidget {
  final String message;

  const AnalysisLoadingCard({
    super.key,
    required this.message,
  });

  @override
  State<AnalysisLoadingCard> createState() => _AnalysisLoadingCardState();
}

class _AnalysisLoadingCardState extends State<AnalysisLoadingCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _block(double height) {
    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFEFE2CD),
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }

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
              const SizedBox(
                height: 16,
                width: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primaryGreen,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.message,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              return Opacity(
                opacity: 0.45 + 0.4 * _controller.value,
                child: Column(
                  children: [
                    _block(86),
                    const SizedBox(height: 12),
                    _block(56),
                    const SizedBox(height: 12),
                    _block(56),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
