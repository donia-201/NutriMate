import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/dataresource/local_database_service.dart';
import '../../data/models/ai_recipe_model.dart';
import '../../data/models/healthy_alternative.dart';
import '../../data/models/meal_analysis_request.dart';
import '../../data/models/meal_analysis_result.dart';
import '../../data/models/meal_model.dart';
import '../cubit/ai_chat_cubit.dart';
import '../cubit/ai_chat_state.dart';
import '../widgets/ai/ai_chat_bubbles.dart';
import '../widgets/ai/alternative_recipe_card.dart';
import '../widgets/ai/analysis_loading_card.dart';
import '../widgets/ai/dietary_preferences_widget.dart';
import '../widgets/ai/meal_analysis_cards.dart';

enum AiAssistantMode {
  mealAnalysis,
  healthyAlternatives,
}

/// The screen the user is looking at. It is derived from the cubit state:
/// ask -> loading -> analysis -> alternatives.
enum _AiView {
  input,
  loading,
  analysis,
  alternatives,
}

class AiAssistantPage extends StatefulWidget {
  const AiAssistantPage({super.key});

  @override
  State<AiAssistantPage> createState() => _AiAssistantPageState();
}

class _AiAssistantPageState extends State<AiAssistantPage> {
  // Shortcut to the current theme colors (works in Light and Dark).
  ColorScheme get _c => Theme.of(context).colorScheme;

  final TextEditingController _mealController = TextEditingController();
  final TextEditingController _additionalRequestController =
  TextEditingController();

  AiAssistantMode _selectedMode = AiAssistantMode.mealAnalysis;
  Set<String> _selectedPreferences = {};

  // What the user sent, kept so the chat bubble stays on screen.
  MealAnalysisRequest? _submittedRequest;
  String _submittedTime = '';

  // Lets the user come back from the recipes to the analysis without a
  // new request.
  MealAnalysisResult? _lastAnalysis;
  bool _cameFromAnalysis = false;
  bool _showAnalysisAgain = false;

  Set<String> _savedIds = {};

  bool get _isMealAnalysis => _selectedMode == AiAssistantMode.mealAnalysis;

  @override
  void initState() {
    super.initState();
    _loadSavedIds();
  }

