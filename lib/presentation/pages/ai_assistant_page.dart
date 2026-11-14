import 'package:flutter/material.dart';

import '../../core/utils/app_colors.dart';
import '../widgets/ai/dietary_preferences_widget.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/models/meal_analysis_result.dart';
import '../../data/models/meal_analysis_request.dart';
import '../cubit/ai_chat_cubit.dart';
import '../cubit/ai_chat_state.dart';

enum AiAssistantMode {
  mealAnalysis,
  healthyAlternatives,
}

class AiAssistantPage extends StatefulWidget {
  const AiAssistantPage({super.key});

  @override
  State<AiAssistantPage> createState() =>
      _AiAssistantPageState();
}

class _AiAssistantPageState extends State<AiAssistantPage> {
  final TextEditingController _mealController =
      TextEditingController();

  final TextEditingController _additionalRequestController =
      TextEditingController();

  AiAssistantMode _selectedMode =
      AiAssistantMode.mealAnalysis;

  Set<String> _selectedPreferences = {};

  bool get _isMealAnalysis =>
      _selectedMode == AiAssistantMode.mealAnalysis;

  @override
  void dispose() {
    _mealController.dispose();
    _additionalRequestController.dispose();
    super.dispose();
  }

  void _changeMode(AiAssistantMode mode) {
    setState(() {
      _selectedMode = mode;
    });
  }

