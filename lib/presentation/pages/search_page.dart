import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/app_theme.dart';
import '../../data/models/meal_model.dart';
import '../cubit/search_cubit.dart';
import '../cubit/home_cubit.dart';
import '../cubit/search_state.dart';
import 'meal_details_page.dart';

class SearchPage extends StatelessWidget {
  final SearchCubit? cubit;
  final bool embedded;

  const SearchPage({super.key, this.cubit, this.embedded = false});

  @override
  Widget build(BuildContext context) {
    final view = _SearchView(embedded: embedded);
    return cubit == null
        ? BlocProvider(create: (_) => SearchCubit(), child: view)
        : BlocProvider.value(value: cubit!, child: view);
  }
}

class _SearchView extends StatefulWidget {
  final bool embedded;
  const _SearchView({required this.embedded});

  @override
  State<_SearchView> createState() => _SearchViewState();
}

class _SearchViewState extends State<_SearchView> {
  final _controller = TextEditingController();
  final _searchFocus = FocusNode();
  bool _sortAscending = true;

  static const _categories = <List<String>>[
    ['Beef', 'https://www.themealdb.com/images/category/beef.png'],
    ['Chicken', 'https://www.themealdb.com/images/category/chicken.png'],
    ['Dessert', 'https://www.themealdb.com/images/category/dessert.png'],
    ['Seafood', 'https://www.themealdb.com/images/category/seafood.png'],
    ['Vegetarian', 'https://www.themealdb.com/images/category/vegetarian.png'],
    ['Pasta', 'https://www.themealdb.com/images/category/pasta.png'],
    ['Breakfast', 'https://www.themealdb.com/images/category/breakfast.png'],
    ['Side dishes', 'https://www.themealdb.com/images/category/side.png'],
  ];
  static const _countries = [
    ('Greece', 'ðŸ‡¬ðŸ‡·', 'Greek'),
    ('Italy', 'ðŸ‡®ðŸ‡¹', 'Italian'),
    ('Mexico', 'ðŸ‡²ðŸ‡½', 'Mexican'),
    ('India', 'ðŸ‡®ðŸ‡³', 'Indian'),
    ('Japan', 'ðŸ‡¯ðŸ‡µ', 'Japanese'),
    ('Egypt', 'ðŸ‡ªðŸ‡¬', 'Egyptian'),
    ('France', 'ðŸ‡«ðŸ‡·', 'French'),
    ('Thailand', 'ðŸ‡¹ðŸ‡­', 'Thai'),
    ('USA', 'ðŸ‡ºðŸ‡¸', 'American'),
  ];
  static const _ingredients = <List<String>>[
    ['Avocado', 'avocado'],
    ['Chicken', 'chicken'],
    ['Eggs', 'egg'],
    ['Tomato', 'tomato'],
    ['Salmon', 'salmon'],
    ['Spinach', 'spinach'],
    ['Rice', 'rice'],
    ['Berries', 'berries'],
    ['Oats', 'oats'],
  ];