  @override
  void dispose() {
    _mealController.dispose();
    _additionalRequestController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // State handling
  // ---------------------------------------------------------------------------

  _AiView _resolveView(AiChatState state) {
    switch (state.status) {
      case AiChatStatus.loading:
        return _AiView.loading;

      case AiChatStatus.success:
        if (state.operation == AiChatOperation.healthyAlternatives) {
          return _showAnalysisAgain && _lastAnalysis != null
              ? _AiView.analysis
              : _AiView.alternatives;
        }

        if (state.operation == AiChatOperation.mealAnalysis &&
            state.analysisResult != null) {
          return _AiView.analysis;
        }

        return _AiView.input;

      case AiChatStatus.initial:
      case AiChatStatus.failure:
      // A failed "healthier recipes" request keeps the analysis on screen.
        return _cameFromAnalysis && _lastAnalysis != null
            ? _AiView.analysis
            : _AiView.input;
    }
  }

  void _onStateChanged(BuildContext context, AiChatState state) {
    if (state.status == AiChatStatus.success &&
        state.operation == AiChatOperation.mealAnalysis &&
        state.analysisResult != null) {
      setState(() => _lastAnalysis = state.analysisResult);
    }

    if (state.status == AiChatStatus.failure) {
      final request = _submittedRequest;

      if (_cameFromAnalysis && _lastAnalysis != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(state.errorMessage ?? 'Something went wrong.')),
        );
      } else if (request != null && _mealController.text.isEmpty) {
        // Give the text back so the user can retry or edit it.
        _mealController.text = request.mealDescription;
      }
    }
  }

  void _changeMode(AiAssistantMode mode) {
    if (_selectedMode == mode) return;

    context.read<AiChatCubit>().reset();

    setState(() {
      _selectedMode = mode;
      _submittedRequest = null;
      _lastAnalysis = null;
      _cameFromAnalysis = false;
      _showAnalysisAgain = false;
    });
  }

  void _resetToInput() {
    context.read<AiChatCubit>().reset();

    setState(() {
      _submittedRequest = null;
      _lastAnalysis = null;
      _cameFromAnalysis = false;
      _showAnalysisAgain = false;
    });
  }

  void _goBack(_AiView view) {
    switch (view) {
      case _AiView.input:
        Navigator.maybePop(context);
        return;

      case _AiView.loading:
        if (_cameFromAnalysis && _lastAnalysis != null) {
          // Cancel the recipes request and show the analysis again.
          context.read<AiChatCubit>().reset();
        } else {
          _resetToInput();
        }
        return;

      case _AiView.analysis:
        _resetToInput();
        return;

      case _AiView.alternatives:
        if (_cameFromAnalysis && _lastAnalysis != null) {
          setState(() => _showAnalysisAgain = true);
        } else {
          _resetToInput();
        }
        return;
    }
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

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

    FocusScope.of(context).unfocus();

    final request = MealAnalysisRequest(
      mealDescription: meal,
      dietaryPreferences: _selectedPreferences.toList(),
      additionalRequest:
      _isMealAnalysis ? null : _additionalRequestController.text.trim(),
    );

    setState(() {
      _submittedRequest = request;
      _submittedTime = TimeOfDay.fromDateTime(DateTime.now()).format(context);
      _lastAnalysis = null;
      _cameFromAnalysis = false;
      _showAnalysisAgain = false;
    });

    _mealController.clear();

    final cubit = context.read<AiChatCubit>();

    if (_isMealAnalysis) {
      cubit.analyzeMeal(request);
    } else {
      cubit.findHealthyAlternatives(request);
    }
  }

  void _showHealthierRecipes() {
    final cubit = context.read<AiChatCubit>();
    final current = cubit.state;

    // The recipes are already loaded, so just show them again.
    if (current.operation == AiChatOperation.healthyAlternatives &&
        current.status == AiChatStatus.success) {
      setState(() => _showAnalysisAgain = false);
      return;
    }

    final request = _submittedRequest;
    if (request == null) return;

    setState(() {
      _cameFromAnalysis = true;
      _showAnalysisAgain = false;
    });

    cubit.findHealthyAlternatives(
      MealAnalysisRequest(
        mealDescription: request.mealDescription,
        dietaryPreferences: request.dietaryPreferences,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Favorites
  // ---------------------------------------------------------------------------

  Future<void> _loadSavedIds() async {
    try {
      final favorites = await LocalDatabaseService.instance.getFavorites();
      if (!mounted) return;

      setState(() {
        _savedIds = favorites.map((meal) => meal.idMeal).toSet();
      });
    } catch (_) {
      // Saving still works; the hearts just start empty.
    }
  }

  MealModel _toMeal(AiRecipeModel recipe) {
    final instructions = recipe.description;

    return MealModel(
      idMeal: recipe.id,
      strMeal: recipe.name,
      strCategory: recipe.category,
      strArea: recipe.area,
      strMealThumb: recipe.imageUrl ?? '',
      strInstructions: instructions,
      detailsLoaded: instructions != null && instructions.isNotEmpty,
    );
  }

  Future<bool> _confirmRemove() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove from favorites?'),
        content: const Text('This recipe will be removed from your favorites.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Yes'),
          ),
        ],
      ),
    );

    return confirmed ?? false;
  }

  Future<void> _toggleSaved(AiRecipeModel recipe) async {
    final wasSaved = _savedIds.contains(recipe.id);

    if (wasSaved && !await _confirmRemove()) return;
    if (!mounted) return;

    setState(() {
      if (wasSaved) {
        _savedIds.remove(recipe.id);
      } else {
        _savedIds.add(recipe.id);
      }
    });

    try {
      await LocalDatabaseService.instance.setFavorite(
        _toMeal(recipe),
        !wasSaved,
      );
    } catch (_) {
      if (!mounted) return;

      setState(() {
        if (wasSaved) {
          _savedIds.add(recipe.id);
        } else {
          _savedIds.remove(recipe.id);
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update your favorites.')),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  String _titleFor(_AiView view, AiChatState state) {
    switch (view) {
      case _AiView.input:
        return 'Your food, understood';
      case _AiView.loading:
        return state.operation == AiChatOperation.healthyAlternatives
            ? 'Finding alternatives'
            : 'Analyzing your meal';
      case _AiView.analysis:
        return 'Your meal analysis';
      case _AiView.alternatives:
        return 'A better choice';
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AiChatCubit, AiChatState>(
      listenWhen: (previous, current) => previous.status != current.status,
      listener: _onStateChanged,
      builder: (context, state) {
        final view = _resolveView(state);

        return PopScope(
          canPop: view == _AiView.input,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _goBack(view);
          },
          child: Scaffold(
            // Background comes from the Theme (Light / Dark).
            appBar: _buildAppBar(view, state),
            body: SafeArea(
              top: false,
              child: _buildBody(view, state),
            ),
          ),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(_AiView view, AiChatState state) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: IconButton(
        icon: Icon(
          Icons.arrow_back_ios_new,
          size: 19,
          color: _c.onSurface,
        ),
        onPressed: () => _goBack(view),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _titleFor(view, state),
            style: TextStyle(
              color: _c.onSurface,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (view == _AiView.input)
            Text(
              'A little clarity with every bite',
              style: TextStyle(
                color: _c.onSurfaceVariant,
                fontSize: 11,
                fontWeight: FontWeight.w400,
              ),
            ),
        ],
      ),
      centerTitle: false,
    );
  }

  Widget _buildBody(_AiView view, AiChatState state) {
    switch (view) {
      case _AiView.input:
        return _buildInputView(state);
      case _AiView.loading:
        return _buildLoadingView(state);
      case _AiView.analysis:
        return _buildAnalysisView(state);
      case _AiView.alternatives:
        return _buildAlternativesView(state);
    }
  }

  // --- Ask ---------------------------------------------------------------

  Widget _buildInputView(AiChatState state) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildModeSelector(),
                const SizedBox(height: 20),
                AssistantBubble(
                  title: 'Hi there, what’s on your plate?',
                  message: _isMealAnalysis
                      ? 'Describe a meal and I’ll estimate its nutrition, '
                      'then suggest practical swaps.'
                      : 'Tell me a food you love. We’ll find a nourishing '
                      'alternative without losing the joy.',
                ),
                if (state.status == AiChatStatus.failure) ...[
                  const SizedBox(height: 14),
                  _buildErrorMessage(state.errorMessage),
                ],
                const SizedBox(height: 22),
                Text(
                  'Dietary preferences',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: _c.onSurface,
                  ),
                ),
                const SizedBox(height: 12),
                DietaryPreferencesWidget(
                  selectedPreferences: _selectedPreferences,
                  onChanged: (preferences) {
                    setState(() => _selectedPreferences = preferences);
                  },
                ),
                if (!_isMealAnalysis) ...[
                  const SizedBox(height: 22),
                  _buildAdditionalRequest(),
                ],
              ],
            ),
          ),
        ),
        _buildBottomPanel(
          children: [
            _buildComposer(),
            const SizedBox(height: 10),
            _buildPrimaryButton(
              label: _isMealAnalysis ? 'Analyze meal' : 'Find alternatives',
              onPressed: _submitRequest,
            ),
            const SizedBox(height: 8),
            Text(
              _isMealAnalysis
                  ? 'Estimates only. Check ingredients for allergy safety.'
                  : 'Suggestions consider your food and dietary preferences.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                color: _c.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildComposer() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: _c.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(22),
      ),
      child: TextField(
        controller: _mealController,
        minLines: 1,
        maxLines: 4,
        textCapitalization: TextCapitalization.sentences,
        style: TextStyle(color: _c.onSurface),
        decoration: InputDecoration(
          hintText: _isMealAnalysis
              ? 'Describe your meal...'
              : 'Tell me a food you love...',
          hintStyle: TextStyle(
            fontSize: 13.5,
            color: _c.onSurfaceVariant,
          ),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          fillColor: Colors.transparent,
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
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          decoration: BoxDecoration(
            color: selected ? _c.primary.withValues(alpha: 0.18) : _c.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: selected
                  ? _c.primary.withValues(alpha: 0.6)
                  : _c.outline.withValues(alpha: 0.4),
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _c.onSurface,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAdditionalRequest() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Anything specific? (optional)',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: _c.onSurface,
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _additionalRequestController,
          minLines: 2,
          maxLines: 3,
          style: TextStyle(color: _c.onSurface),
          decoration: InputDecoration(
            hintText: 'e.g. high protein, ready in 20 minutes...',
            filled: true,
            fillColor: _c.surface,
            hintStyle: TextStyle(
              color: _c.onSurfaceVariant,
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

  Widget _buildErrorMessage(String? message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _c.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        message ?? 'Something went wrong.',
        style: TextStyle(
          color: _c.error,
          fontSize: 13,
        ),
      ),
    );
  }

  // --- Loading -----------------------------------------------------------

  Widget _buildLoadingView(AiChatState state) {
    final isAlternatives =
        state.operation == AiChatOperation.healthyAlternatives;

    return Column(
      children: [
        Expanded(
          child: _buildScrollableChat(
            children: [
              const AiNoticeBanner(),
              const SizedBox(height: 16),
              _buildUserBubble(),
              const SizedBox(height: 16),
              AnalysisLoadingCard(
                message: isAlternatives
                    ? 'Searching for nourishing swaps...'
                    : 'Finding a little food wisdom...',
              ),
            ],
          ),
        ),
        _buildBottomPanel(
          children: [
            _buildPrimaryButton(
              label: 'Please wait...',
              onPressed: null,
              showSpinner: true,
            ),
          ],
        ),
      ],
    );
  }

  // --- Analysis ----------------------------------------------------------

  Widget _buildAnalysisView(AiChatState state) {
    final result = _showAnalysisAgain
        ? _lastAnalysis
        : (state.analysisResult ?? _lastAnalysis);

    if (result == null) return _buildInputView(state);

    return Column(
      children: [
        Expanded(
          child: _buildScrollableChat(
            children: [
              const AiNoticeBanner(),
              const SizedBox(height: 16),
              _buildUserBubble(),
              const SizedBox(height: 16),
              NutritionCard(nutrition: result.nutrition),
              const SizedBox(height: 14),
              HealthScoreCard(
                balanceScore: result.balanceScore,
                assessment: result.assessment,
              ),
              const SizedBox(height: 14),
              TipsCard(tips: result.tips),
              if (result.nutrition.disclaimer != null &&
                  result.nutrition.disclaimer!.trim().isNotEmpty) ...[
                const SizedBox(height: 14),
                Text(
                  result.nutrition.disclaimer!.trim(),
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.4,
                    color: _c.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
        _buildBottomPanel(
          children: [
            _buildPrimaryButton(
              label: 'View healthier recipes',
              onPressed: _showHealthierRecipes,
            ),
            TextButton(
              onPressed: _resetToInput,
              child: Text(
                'Analyze another meal',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: _c.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // --- Alternatives ------------------------------------------------------

  Widget _buildAlternativesView(AiChatState state) {
    final alternatives = state.alternatives;
    final count = alternatives.length;

    final summary = count == 0
        ? ''
        : '${_cameFromAnalysis ? 'Your meal analysis · ' : ''}'
        '$count healthier ${count == 1 ? 'recipe' : 'recipes'}';

    return _buildScrollableChat(
      children: [
        const AiNoticeBanner(
          message: 'Suggestions are ideas, not rules. Check ingredients '
              'against your dietary needs and allergies.',
        ),
        const SizedBox(height: 14),
        if (alternatives.isEmpty)
          _buildEmptyAlternatives()
        else ...[
          Text(
            summary,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _c.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          ...alternatives.map(_buildAlternativeCard),
        ],
        const SizedBox(height: 4),
        Center(
          child: TextButton(
            onPressed: _resetToInput,
            child: Text(
              'Start over',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: _c.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAlternativeCard(HealthyAlternative alternative) {
    return AlternativeRecipeCard(
      alternative: alternative,
      isSaved: _savedIds.contains(alternative.recipe.id),
      onToggleSaved: () => _toggleSaved(alternative.recipe),
      onViewRecipe: () => showRecipeDetailsSheet(context, alternative),
    );
  }

  Widget _buildEmptyAlternatives() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _c.surface,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Text(
        'No verified recipe alternatives were found. '
            'Try adjusting your meal description or dietary preferences.',
        style: TextStyle(
          fontSize: 13,
          height: 1.5,
          color: _c.onSurfaceVariant,
        ),
      ),
    );
  }

  // --- Shared pieces -----------------------------------------------------

  Widget _buildUserBubble() {
    return UserBubble(
      text: _submittedRequest?.mealDescription ?? '',
      time: _submittedTime,
    );
  }

  Widget _buildScrollableChat({required List<Widget> children}) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _buildBottomPanel({required List<Widget> children}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(
          top: BorderSide(
            color: _c.outline.withValues(alpha: 0.4),
            width: 0.8,
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: children,
      ),
    );
  }

  Widget _buildPrimaryButton({
    required String label,
    required VoidCallback? onPressed,
    bool showSpinner = false,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: _c.primary,
          foregroundColor: _c.onPrimary,
          disabledBackgroundColor: _c.primary.withValues(alpha: 0.5),
          disabledForegroundColor: _c.onPrimary,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (showSpinner) ...[
              SizedBox(
                height: 16,
                width: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: _c.onPrimary,
                ),
              ),
              const SizedBox(width: 10),
            ],
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}