import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/app_theme.dart' hide AppColors;
import '../../core/utils/app_colors.dart';
import '../../data/models/meal_model.dart';
import '../../core/guest_guard.dart';
import '../cubit/favorites_cubit.dart';
import '../cubit/home_cubit.dart';
import '../cubit/home_state.dart';
import '../cubit/planner_cubit.dart';
import '../cubit/profile_cubit.dart';
import '../cubit/search_cubit.dart';
import '../cubit/search_state.dart';
import '../widgets/bottom_nav.dart';
//import 'insights_page.dart';
import 'planner_page.dart';
import 'profile_screen.dart';
import 'search_page.dart';

class HomePage extends StatelessWidget {
  final String userName;

  const HomePage({
    super.key,
    this.userName = 'user',
  });

  @override
  Widget build(BuildContext context) => MultiBlocProvider(
    providers: [
      BlocProvider(
        create: (context) => HomeCubit(
          favoritesCubit: context.read<FavoritesCubit>(),
        )..initialize(),
      ),
      BlocProvider(
        create: (_) => SearchCubit(),
      ),
      BlocProvider(
        create: (_) => PlannerCubit()..initialize(),
      ),
    ],
    child: _HomeView(userName: userName),
  );
}

class _HomeView extends StatefulWidget {
  final String userName;

  const _HomeView({
    required this.userName,
  });

