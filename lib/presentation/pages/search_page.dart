import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/app_theme.dart';
import '../../core/utils/app_text_style.dart';
import '../../data/models/meal_model.dart';
import '../cubit/search_cubit.dart';
import '../cubit/home_cubit.dart';
import '../cubit/search_state.dart';
import '../widgets/bottom_nav.dart';
import 'meal_details_page.dart';
import 'filtered_meals_page.dart';

class SearchPage extends StatelessWidget {
  final SearchCubit? cubit;
  final bool embedded;
  final ValueChanged<int>? onBottomNavTap;

  const SearchPage({
    super.key,
    this.cubit,
    this.embedded = false,
    this.onBottomNavTap,
  });

  @override
  Widget build(BuildContext context) {
    final view = _SearchView(
      embedded: embedded,
      onBottomNavTap: onBottomNavTap,
    );
    return cubit == null
        ? BlocProvider(create: (_) => SearchCubit(), child: view)
        : BlocProvider.value(value: cubit!, child: view);
  }
}

class _SearchView extends StatefulWidget {
  final bool embedded;
  final ValueChanged<int>? onBottomNavTap;
  const _SearchView({required this.embedded, this.onBottomNavTap});

  @override
  State<_SearchView> createState() => _SearchViewState();
}

class _SearchViewState extends State<_SearchView> {
  final _controller = TextEditingController();
  final _searchFocus = FocusNode();
  SearchCubit? _cubit;
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
    ('Greece', 'GR', 'Greek'),
    ('Italy', 'IT', 'Italian'),
    ('Mexico', 'MX', 'Mexican'),
    ('India', 'IN', 'Indian'),
    ('Japan', 'JP', 'Japanese'),
    ('Egypt', 'EG', 'Egyptian'),
    ('France', 'FR', 'French'),
    ('Thailand', 'TH', 'Thai'),
    ('USA', 'US', 'American'),
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
  void didChangeDependencies() {
    super.didChangeDependencies();
    _cubit ??= context.read<SearchCubit>();
  }

  @override
  void dispose() {
    _cubit?.cancelPendingSearch();
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
              if (state.isTyping)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Text(
                      'Waiting to search...',
                      style: AppTheme.subTitle.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                )
              else if (state.isLoading)
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
                _discoveryGrid(state.mode, cubit, state.query),
              if (!state.isLoading && !state.isTyping)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  sliver: SliverToBoxAdapter(
                    child: Text(
                      state.mode == SearchMode.ingredient
                          ? 'Filter ingredients, then choose one to see meals.'
                          : state.mode == SearchMode.search
                          ? 'Type a meal name to search.'
                          : state.mode == SearchMode.country
                          ? 'Filter countries, then choose one to see meals.'
                          : 'Filter categories, then choose one to see meals.',
                      style: AppTheme.subTitle.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
        return widget.embedded
            ? content
            : Scaffold(
                body: content,
                bottomNavigationBar: BottomNavBar(
                  currentIndex: 0,
                  onTap:
                      widget.onBottomNavTap ??
                      (_) {
                        Navigator.maybePop(context);
                      },
                ),
              );
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
        SearchMode.category => 'Filter categories',
        SearchMode.ingredient => 'Filter ingredients',
        SearchMode.country => 'Filter countries',
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

  Widget _discoveryGrid(SearchMode mode, SearchCubit cubit, String filter) {
    if (mode == SearchMode.search) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }
    if (mode == SearchMode.country) {
      final query = filter.trim().toLowerCase();
      final filteredCountries = _countries.where((item) {
        return query.isEmpty ||
            item.$1.toLowerCase().contains(query) ||
            item.$3.toLowerCase().contains(query);
      }).toList();
      if (filteredCountries.isEmpty) {
        return const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Text('No countries matched your filter.'),
          ),
        );
      }
      return SliverPadding(
        padding: const EdgeInsets.all(20),
        sliver: SliverGrid(
          delegate: SliverChildBuilderDelegate(
            (_, index) => _countryCard(filteredCountries[index], cubit),
            childCount: filteredCountries.length,
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
    final query = filter.trim().toLowerCase();
    final filteredItems = items.where((item) {
      return query.isEmpty || item[0].toLowerCase().contains(query);
    }).toList();
    if (filteredItems.isEmpty) {
      return const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Text('No choices matched your filter.'),
        ),
      );
    }
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      sliver: SliverGrid(
        delegate: SliverChildBuilderDelegate(
          (_, index) => _discoveryCard(filteredItems[index], cubit, mode),
          childCount: filteredItems.length,
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
      onTap: () async {
        final value = mode == SearchMode.ingredient ? item[1] : name;
        await cubit.select(value);
        if (!mounted) return;
        await Navigator.push<void>(
          context,
          MaterialPageRoute(
            builder: (_) => FilteredMealsPage(cubit: cubit, title: name),
          ),
        );
        if (!mounted) return;
        cubit.resetDiscovery();
        _controller.clear();
        setState(() {});
      },
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
        onTap: () async {
          await cubit.select(item.$3);
          if (!mounted) return;
          await Navigator.push<void>(
            context,
            MaterialPageRoute(
              builder: (_) => FilteredMealsPage(cubit: cubit, title: item.$1),
            ),
          );
          if (!mounted) return;
          cubit.resetDiscovery();
          _controller.clear();
          setState(() {});
        },
        child: Card(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(AppTheme.cardRadius),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                child: Text(
                  item.$2,
                  style: AppTextStyles.buttonText.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 15,
                    letterSpacing: 1,
                  ),
                ),
              ),
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
    Navigator.of(context)
        .push(
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
        )
        .then((_) {
          if (mounted) context.read<HomeCubit>().refreshFavorites();
        });
  }
}
