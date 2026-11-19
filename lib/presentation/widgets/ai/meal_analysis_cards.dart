import 'package:flutter/material.dart';

import '../../../core/utils/app_colors.dart';
import '../../../data/models/nutrition_summary.dart';

const Color _tileColor = Color(0xFFEFE2CD);
const Color _carbsColor = Color(0xFFB9D3C2);

BoxDecoration _cardDecoration() {
  return BoxDecoration(
    color: AppColors.surface,
    borderRadius: BorderRadius.circular(22),
  );
}

/// Calories, macros and the macro split bar.
class NutritionCard extends StatelessWidget {
  final NutritionSummary nutrition;

  const NutritionCard({super.key, required this.nutrition});

  static String _number(double? value, {String unit = ''}) {
    if (value == null) return '--';
    return '${value.round()}$unit';
  }

  bool get _hasNutrition =>
      nutrition.calories != null ||
      nutrition.protein != null ||
      nutrition.carbohydrates != null ||
      nutrition.fat != null;

  Widget _stat(String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: _tileColor.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _legendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
        ),
      ],
    );
  }

  Widget _macroSplit() {
    final protein = (nutrition.protein ?? 0) * 4;
    final carbs = (nutrition.carbohydrates ?? 0) * 4;
    final fat = (nutrition.fat ?? 0) * 9;
    final total = protein + carbs + fat;

    if (total <= 0) return const SizedBox.shrink();

    final segments = <(double, Color, String)>[
      (protein, AppColors.primaryGreen, 'Protein'),
      (carbs, _carbsColor, 'Carbs'),
      (fat, AppColors.accentHeart, 'Fat'),
    ].where((segment) => segment.$1 > 0).toList();

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 8,
              child: Row(
                children: segments.map((segment) {
                  final flex = (segment.$1 / total * 1000).round();
                  return Expanded(
                    flex: flex < 1 ? 1 : flex,
                    child: ColoredBox(color: segment.$2),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 14,
            runSpacing: 6,
            children: segments.map((segment) {
              final percent = (segment.$1 / total * 100).round();
              return _legendItem(segment.$2, '${segment.$3} $percent%');
            }).toList(),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final notes = <String>[
      if (nutrition.fiber != null) 'Fiber ${_number(nutrition.fiber)} g',
      if (nutrition.unresolvedIngredients.isNotEmpty)
        'Could not match: ${nutrition.unresolvedIngredients.join(', ')}',
      if (nutrition.missingNutrients.isNotEmpty)
        'Unavailable nutrients: ${nutrition.missingNutrients.join(', ')}',
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Estimated nutrition',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
              ),
              if (nutrition.isEstimated)
                const Text(
                  'Estimated',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryGreen,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          if (_hasNutrition) ...[
            Row(
              children: [
                _stat(_number(nutrition.calories), 'kcal'),
                const SizedBox(width: 8),
                _stat(_number(nutrition.protein, unit: 'g'), 'Protein'),
                const SizedBox(width: 8),
                _stat(_number(nutrition.carbohydrates, unit: 'g'), 'Carbs'),
                const SizedBox(width: 8),
                _stat(_number(nutrition.fat, unit: 'g'), 'Fat'),
              ],
            ),
            _macroSplit(),
          ] else
            const Text(
              'Nutrition values are not available for this meal.',
              style: TextStyle(fontSize: 13, color: AppColors.textMuted),
            ),
          if (notes.isNotEmpty) ...[
            const SizedBox(height: 12),
            ...notes.map(
              (note) => Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(
                  note,
                  style: const TextStyle(
                    fontSize: 11,
                    height: 1.4,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Health score ring (0-100) with a short assessment.
/// The API sends the balance score from 0 to 10.
class HealthScoreCard extends StatelessWidget {
  final double? balanceScore;
  final String assessment;

  const HealthScoreCard({
    super.key,
    required this.balanceScore,
    required this.assessment,
  });

  static String _headline(int score) {
    if (score >= 80) return 'A great choice';
    if (score >= 60) return 'A balanced start';
    if (score >= 40) return 'Room to improve';
    return 'Let’s rebalance';
  }

  static Color _color(int score) {
    if (score >= 70) return AppColors.primaryGreen;
    if (score >= 40) return AppColors.warning;
    return AppColors.error;
  }

  @override
  Widget build(BuildContext context) {
    final hasScore = balanceScore != null;
    final score = hasScore ? (balanceScore!.clamp(0.0, 10.0) * 10).round() : 0;
    final hasAssessment = assessment.trim().isNotEmpty;

    if (!hasScore && !hasAssessment) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasScore) ...[
            SizedBox(
              width: 76,
              height: 76,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CircularProgressIndicator(
                    value: score / 100,
                    strokeWidth: 7,
                    backgroundColor: _tileColor,
                    color: _color(score),
                  ),
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$score',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textDark,
                          ),
                        ),
                        const Text(
                          '/100',
                          style: TextStyle(
                            fontSize: 10,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasScore ? _headline(score) : 'Assessment',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
                if (hasScore) ...[
                  const SizedBox(height: 3),
                  const Text(
                    'Health score',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryGreen,
                    ),
                  ),
                ],
                if (hasAssessment) ...[
                  const SizedBox(height: 8),
                  Text(
                    assessment.trim(),
                    style: const TextStyle(
                      fontSize: 12.5,
                      height: 1.5,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Practical tips returned by the AI.
class TipsCard extends StatelessWidget {
  final List<String> tips;

  const TipsCard({super.key, required this.tips});

  @override
  Widget build(BuildContext context) {
    if (tips.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Make your meal work harder',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 12),
          ...tips.map(
            (tip) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 1),
                    child: Icon(
                      Icons.check_circle_outline,
                      size: 17,
                      color: AppColors.primaryGreen,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      tip,
                      style: const TextStyle(
                        fontSize: 12.5,
                        height: 1.45,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
