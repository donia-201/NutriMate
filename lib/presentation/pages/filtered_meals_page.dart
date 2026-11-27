import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/app_theme.dart';
import '../../data/models/meal_model.dart';
import '../cubit/meal_log_session.dart';
import '../cubit/search_cubit.dart';
import '../cubit/search_state.dart';
import 'meal_details_page.dart';

class FilteredMealsPage extends StatefulWidget {
  final SearchCubit cubit;
  final String title;
  final MealLogSession? logSession;

  const FilteredMealsPage({
    super.key,
    required this.cubit,
    required this.title,
    this.logSession,
  });

  @override
  State<FilteredMealsPage> createState() => _FilteredMealsPageState();
}

class _FilteredMealsPageState extends State<FilteredMealsPage> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  String _filter = '';

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  MealLogSession? _resolveSession() => widget.logSession;

  Future<void> _openMealDetails(MealModel meal) async {
    final session = _resolveSession();
    final result = await Navigator.push<Object?>(
      context,
      MaterialPageRoute<Object?>(
        builder: (_) => MealDetailsPage(
          meal: meal,
          logSession: session,
        ),
      ),
    );
    if (!mounted) return;
    if (result is StagedMealEntry) {
      session?.stageMeal(
        result.meal,
        nutrition: result.nutrition,
        eatenAt: result.eatenAt,
      );
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop(result);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: widget.cubit,
      child: BlocBuilder<SearchCubit, SearchState>(
        builder: (context, state) {
          final filtered = state.meals.where((meal) {
            final query = _filter.trim().toLowerCase();
            if (query.isEmpty) return true;
            return meal.strMeal.toLowerCase().contains(query) ||
                (meal.strCategory?.toLowerCase().contains(query) ?? false) ||
                (meal.strArea?.toLowerCase().contains(query) ?? false);
          }).toList()..sort((a, b) => a.strMeal.compareTo(b.strMeal));

          return Scaffold(
            appBar: AppBar(
              title: Text(widget.title),
              centerTitle: true,
              backgroundColor: Colors.transparent,
            ),
            body: SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                    child: TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      onChanged: (value) {
                        if (!mounted) return;
                        setState(() => _filter = value);
                      },
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText: 'Filter meals in this selection',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _filter.isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'Clear filter',
                                onPressed: () {
                                  _controller.clear();
                                  setState(() => _filter = '');
                                },
                                icon: const Icon(Icons.clear),
                              ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: state.isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : state.errorMessage != null
                        ? _message(
                            state.errorMessage!,
                            () => widget.cubit.retry(),
                          )
                        : filtered.isEmpty
                        ? _message(
                            _filter.trim().isEmpty
                                ? 'No meals found for ${widget.title}.'
                                : 'No meals matched your filter.',
                            null,
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                            itemCount: filtered.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 12),
                            itemBuilder: (context, index) =>
                                _mealTile(context, filtered[index]),
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _message(String message, VoidCallback? onRetry) => Center(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppTheme.body.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 12),
            TextButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ],
      ),
    ),
  );

  Widget _mealTile(BuildContext context, MealModel meal) => InkWell(
    borderRadius: BorderRadius.circular(AppTheme.cardRadius),
    onTap: () => _openMealDetails(meal),
    child: Card(
      child: Row(
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.horizontal(
              left: Radius.circular(AppTheme.cardRadius),
            ),
            child: Image.network(
              meal.strMealThumb,
              width: 110,
              height: 100,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const SizedBox(
                width: 110,
                height: 100,
                child: Icon(Icons.restaurant),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    meal.strMeal,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.label,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${meal.strCategory ?? 'Meal'} - ${meal.strArea ?? 'International'}',
                    style: AppTheme.small.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(12),
            child: Icon(Icons.chevron_right),
          ),
        ],
      ),
    ),
  );
}