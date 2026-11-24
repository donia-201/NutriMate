import 'package:flutter/material.dart';

import '../../../data/models/nutrition_summary.dart';

BoxDecoration _cardDecoration(BuildContext context) {
  return BoxDecoration(
    color: Theme.of(context).colorScheme.surface,
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

  Widget _stat(BuildContext context, String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _legendItem(BuildContext context, Color color, String label) {
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
          style: TextStyle(
            fontSize: 11,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _macroSplit(BuildContext context) {
    final protein = (nutrition.protein ?? 0) * 4;
    final carbs = (nutrition.carbohydrates ?? 0) * 4;
    final fat = (nutrition.fat ?? 0) * 9;
    final total = protein + carbs + fat;

    if (total <= 0) return const SizedBox.shrink();

    final segments = <(double, Color, String)>[
      (protein, Theme.of(context).colorScheme.primary, 'Protein'),
      (carbs, Theme.of(context).colorScheme.tertiary, 'Carbs'),
      (fat, Theme.of(context).colorScheme.secondary, 'Fat'),
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
              return _legendItem(
                context,
                segment.$2,
                '${segment.$3} $percent%',
              );
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
      decoration: _cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Estimated nutrition',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
              if (nutrition.isEstimated)
                Text(
                  'Estimated',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          if (_hasNutrition) ...[
            Row(
              children: [
                _stat(context, _number(nutrition.calories), 'kcal'),
                const SizedBox(width: 8),
                _stat(
                  context,
                  _number(nutrition.protein, unit: 'g'),
                  'Protein',
                ),
                const SizedBox(width: 8),
                _stat(
                  context,
                  _number(nutrition.carbohydrates, unit: 'g'),
                  'Carbs',
                ),
                const SizedBox(width: 8),
                _stat(context, _number(nutrition.fat, unit: 'g'), 'Fat'),
              ],
            ),
            _macroSplit(context),
          ] else
            Text(
              'Nutrition values are not available for this meal.',
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          if (notes.isNotEmpty) ...[
            const SizedBox(height: 12),
            ...notes.map(
              (note) => Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(
                  note,
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.4,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
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
    return "Let's rebalance";
  }

  static Color _color(BuildContext context, int score) {
    final colors = Theme.of(context).colorScheme;
    if (score >= 70) return colors.primary;
    if (score >= 40) return colors.tertiary;
    return colors.error;
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
      decoration: _cardDecoration(context),
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
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    color: _color(context, score),
                  ),
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$score',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        Text(
                          '/100',
                          style: TextStyle(
                            fontSize: 10,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
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
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                if (hasScore) ...[
                  const SizedBox(height: 3),
                  Text(
                    'Health score',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
                if (hasAssessment) ...[
                  const SizedBox(height: 8),
                  Text(
                    assessment.trim(),
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.5,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
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
      decoration: _cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Make your meal work harder',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          ...tips.map(
            (tip) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Icon(
                      Icons.check_circle_outline,
                      size: 17,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      tip,
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.45,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
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