  void _submitRequest() {
  final meal = _mealController.text.trim();

  if (meal.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Please enter your meal or food first.'),
      ),
    );
    return;
  }

  final request = MealAnalysisRequest(
    mealDescription: meal,
    dietaryPreferences: _selectedPreferences.toList(),
    additionalRequest: _isMealAnalysis
        ? null
        : _additionalRequestController.text.trim(),
  );

  final cubit = context.read<AiChatCubit>();

  if (_isMealAnalysis) {
    cubit.analyzeMeal(request);
  } else {
    cubit.findHealthyAlternatives(request);
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            size: 19,
            color: AppColors.textDark,
          ),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: const Text(
          'Your food, understood',
          style: TextStyle(
            color: AppColors.textDark,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: false,
      ),
      body: SafeArea(
  top: false,
  child: BlocBuilder<AiChatCubit, AiChatState>(
    builder: (context, state) {
      return SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildModeSelector(),
            const SizedBox(height: 22),
            _buildWelcomeMessage(),
            const SizedBox(height: 18),
            _buildMealInput(),
            const SizedBox(height: 22),

            const Text(
              'Dietary preferences',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 12),

            DietaryPreferencesWidget(
              selectedPreferences: _selectedPreferences,
              onChanged: (preferences) {
                setState(() {
                  _selectedPreferences = preferences;
                });
              },
            ),

            const SizedBox(height: 22),

            if (!_isMealAnalysis) ...[
              _buildAdditionalRequest(),
              const SizedBox(height: 18),
            ],

            _buildSubmitButton(state),

            const SizedBox(height: 18),

            if (state.isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(
                    color: AppColors.primaryGreen,
                  ),
                ),
              ),

            if (state.status == AiChatStatus.failure)
              _buildErrorMessage(state.errorMessage),

            if (state.status == AiChatStatus.success &&
                state.operation == AiChatOperation.mealAnalysis &&
                state.analysisResult != null)
              _buildAnalysisResult(state.analysisResult!),

            if (state.status == AiChatStatus.success &&
                state.operation == AiChatOperation.healthyAlternatives)
              _buildAlternativesResult(state),

            const SizedBox(height: 12),

            Text(
              _isMealAnalysis
                  ? 'Nutrition results depend on ingredient matching and quantity accuracy.'
                  : 'Suggestions will consider your food choices and dietary preferences.',
              style: const TextStyle(
                fontSize: 11,
                height: 1.5,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      );
    },
  ),
),


    );
  }

  Widget _buildModeSelector() {
    return Row(
      children: [
        _modeButton(
          title: 'Meal Analysis',
          mode: AiAssistantMode.mealAnalysis,
        ),
        const SizedBox(width: 10),
        _modeButton(
          title: 'Healthy Alternatives',
          mode: AiAssistantMode.healthyAlternatives,
        ),
      ],
    );
  }

  Widget _modeButton({
    required String title,
    required AiAssistantMode mode,
  }) {
    final selected = _selectedMode == mode;

    return Expanded(
      child: GestureDetector(
        onTap: () => _changeMode(mode),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 12,
          ),
          decoration: BoxDecoration(
            color: selected
                ? const Color(0xFFE9DEC9)
                : AppColors.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: selected
                  ? AppColors.accentHeart.withValues(alpha: 0.5)
                  : AppColors.divider,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textDark,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeMessage() {
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
          const Row(
            children: [
              Icon(
                Icons.auto_awesome,
                color: AppColors.primaryGreen,
                size: 19,
              ),
              SizedBox(width: 8),
              Text(
                'Hi! Welcome, what’s on your plate?',
                style: TextStyle(
                  color: AppColors.textDark,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _isMealAnalysis
                ? 'Describe a meal and I’ll estimate its nutrition, then suggest personalized insights.'
                : 'Tell me a food you love. We’ll find a nourishing alternative without losing the joy.',
            style: const TextStyle(
              fontSize: 12,
              height: 1.5,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMealInput() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFFEFE2CD),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _isMealAnalysis ? 'Your meal' : 'Food you love',
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
            TextField(
            controller: _mealController,
            minLines: 2,
            maxLines: 4,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: _isMealAnalysis
                  ? 'e.g. 2 eggs, whole wheat toast and a glass of orange juice'
                  : 'e.g. Chocolate cookies',
              hintStyle: const TextStyle(
                fontSize: 13,
                color: AppColors.textHint,
              ),
              border: InputBorder.none,
              isDense: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdditionalRequest() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Additional request (optional)',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.textDark,
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _additionalRequestController,
          minLines: 2,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'One idea, one preference...',
            filled: true,
            fillColor: AppColors.surface,
            hintStyle: const TextStyle(
              color: AppColors.textHint,
              fontSize: 12,
            ),
            contentPadding: const EdgeInsets.all(15),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSubmitButton(AiChatState state) {
  return SizedBox(
    width: double.infinity,
    child: ElevatedButton(
      onPressed: state.isLoading ? null : _submitRequest,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: AppColors.buttonText,
        disabledBackgroundColor:
            AppColors.primaryGreen.withValues(alpha: 0.5),
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(25),
        ),
      ),
      child: state.isLoading
          ? const SizedBox(
              height: 18,
              width: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : Text(
              _isMealAnalysis
                  ? 'Analyze meal'
                  : 'Find alternatives',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
    ),
  );
}

 Widget _buildErrorMessage(String? message) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.error.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Text(
      message ?? 'Something went wrong.',
      style: const TextStyle(
        color: AppColors.error,
        fontSize: 13,
      ),
    ),
  );
}

Widget _buildAnalysisResult(MealAnalysisResult result) {
  final nutrition = result.nutrition;

  Widget nutrient(String label, double? value, String unit) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value == null
                ? '--'
                : '${value.toStringAsFixed(1)} $unit',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Meal Analysis',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppColors.textDark,
          ),
        ),
        const SizedBox(height: 16),

        if (nutrition.calories != null ||
            nutrition.protein != null ||
            nutrition.carbohydrates != null ||
            nutrition.fat != null) ...[
          Wrap(
            spacing: 8,
            runSpacing: 16,
            children: [
              nutrient('Calories', nutrition.calories, 'kcal'),
              nutrient('Protein', nutrition.protein, 'g'),
              nutrient('Carbs', nutrition.carbohydrates, 'g'),
              nutrient('Fat', nutrition.fat, 'g'),
            ],
          ),
        ] else
          const Text(
            'Nutrition values are not available yet.',
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 13,
            ),
          ),

        const SizedBox(height: 16),

        if (result.balanceScore != null) ...[
          Text(
            'Balance Score: ${result.balanceScore!.toStringAsFixed(1)}',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.primaryGreen,
            ),
          ),
          const SizedBox(height: 12),
        ],

        if (result.assessment.isNotEmpty) ...[
          const Text(
            'Assessment',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            result.assessment,
            style: const TextStyle(
              fontSize: 13,
              height: 1.5,
              color: AppColors.textMuted,
            ),
          ),
        ],

        if (result.tips.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Text(
            'Tips',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 8),
          ...result.tips.map(
            (tip) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.check_circle_outline,
                    size: 17,
                    color: AppColors.primaryGreen,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      tip,
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],

        if (nutrition.disclaimer != null) ...[
          const SizedBox(height: 12),
          Text(
            nutrition.disclaimer!,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ],
    ),
  );
}

Widget _buildAlternativesResult(AiChatState state) {
  if (state.alternatives.isEmpty) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Text(
        'No alternatives are available yet. '
        'Connect the AI service to receive recipe suggestions.',
        style: TextStyle(
          fontSize: 13,
          height: 1.5,
          color: AppColors.textMuted,
        ),
      ),
    );
  }

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Healthy Alternatives',
        style: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: AppColors.textDark,
        ),
      ),
      const SizedBox(height: 12),
      ...state.alternatives.map((alternative) {
        final recipe = alternative.recipe;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (recipe.imageUrl != null &&
                  recipe.imageUrl!.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    recipe.imageUrl!,
                    width: double.infinity,
                    height: 150,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) =>
                        const SizedBox.shrink(),
                  ),
                ),
              const SizedBox(height: 10),
              Text(
                recipe.name,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                alternative.reason,
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.5,
                  color: AppColors.textMuted,
                ),
              ),
              if (alternative.improvementSummary != null) ...[
                const SizedBox(height: 6),
                Text(
                  alternative.improvementSummary!,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.primaryGreen,
                  ),
                ),
              ],
            ],
          ),
        );
      }),
    ],
  );
}
}