  @override
  void dispose() {
    _searchFocus.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => BlocListener<SearchCubit, SearchState>(
    listenWhen: (previous, current) =>
        previous.query != current.query ||
        previous.mode != current.mode ||
        previous.selectedValue != current.selectedValue,
    listener: (context, state) {
      final value = state.selectedValue ?? state.query;
      if (value.isNotEmpty && _controller.text != value) {
        _controller.text = value;
        _controller.selection = TextSelection.collapsed(offset: value.length);
      } else if (value.isEmpty &&
          _controller.text.isNotEmpty &&
          !state.hasSearched) {
        _controller.clear();
      }
    },
    child: BlocBuilder<SearchCubit, SearchState>(
      builder: (context, state) {
        final cubit = context.read<SearchCubit>();
        final content = SafeArea(
          bottom: false,
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                sliver: SliverToBoxAdapter(child: _header(context)),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverToBoxAdapter(child: _searchBar(cubit)),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                sliver: SliverToBoxAdapter(child: _modeSelector(state, cubit)),
              ),
              if (state.isLoading)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (state.errorMessage != null)
                SliverToBoxAdapter(
                  child: _messageCard(state.errorMessage!, cubit.retry),
                )
              else if (state.hasSearched && state.meals.isEmpty)
                SliverToBoxAdapter(
                  child: _messageCard(
                    'No recipes matched your search.',
                    cubit.retry,
                  ),
                )
              else if (state.hasSearched)
                _mealResults(state.meals)
              else
                _discoveryGrid(state.mode, cubit),
              if (!state.isLoading)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  sliver: SliverToBoxAdapter(
                    child: Text(
                      state.mode == SearchMode.ingredient
                          ? 'Choose an ingredient to see recipe ideas.'
                          : state.mode == SearchMode.search
                          ? 'Type a meal name to search.'
                          : 'Select a collection to browse its meals.',
                      style: AppTheme.subTitle.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
        return widget.embedded ? content : Scaffold(body: content);
      },
    ),
  );

  Widget _header(BuildContext context) => Row(
    children: [
      IconButton(
        onPressed: () => Navigator.maybePop(context),
        icon: const Icon(Icons.arrow_back),
      ),
      const SizedBox(width: 4),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Find your next favorite',
              style: AppTheme.titleBold.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            Text(
              'Explore a world of good food',
              style: AppTheme.subTitle.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
      IconButton(onPressed: () {}, icon: const Icon(Icons.more_horiz)),
    ],
  );

  Widget _searchBar(SearchCubit cubit) => TextField(
    controller: _controller,
    focusNode: _searchFocus,
    onChanged: cubit.searchChanged,
    onSubmitted: cubit.submit,
    textInputAction: TextInputAction.search,
    decoration: InputDecoration(
      hintText: switch (cubit.state.mode) {
        SearchMode.search => 'Search meals by name',
        SearchMode.category => 'Search meals by category',
        SearchMode.ingredient => 'Search meals by ingredient',
        SearchMode.country => 'Search meals by country',
      },
      prefixIcon: const Icon(Icons.search),
      suffixIcon: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_controller.text.isNotEmpty)
            IconButton(
              tooltip: 'Clear search',
              onPressed: () {
                _controller.clear();
                cubit.clear();
                setState(() {});
              },
              icon: const Icon(Icons.clear),
            ),
          IconButton(
            tooltip: 'Sort results',
            onPressed: () => setState(() => _sortAscending = !_sortAscending),
            icon: Icon(_sortAscending ? Icons.sort : Icons.sort_by_alpha),
          ),
        ],
      ),
    ),
  );

  Widget _modeSelector(SearchState state, SearchCubit cubit) => Row(
    children: SearchMode.values.map((mode) {
      final selected = state.mode == mode;
      final label = mode == SearchMode.search
          ? 'Name'
          : mode.name[0].toUpperCase() + mode.name.substring(1);
      return Expanded(
        child: Padding(
          padding: EdgeInsets.only(
            right: mode == SearchMode.values.last ? 0 : AppTheme.gridGap / 2,
          ),
          child: OutlinedButton(
            onPressed: () {
              _controller.clear();
              cubit.setMode(mode);
              setState(() {});
            },
            style: OutlinedButton.styleFrom(
              backgroundColor: selected
                  ? Theme.of(context).colorScheme.primary.withValues(alpha: .16)
                  : Colors.transparent,
              side: BorderSide(
                color: selected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.outline,
                width: selected ? 1.5 : 1,
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.gridUnit,
                vertical: 12,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.cardRadius),
              ),
            ),
            child: Text(
              label,
              style: AppTheme.label.copyWith(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                color: selected
                    ? Theme.of(context).colorScheme.onSurface
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      );
    }).toList(),
  );

  Widget _discoveryGrid(SearchMode mode, SearchCubit cubit) {
    if (mode == SearchMode.search) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }
    if (mode == SearchMode.country) {
      return SliverPadding(
        padding: const EdgeInsets.all(20),
        sliver: SliverGrid(
          delegate: SliverChildBuilderDelegate(
            (_, index) => _countryCard(_countries[index], cubit),
            childCount: _countries.length,
          ),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: .82,
          ),
        ),
      );
    }
    final items = mode == SearchMode.category ? _categories : _ingredients;
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      sliver: SliverGrid(
        delegate: SliverChildBuilderDelegate(
          (_, index) => _discoveryCard(items[index], cubit, mode),
          childCount: items.length,
        ),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: mode == SearchMode.category ? 2 : 3,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: mode == SearchMode.category ? 1.25 : .82,
        ),
      ),
    );
  }

  Widget _discoveryCard(List<String> item, SearchCubit cubit, SearchMode mode) {
    final name = item[0];
    final image = mode == SearchMode.category
        ? item[1]
        : 'https://www.themealdb.com/images/ingredients/${item[1]}.png';
    return InkWell(
      borderRadius: BorderRadius.circular(AppTheme.cardRadius),
      onTap: () => cubit.select(mode == SearchMode.ingredient ? item[1] : name),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            Expanded(
              child: Image.network(
                image,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) =>
                    const Center(child: Icon(Icons.restaurant)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppTheme.gridUnit),
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTheme.label,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _countryCard((String, String, String) item, SearchCubit cubit) =>
      InkWell(
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        onTap: () => cubit.select(item.$3),
        child: Card(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(item.$2, style: const TextStyle(fontSize: 38)),
              const SizedBox(height: AppTheme.gridUnit),
              Text(item.$1, style: AppTheme.label),
            ],
          ),
        ),
      );

  SliverPadding _mealResults(List<MealModel> meals) {
    final sorted = [...meals]
      ..sort(
        (a, b) => _sortAscending
            ? a.strMeal.compareTo(b.strMeal)
            : b.strMeal.compareTo(a.strMeal),
      );
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      sliver: SliverList.builder(
        itemCount: sorted.length,
        itemBuilder: (_, index) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _mealTile(sorted[index]),
        ),
      ),
    );
  }

  Widget _mealTile(MealModel meal) => InkWell(
    borderRadius: BorderRadius.circular(AppTheme.cardRadius),
    onTap: () => _openMealDetails(meal),
    child: Card(
      child: Row(
        children: [
          Hero(
            tag: 'meal-${meal.idMeal}',
            child: ClipRRect(
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
                    '${meal.strCategory ?? 'Meal'} â€¢ ${meal.strArea ?? 'International'}',
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

  Widget _messageCard(String message, VoidCallback onRetry) => Card(
    margin: const EdgeInsets.fromLTRB(20, 24, 20, 8),
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppTheme.body.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: AppTheme.gridUnit),
          TextButton(onPressed: onRetry, child: const Text('Try again')),
        ],
      ),
    ),
  );

  void _openMealDetails(MealModel meal) {
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        pageBuilder: (_, animation, secondaryAnimation) =>
            MealDetailsPage(meal: meal),
        transitionsBuilder: (_, animation, secondaryAnimation, child) =>
            FadeTransition(
              opacity: CurvedAnimation(
                parent: animation,
                curve: Curves.easeOut,
              ),
              child: child,
            ),
        transitionDuration: const Duration(milliseconds: 260),
        reverseTransitionDuration: const Duration(milliseconds: 220),
      ),
    ).then((_) {
      if (mounted) context.read<HomeCubit>().refreshFavorites();
    });
  }
}
