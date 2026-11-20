import 'package:flutter/material.dart';

import '../../../core/utils/app_colors.dart';
import '../../../data/models/healthy_alternative.dart';

String _recipeMeta(HealthyAlternative alternative) {
  final recipe = alternative.recipe;

  return [recipe.category, recipe.area]
      .whereType<String>()
      .map((value) => value.trim())
      .where((value) => value.isNotEmpty)
      .join(' · ');
}

Widget _recipeImage(String? url, {required double height}) {
  Widget placeholder() {
    return Container(
      height: height,
      width: double.infinity,
      color: const Color(0xFFEFE2CD),
      child: const Icon(
        Icons.restaurant_outlined,
        color: AppColors.textHint,
        size: 34,
      ),
    );
  }

  if (url == null || url.isEmpty) return placeholder();

  return Image.network(
    url,
    height: height,
    width: double.infinity,
    fit: BoxFit.cover,
    errorBuilder: (_, _, _) => placeholder(),
  );
}

/// One healthier recipe suggestion with save and view actions.
class AlternativeRecipeCard extends StatelessWidget {
  final HealthyAlternative alternative;
  final bool isSaved;
  final VoidCallback onToggleSaved;
  final VoidCallback onViewRecipe;

  const AlternativeRecipeCard({
    super.key,
    required this.alternative,
    required this.isSaved,
    required this.onToggleSaved,
    required this.onViewRecipe,
  });

  @override
  Widget build(BuildContext context) {
    final recipe = alternative.recipe;
    final meta = _recipeMeta(alternative);
    final summary = alternative.improvementSummary?.trim() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              _recipeImage(recipe.imageUrl, height: 150),
              Positioned(
                top: 10,
                right: 10,
                child: GestureDetector(
                  onTap: onToggleSaved,
                  child: CircleAvatar(
                    radius: 17,
                    backgroundColor: Colors.white.withValues(alpha: 0.92),
                    child: Icon(
                      isSaved ? Icons.favorite : Icons.favorite_border,
                      size: 19,
                      color: AppColors.accentHeart,
                    ),
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  recipe.name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
                if (meta.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    meta,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
                if (alternative.reason.trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    alternative.reason.trim(),
                    style: const TextStyle(
                      fontSize: 12.5,
                      height: 1.45,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
                if (summary.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primaryGreen.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      summary,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: onViewRecipe,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryGreen,
                          foregroundColor: AppColors.buttonText,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(22),
                          ),
                        ),
                        child: const Text(
                          'View Recipe',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: onToggleSaved,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textDark,
                          side: const BorderSide(color: AppColors.primaryGreen),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(22),
                          ),
                        ),
                        child: Text(
                          isSaved ? 'Saved' : 'Save',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Bottom sheet with the full recipe (image, reason and instructions).
Future<void> showRecipeDetailsSheet(
  BuildContext context,
  HealthyAlternative alternative,
) {
  final recipe = alternative.recipe;
  final meta = _recipeMeta(alternative);
  final steps = (recipe.description ?? '')
      .split(RegExp(r'\r?\n'))
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList();

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.background,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
    ),
    builder: (sheetContext) {
      return DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, scrollController) {
          return ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.dotInactive,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: _recipeImage(recipe.imageUrl, height: 190),
              ),
              const SizedBox(height: 16),
              Text(
                recipe.name,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDark,
                ),
              ),
              if (meta.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  meta,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
              if (alternative.reason.trim().isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    alternative.reason.trim(),
                    style: const TextStyle(
                      fontSize: 12.5,
                      height: 1.5,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
              ],
              if (steps.isNotEmpty) ...[
                const SizedBox(height: 20),
                const Text(
                  'Instructions',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 10),
                ...steps.map(
                  (step) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(
                      step,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.55,
                        color: AppColors.textDark,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      );
    },
  );
}