  @override
  State<_HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<_HomeView> {
  int _currentBottomNavIndex = 0;

  final _homeSearchController = TextEditingController();
  final _homeSearchFocusNode = FocusNode();

  @override
  void dispose() {
    _homeSearchController.dispose();
    _homeSearchFocusNode.dispose();
    super.dispose();
  }

  void _openProfile() => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => const ProfileScreen(),
    ),
  );

  void _openSearch({String? query}) {
    _homeSearchFocusNode.unfocus();

    final searchCubit = context.read<SearchCubit>();
    final normalizedQuery = query?.trim() ?? '';

    if (normalizedQuery.isNotEmpty) {
      searchCubit.setMode(SearchMode.search);
      searchCubit.search(normalizedQuery);
    }

    if (_currentBottomNavIndex != 1) {
      setState(() => _currentBottomNavIndex = 1);
    }
  }

  Widget _homeSearchBox() {
    final c = Theme.of(context).colorScheme;

    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.gridUnit * 2,
      ),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(
          AppTheme.cardRadius,
        ),
        border: Border.all(
          color: c.outline.withValues(alpha: 0.38),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.search,
            color: c.onSurface,
            size: 22,
          ),
          const SizedBox(
            width: AppTheme.gridUnit,
          ),
          Expanded(
            child: TextField(
              controller: _homeSearchController,
              focusNode: _homeSearchFocusNode,
              textInputAction: TextInputAction.search,
              onTap: () => _openSearch(),
              onSubmitted: (value) => _openSearch(
                query: value,
              ),
              style: AppTheme.body.copyWith(
                color: c.onSurface,
              ),
              decoration: InputDecoration(
                hintText:
                'Search recipes, cuisines, ingredients',
                hintStyle: AppTheme.body.copyWith(
                  color: c.onSurfaceVariant,
                  fontSize: 13.5,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                fillColor: Colors.transparent,
                isDense: true,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Search filters',
            onPressed: () => _openSearch(),
            icon: Icon(
              Icons.tune,
              color: c.onSurface,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<HomeCubit, HomeState>(
        builder: (context, state) {
          final c = Theme.of(context).colorScheme;
          final cubit = context.read<HomeCubit>();

          return Scaffold(
            body: IndexedStack(
              index: _currentBottomNavIndex,
              children: [
                // =========================
                // 0 - HOME
                // =========================
                SafeArea(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    child: Column(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment:
                              CrossAxisAlignment.start,
                              children: [
                                BlocBuilder<
                                    ProfileCubit,
                                    ProfileState
                                >(
                                  builder: (context, profile) =>
                                      Text(
                                        'Hello, ${profile.name}',
                                        style: TextStyle(
                                          fontSize: 22,
                                          fontWeight:
                                          FontWeight.bold,
                                          color: c.onSurface,
                                        ),
                                      ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  "Let's make today feel good.",
                                  style: TextStyle(
                                    fontSize: 14,
                                    color:
                                    c.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),

                            // Profile icon
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: c.surface,
                                shape: BoxShape.circle,
                              ),
                              child: IconButton(
                                padding: EdgeInsets.zero,
                                onPressed: _openProfile,
                                icon: Icon(
                                  Icons.person_outline,
                                  color: c.onSurface,
                                  size: 22,
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 20),

                        _homeSearchBox(),

                        const SizedBox(height: 14),

                        if (!state.isOnline)
                          _offlineNotice(state, cubit),

                        const SizedBox(height: 10),

                        Text(
                          'Meal of the Day',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: c.onSurface,
                          ),
                        ),

                        const SizedBox(height: 12),

                        if (state.isLoading &&
                            state.mealOfDay == null)
                          Container(
                            height: 240,
                            decoration: BoxDecoration(
                              color: c.surface,
                              borderRadius:
                              BorderRadius.circular(24),
                            ),
                            child: Center(
                              child:
                              CircularProgressIndicator(
                                color: c.primary,
                              ),
                            ),
                          )
                        else if (state.mealOfDay != null)
                          _mealCard(
                            state.mealOfDay!,
                            state,
                            cubit,
                          )
                        else
                          _emptyCard(
                            state.errorMessage ??
                                'No recipes available. Check your connection.',
                          ),

                        const SizedBox(height: 24),

                        _nutritionCard(state),

                        const SizedBox(height: 20),

                        if (state.categories.isNotEmpty)
                          Wrap(
                            spacing: 8,
                            runSpacing: 10,
                            children: state.categories
                                .map(
                                  (category) => Container(
                                padding:
                                const EdgeInsets
                                    .symmetric(
                                  horizontal: 20,
                                  vertical: 10,
                                ),
                                decoration:
                                BoxDecoration(
                                  color: c.surface,
                                  borderRadius:
                                  BorderRadius
                                      .circular(25),
                                ),
                                child: Text(
                                  category,
                                  style: TextStyle(
                                    color: c.onSurface,
                                    fontSize: 13.5,
                                    fontWeight:
                                    FontWeight.w500,
                                  ),
                                ),
                              ),
                            )
                                .toList(),
                          )
                        else if (state.isLoading)
                          LinearProgressIndicator(
                            color: c.primary,
                          ),

                        const SizedBox(height: 20),

                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () {},
                                style:
                                ElevatedButton.styleFrom(
                                  backgroundColor:
                                  c.primary,
                                  elevation: 0,
                                  shape:
                                  RoundedRectangleBorder(
                                    borderRadius:
                                    BorderRadius
                                        .circular(25),
                                  ),
                                  padding:
                                  const EdgeInsets
                                      .symmetric(
                                    vertical: 14,
                                  ),
                                ),
                                child: Text(
                                  'Log a meal',
                                  style: TextStyle(
                                    color: c.onPrimary,
                                    fontWeight:
                                    FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(width: 12),

                            Expanded(
                              child: OutlinedButton(
                                onPressed: () {
                                  setState(
                                        () =>
                                    _currentBottomNavIndex =
                                    4,
                                  );
                                },
                                style:
                                OutlinedButton.styleFrom(
                                  backgroundColor:
                                  c.surface,
                                  side: BorderSide.none,
                                  shape:
                                  RoundedRectangleBorder(
                                    borderRadius:
                                    BorderRadius
                                        .circular(25),
                                  ),
                                  padding:
                                  const EdgeInsets
                                      .symmetric(
                                    vertical: 14,
                                  ),
                                ),
                                child: Text(
                                  'Meal Log / Insights',
                                  style: TextStyle(
                                    color: c.onSurface,
                                    fontWeight:
                                    FontWeight.w600,
                                    fontSize: 13.5,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 32),

                        Text(
                          'For your everyday',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: c.onSurface,
                          ),
                        ),

                        Text(
                          'Home feed • scroll continuation',
                          style: TextStyle(
                            fontSize: 12,
                            color: c.onSurfaceVariant,
                          ),
                        ),

                        const SizedBox(height: 20),

                        Row(
                          mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Popular Recipes',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight:
                                FontWeight.bold,
                                color: c.onSurface,
                              ),
                            ),
                            Text(
                              'See all',
                              style: TextStyle(
                                color:
                                c.onSurfaceVariant,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),

                        if (state.popularMeals.isEmpty &&
                            state.isLoading)
                          Center(
                            child:
                            CircularProgressIndicator(
                              color: c.primary,
                            ),
                          )
                        else if (state.popularMeals.isEmpty)
                          Text(
                            'No cached popular recipes available.',
                            style: TextStyle(
                              color:
                              c.onSurfaceVariant,
                            ),
                          )
                        else
                          ...state.popularMeals.map(
                                (meal) => Padding(
                              padding:
                              const EdgeInsets.only(
                                bottom: 12,
                              ),
                              child: _popularTile(
                                meal,
                                state.favoriteIds
                                    .contains(
                                    meal.idMeal),
                                    () async {
                                  if (!await requireSignedIn(
                                    context,
                                    feature: 'Saving favorites',
                                  )) {
                                    return;
                                  }
                                  cubit.toggleFavorite(meal);
                                },
                              ),
                            ),
                          ),

                        const SizedBox(height: 16),

                        Text(
                          'Healthy Swaps',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: c.onSurface,
                          ),
                        ),

                        const SizedBox(height: 12),

                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: c.surface,
                            borderRadius:
                            BorderRadius.circular(24),
                          ),
                          child: Column(
                            crossAxisAlignment:
                            CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Try this instead',
                                style: TextStyle(
                                  color:
                                  c.onSurfaceVariant,
                                  fontSize: 12,
                                ),
                              ),

                              const SizedBox(height: 12),

                              Row(
                                children: [
                                  Expanded(
                                    child: ClipRRect(
                                      borderRadius:
                                      BorderRadius
                                          .circular(
                                          12),
                                      child:
                                      Image.network(
                                        'https://images.unsplash.com/photo-1578985545062-69928b1d9587?w=400',
                                        height: 90,
                                        fit: BoxFit.cover,
                                        errorBuilder:
                                            (_, _, _) =>
                                            _imageFallback(
                                              height: 90,
                                            ),
                                      ),
                                    ),
                                  ),

                                  Padding(
                                    padding:
                                    const EdgeInsets
                                        .symmetric(
                                      horizontal: 10,
                                    ),
                                    child: Icon(
                                      Icons.arrow_forward,
                                      color: c.onSurface,
                                      size: 20,
                                    ),
                                  ),

                                  Expanded(
                                    child: ClipRRect(
                                      borderRadius:
                                      BorderRadius
                                          .circular(
                                          12),
                                      child:
                                      Image.network(
                                        'https://images.unsplash.com/photo-1488477181946-6428a0291777?w=400',
                                        height: 90,
                                        fit: BoxFit.cover,
                                        errorBuilder:
                                            (_, _, _) =>
                                            _imageFallback(
                                              height: 90,
                                            ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 12),

                              Text(
                                'Chocolate Cake → Greek Yogurt Berry Bowl',
                                style: TextStyle(
                                  fontWeight:
                                  FontWeight.w700,
                                  fontSize: 14,
                                  color: c.onSurface,
                                ),
                              ),

                              const SizedBox(height: 4),

                              Text(
                                'More protein, less added sugar. Still a sweet moment.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color:
                                  c.onSurfaceVariant,
                                ),
                              ),

                              const SizedBox(height: 14),

                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: () {},
                                  style:
                                  ElevatedButton
                                      .styleFrom(
                                    backgroundColor:
                                    c.surfaceContainerHighest,
                                    elevation: 0,
                                    shape:
                                    RoundedRectangleBorder(
                                      borderRadius:
                                      BorderRadius
                                          .circular(
                                          20),
                                    ),
                                    padding:
                                    const EdgeInsets
                                        .symmetric(
                                      vertical: 12,
                                    ),
                                  ),
                                  child: Text(
                                    'View swap',
                                    style: TextStyle(
                                      color:
                                      c.onSurface,
                                      fontWeight:
                                      FontWeight.w600,
                                      fontSize: 13.5,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),

                // =========================
                // 1 - SEARCH
                // =========================
                SearchPage(
                  cubit: context.read<SearchCubit>(),
                  embedded: true,
                ),

                // =========================
                // 2 - NUTRIAI
                // =========================
                const Scaffold(
                  body: Center(
                    child: Text('NutriAI'),
                  ),
                ),

                // =========================
                // 3 - PLANNER
                // =========================
                PlannerPage(
                  cubit: context.read<PlannerCubit>(),
                  embedded: true,
                ),

                // =========================
                // 4 - PLACEHOLDER
                // =========================
                const Scaffold(
                  body: Center(
                    child: Text('Coming soon'),
                  ),
                ),
              ],
            ),

            bottomNavigationBar: BottomNavBar(
              currentIndex: _currentBottomNavIndex,
              onTap: (index) {
                setState(() {
                  _currentBottomNavIndex = index;
                });
              },
            ),
          );
        },
      );

  Widget _offlineNotice(
      HomeState state,
      HomeCubit cubit,
      ) {
    final c = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color:
        AppColors.warning.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(
            Icons.wifi_off,
            size: 18,
            color: c.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              state.errorMessage ??
                  'Offline mode — showing saved recipes.',
              style: TextStyle(
                fontSize: 12,
                color: c.onSurfaceVariant,
              ),
            ),
          ),
          TextButton(
            onPressed: cubit.refresh,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _mealCard(
      MealModel meal,
      HomeState state,
      HomeCubit cubit,
      ) {
    final c = Theme.of(context).colorScheme;
    final fav =
    state.favoriteIds.contains(meal.idMeal);
    final calories =
        state.mealNutrition?.calories;

    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius:
            const BorderRadius.vertical(
              top: Radius.circular(24),
            ),
            child: Image.network(
              meal.strMealThumb,
              height: 180,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) =>
                  _imageFallback(height: 180),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      Text(
                        meal.strMeal,
                        maxLines: 2,
                        overflow:
                        TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight:
                          FontWeight.w700,
                          color: c.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${meal.strCategory ?? 'Meal'} • ${meal.strArea ?? 'International'}',
                        maxLines: 1,
                        overflow:
                        TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          color:
                          c.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 10),

                Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.end,
                  children: [
                    Text(
                      calories == null
                          ? '— kcal'
                          : '${calories.toStringAsFixed(0)} kcal',
                      style: TextStyle(
                        fontWeight:
                        FontWeight.w700,
                        fontSize: 13.5,
                        color: c.onSurface,
                      ),
                    ),

                    const SizedBox(height: 4),

                    IconButton(
                      constraints:
                      const BoxConstraints(
                        minWidth: 40,
                        minHeight: 40,
                      ),
                      padding:
                      EdgeInsets.zero,
                      onPressed: () async {
                        if (!await requireSignedIn(
                          context,
                          feature: 'Saving favorites',
                        )) {
                          return;
                        }
                        cubit.toggleFavorite(meal);
                      },
                      tooltip: fav
                          ? 'Remove from favorites'
                          : 'Add to favorites',
                      icon: Icon(
                        fav
                            ? Icons.favorite
                            : Icons.favorite_border,
                        color: fav
                            ? AppColors
                            .accentHeart
                            : c.onSurfaceVariant,
                        size: 22,
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

  Widget _nutritionCard(
      HomeState state,
      ) {
    final c =
        Theme.of(context).colorScheme;
    final nutrition =
        state.mealNutrition;

    String value(
        double? number,
        String unit,
        ) {
      if (number == null) return '--';

      return '${number.toStringAsFixed(1)}$unit';
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius:
        BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Text(
            'Meal Nutrition',
            style: TextStyle(
              fontSize: 18,
              fontWeight:
              FontWeight.bold,
              color: c.onSurface,
            ),
          ),

          const SizedBox(height: 5),

          Text(
            'Nutrition values for the whole recipe',
            style: TextStyle(
              fontSize: 11.5,
              color:
              c.onSurfaceVariant,
            ),
          ),

          const SizedBox(height: 16),

          if (state.isNutritionLoading)
            Center(
              child: Padding(
                padding:
                const EdgeInsets.all(16),
                child:
                CircularProgressIndicator(
                  color: c.primary,
                ),
              ),
            )
          else if (nutrition == null)
            Column(
              children: [
                Text(
                  state.nutritionError ??
                      'Nutrition data is not available yet.',
                  textAlign:
                  TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color:
                    c.onSurfaceVariant,
                  ),
                ),

                const SizedBox(height: 8),

                TextButton(
                  onPressed:
                  state.mealOfDay == null
                      ? null
                      : () => context
                      .read<HomeCubit>()
                      .loadMealNutrition(
                    state.mealOfDay!,
                  ),
                  child:
                  const Text('Retry'),
                ),
              ],
            )
          else ...[
              Row(
                mainAxisAlignment:
                MainAxisAlignment
                    .spaceAround,
                children: [
                  _macroRing(
                    value(
                      nutrition.calories,
                      '',
                    ),
                    'Calories\nkcal',
                    true,
                  ),
                  _macroRing(
                    value(
                      nutrition.protein,
                      'g',
                    ),
                    'Protein',
                    false,
                  ),
                  _macroRing(
                    value(
                      nutrition.carbohydrates,
                      'g',
                    ),
                    'Carbs',
                    false,
                  ),
                  _macroRing(
                    value(
                      nutrition.fat,
                      'g',
                    ),
                    'Fat',
                    false,
                  ),
                ],
              ),

              const SizedBox(height: 14),

              Text(
                !nutrition.isComplete
                    ? 'Some ingredients or nutrients could not be calculated. Displayed values may be incomplete.'
                    : nutrition.isEstimated
                    ? 'Some ingredient quantities were estimated.'
                    : 'All available ingredient quantities were calculated.',
                textAlign:
                TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  color:
                  c.onSurfaceVariant,
                ),
              ),
            ],
        ],
      ),
    );
  }

  Widget _macroRing(
      String value,
      String label,
      bool primary,
      ) {
    final c =
        Theme.of(context).colorScheme;

    return Column(
      children: [
        Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: primary
                  ? AppColors.accentHeart
                  : c.outline,
              width: 3.5,
            ),
          ),
          child: Center(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight:
                FontWeight.bold,
                color: c.onSurface,
              ),
            ),
          ),
        ),

        const SizedBox(height: 6),

        Text(
          label,
          textAlign:
          TextAlign.center,
          style: TextStyle(
            fontSize: 10,
            color:
            c.onSurfaceVariant,
            height: 1.2,
          ),
        ),
      ],
    );
  }

  Widget _popularTile(
      MealModel meal,
      bool fav,
      VoidCallback onTap,
      ) {
    final c =
        Theme.of(context).colorScheme;

    return Container(
      padding:
      const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius:
        BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius:
            BorderRadius.circular(14),
            child: Image.network(
              meal.strMealThumb,
              width: 65,
              height: 65,
              fit: BoxFit.cover,
              errorBuilder:
                  (_, _, _) =>
                  _imageFallback(
                    width: 65,
                    height: 65,
                  ),
            ),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment
                  .start,
              children: [
                Text(
                  meal.strMeal,
                  maxLines: 2,
                  overflow:
                  TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight:
                    FontWeight.w700,
                    fontSize: 14,
                    color:
                    c.onSurface,
                  ),
                ),

                const SizedBox(height: 2),

                Text(
                  '${meal.strCategory ?? 'Recipe'} • ${meal.strArea ?? 'International'}',
                  maxLines: 1,
                  overflow:
                  TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color:
                    c.onSurfaceVariant,
                  ),
                ),

                const SizedBox(height: 2),

                Text(
                  'Nutrition data unavailable',
                  style: TextStyle(
                    fontSize: 11.5,
                    color:
                    c.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),

          IconButton(
            onPressed: onTap,
            padding:
            EdgeInsets.zero,
            constraints:
            const BoxConstraints(
              minWidth: 40,
              minHeight: 40,
            ),
            icon: Icon(
              fav
                  ? Icons.favorite
                  : Icons.favorite_border,
              color: fav
                  ? AppColors
                  .accentHeart
                  : c.onSurfaceVariant,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyCard(
      String message,
      ) {
    final c =
        Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding:
      const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius:
        BorderRadius.circular(24),
      ),
      child: Text(
        message,
        style: TextStyle(
          color:
          c.onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _imageFallback({
    double? width,
    double? height,
  }) {
    final c =
        Theme.of(context).colorScheme;

    return Container(
      width: width,
      height: height,
      color: c.outline,
      alignment:
      Alignment.center,
      child: Icon(
        Icons.restaurant,
        color:
        c.onSurfaceVariant,
      ),
    );
  }
}