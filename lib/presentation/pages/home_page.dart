import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/app_theme.dart' hide AppColors;
import '../../core/app_widgets.dart';
import '../../core/utils/app_colors.dart';
import '../../data/models/meal_model.dart';
import '../../core/guest_guard.dart';
import '../cubit/favorites_cubit.dart';
import '../cubit/home_cubit.dart';
import '../cubit/home_state.dart';
import '../cubit/meal_log_session.dart';
import '../cubit/planner_cubit.dart';
import '../cubit/profile_cubit.dart';
import '../cubit/search_cubit.dart';
import '../cubit/search_state.dart';
import '../widgets/bottom_nav.dart';
import 'insights_page.dart';
import 'favorites_screen.dart';
import 'all_popular_recipes_page.dart';
import 'log_meal_flow_pages.dart';
import 'planner_page.dart';
import 'profile_screen.dart';
import 'notifications_page.dart';
import '../cubit/notifications_cubit.dart';
import '../cubit/notifications_state.dart';
import './search_page.dart';
import 'meal_details_page.dart';
import '../../core/network/ai_api_config.dart';
import '../../core/network/dio_client.dart';
import '../../data/dataresource/ai_remote_darasource.dart';
import '../../data/repositories/ai_repository.dart';
import '../cubit/ai_chat_cubit.dart';
import 'ai_assistant_page.dart';
import '../../data/dataresource/meal_api_services.dart';

class HomePage extends StatelessWidget {
  final String userName;

  const HomePage({super.key, this.userName = 'user'});

  @override
  Widget build(BuildContext context) => MultiBlocProvider(
    providers: [
      BlocProvider(
        create: (context) =>
            HomeCubit(favoritesCubit: context.read<FavoritesCubit>())
              ..initialize(),
      ),
      BlocProvider(create: (_) => SearchCubit()),
    ],
    child: _HomeView(userName: userName),
  );
}

class _HomeView extends StatefulWidget {
  final String userName;

  const _HomeView({required this.userName});

  @override
  State<_HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<_HomeView> {
  int _currentBottomNavIndex = 0;
  final Set<String> _pendingFavoriteIds = {};
  late final MealLogSession _mealLogSession;

  final _homeSearchController = TextEditingController();
  final _homeSearchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _mealLogSession = MealLogSession();
  }

  Future<void> _toggleFavorite(MealModel meal) async {
    if (!_pendingFavoriteIds.add(meal.idMeal)) return;
    try {
      if (!await requireSignedIn(context, feature: 'Saving favorites')) return;
      if (!mounted) return;

      final favorites = context.read<FavoritesCubit>();
      final isFavorite = favorites.isFavorite(meal.idMeal);
      if (isFavorite) {
        final confirmed = await showActionConfirmationDialog(
          context,
          title: 'Remove from favorites?',
          message: 'Remove ${meal.strMeal} from your favorites?',
          confirmLabel: 'Remove',
          icon: Icons.favorite_border,
          accentColor: Theme.of(context).colorScheme.error,
        );
        if (!confirmed || !mounted) return;
      }

      await context.read<HomeCubit>().toggleFavorite(meal);
    } finally {
      _pendingFavoriteIds.remove(meal.idMeal);
    }
  }

  @override
  void dispose() {
    _mealLogSession.dispose();
    _homeSearchController.dispose();
    _homeSearchFocusNode.dispose();
    super.dispose();
  }

  void _openLogMealPage() {
    final searchCubit = context.read<SearchCubit>();
    Navigator.of(context).push(
      MaterialPageRoute(
        settings: const RouteSettings(name: 'LogMealPage'),
        builder: (_) => BlocProvider.value(
          value: searchCubit,
          child: LogMealPage(
            session: _mealLogSession,
            onBottomNavTap: (index) {
              Navigator.of(context).pop();
              if (mounted) setState(() => _currentBottomNavIndex = index);
            },
          ),
        ),
      ),
    );
  }

  Future<void> _openMealDetails(MealModel meal, HomeCubit cubit) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MealDetailsPage(
          meal: meal,
          logSession: _mealLogSession,
        ),
      ),
    );
    if (!mounted) return;
    await cubit.refreshFavorites();
  }

  void _openHealthyAlternatives(MealModel meal) {
    final ingredients = meal.ingredients
        .map((ingredient) => ingredient.name)
        .where((name) => name.trim().isNotEmpty)
        .join(', ');

    final description = ingredients.isEmpty
        ? meal.strMeal
        : '${meal.strMeal}. Ingredients: $ingredients';

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BlocProvider(
          create: (_) {
            final aiDioClient = DioClient(
              baseUrl: AiApiConfig.baseUrl.isEmpty
                  ? 'https://invalid.invalid/'
                  : AiApiConfig.baseUrl,
            );

            final mealApiService = MealApiService();

            final dataSource = AiRemoteDataSource(
              aiDioClient: aiDioClient,
              mealApiService: mealApiService,
            );

            return AiChatCubit(
              repository: AiRepository(dataSource: dataSource),
            );
          },
          child: AiAssistantPage(
            initialMealDescription: description,
            initialMode: AiAssistantMode.healthyAlternatives,
            onBottomNavTap: (index) {
              if (mounted) setState(() => _currentBottomNavIndex = index);
            },
          ),
        ),
      ),
    );
  }

  void _openProfile() => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => ProfileScreen(
        onDestinationChanged: (index) {
          if (mounted) setState(() => _currentBottomNavIndex = index);
        },
      ),
    ),
  );

  void _openNotifications() {
    context.read<NotificationsCubit>().load();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: context.read<NotificationsCubit>(),
          child: const NotificationsPage(),
        ),
      ),
    );
  }

  void _openSearch({String? query}) {
    _homeSearchFocusNode.unfocus();
    if (mounted) setState(() => _currentBottomNavIndex = 0);

    final searchCubit = context.read<SearchCubit>();
    final normalizedQuery = query?.trim() ?? '';

    searchCubit.setMode(SearchMode.search);
    if (normalizedQuery.isNotEmpty) {
      searchCubit.search(normalizedQuery);
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: searchCubit,
          child: SearchPage(
            embedded: false,
            logSession: _mealLogSession,
            onBottomNavTap: (index) {
              Navigator.of(context).pop();
              if (mounted) setState(() => _currentBottomNavIndex = index);
            },
          ),
        ),
      ),
    );
  }

  Widget _homeSearchBox() {
    final c = Theme.of(context).colorScheme;

    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.gridUnit * 2),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        border: Border.all(color: c.outline.withValues(alpha: 0.38)),
      ),
      child: Row(
        children: [
          Icon(Icons.search, color: c.onSurface, size: 22),
          const SizedBox(width: AppTheme.gridUnit),
          Expanded(
            child: TextField(
              controller: _homeSearchController,
              focusNode: _homeSearchFocusNode,
              textInputAction: TextInputAction.search,
              onTap: () => _openSearch(),
              onSubmitted: (value) => _openSearch(query: value),
              style: AppTheme.body.copyWith(color: c.onSurface),
              decoration: InputDecoration(
                hintText: 'Search recipes, cuisines, ingredients',
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
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => BlocBuilder<HomeCubit, HomeState>(
    builder: (context, state) {
      final c = Theme.of(context).colorScheme;
      final cubit = context.read<HomeCubit>();

      return PopScope(
        canPop: _currentBottomNavIndex == 0,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) setState(() => _currentBottomNavIndex = 0);
        },
        child: Scaffold(
          body: IndexedStack(
            index: _currentBottomNavIndex,
            children: [
              // =========================
              // 0 - HOME
              // =========================
              SafeArea(
                bottom: false,
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              BlocBuilder<ProfileCubit, ProfileState>(
                                builder: (context, profile) => Text(
                                  'Hello, ${profile.name}',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: c.onSurface,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                "Let's make today feel good.",
                                style: TextStyle(
                                  fontSize: 14,
                                  color: c.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),

                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              BlocBuilder<
                                NotificationsCubit,
                                NotificationsState
                              >(
                                builder: (context, notifications) {
                                  final unread = notifications.unreadCount;
                                  return Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      Container(
                                        width: 40,
                                        height: 40,
                                        decoration: BoxDecoration(
                                          color: c.surface,
                                          shape: BoxShape.circle,
                                        ),
                                        child: IconButton(
                                          padding: EdgeInsets.zero,
                                          onPressed: _openNotifications,
                                          icon: Icon(
                                            Icons.notifications_none,
                                            color: c.onSurface,
                                            size: 22,
                                          ),
                                        ),
                                      ),
                                      if (unread > 0)
                                        Positioned(
                                          right: 1,
                                          top: 1,
                                          child: Container(
                                            width: 9,
                                            height: 9,
                                            decoration: BoxDecoration(
                                              color: AppColors.error,
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: c.surface,
                                                width: 1.5,
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  );
                                },
                              ),
                              const SizedBox(width: 8),
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
                        ],
                      ),

                      const SizedBox(height: 20),

                      _homeSearchBox(),

                      const SizedBox(height: 14),

                      if (!state.isOnline) _offlineNotice(state, cubit),

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

                      if (state.isLoading && state.mealOfDay == null)
                        Container(
                          height: 240,
                          decoration: BoxDecoration(
                            color: c.surface,
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Center(
                            child: CircularProgressIndicator(color: c.primary),
                          ),
                        )
                      else if (state.mealOfDay != null)
                        _mealCard(state.mealOfDay!, state, cubit)
                      else
                        _emptyCard(
                          state.errorMessage ??
                              'No recipes available. Check your connection.',
                        ),

                      const SizedBox(height: 24),

                      _nutritionCard(state),

                      const SizedBox(height: 20),

                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _openLogMealPage,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: c.primary,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(25),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                              ),
                              child: Text(
                                'Log a meal',
                                style: TextStyle(
                                  color: c.onPrimary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(width: 12),

                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => InsightsPage(
                                    onBottomNavTap: (index) {
                                      Navigator.of(context).pop();
                                      if (mounted) {
                                        setState(
                                          () => _currentBottomNavIndex = index,
                                        );
                                      }
                                    },
                                  ),
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                backgroundColor: c.surface,
                                side: BorderSide.none,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(25),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                              ),
                              child: Text(
                                'Meal Log / Insights',
                                style: TextStyle(
                                  color: c.onSurface,
                                  fontWeight: FontWeight.w600,
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

                      const SizedBox(height: 20),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Popular Recipes',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: c.onSurface,
                            ),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => AllPopularRecipesPage(
                                  onBottomNavTap: (index) {
                                    Navigator.of(context).pop();
                                    if (mounted) {
                                      setState(
                                        () => _currentBottomNavIndex = index,
                                      );
                                    }
                                  },
                                ),
                              ),
                            ),
                            child: Text(
                              'See all',
                              style: TextStyle(
                                color: c.onSurfaceVariant,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      if (state.popularMeals.isEmpty && state.isLoading)
                        Center(
                          child: CircularProgressIndicator(color: c.primary),
                        )
                      else if (state.popularMeals.isEmpty)
                        Text(
                          'No cached popular recipes available.',
                          style: TextStyle(color: c.onSurfaceVariant),
                        )
                      else
                        ...state.popularMeals.map(
                          (meal) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _popularTile(
                              meal,
                              state.favoriteIds.contains(meal.idMeal),
                              () => _toggleFavorite(meal),
                              () => _openMealDetails(meal, cubit),
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

                      if (state.mealOfDay != null &&
                          state.popularMeals.isNotEmpty)
                        _healthySwapCard(state.mealOfDay!)
                      else
                        _emptyCard(
                          'Healthy swaps will appear when recipes are available.',
                        ),

                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),

              // =========================
              // 1 - FAVORITES
              // =========================
              const FavoritesScreen(embedded: true),

              // =========================
              // 2 - NUTRIAI
              // =========================
              BlocProvider(
                create: (_) {
                  final aiDioClient = DioClient(
                    baseUrl: AiApiConfig.baseUrl.isEmpty
                        ? 'https://invalid.invalid/'
                        : AiApiConfig.baseUrl,
                  );
                  final mealApiService = MealApiService();
                  final dataSource = AiRemoteDataSource(
                    aiDioClient: aiDioClient,
                    mealApiService: mealApiService,
                  );
                  return AiChatCubit(
                    repository: AiRepository(dataSource: dataSource),
                  );
                },
                child: AiAssistantPage(
                  embedded: true,
                  onBottomNavTap: (index) {
                    setState(() => _currentBottomNavIndex = index);
                  },
                ),
              ),

              // =========================
              // 3 - PLANNER
              // =========================
              PlannerPage(
                cubit: context.read<PlannerCubit>(),
                embedded: true,
                onBack: () => setState(() => _currentBottomNavIndex = 0),
                onBottomNavTap: (index) {
                  setState(() => _currentBottomNavIndex = index);
                },
                onAddMeal: () {
                  setState(() => _currentBottomNavIndex = 0);
                  _openSearch();
                },
              ),

              // =========================
              // 4 - Insights
              // =========================
              InsightsPage(
                embedded: true,
                onBack: () => setState(() => _currentBottomNavIndex = 0),
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
        ),
      );
    },
  );

  Widget _healthySwapCard(MealModel original) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'A similar meal with a healthier profile',
            style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  original.strMealThumb,
                  width: 104,
                  height: 86,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => _imageFallback(height: 86),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  original.strMeal,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: colors.onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _openHealthyAlternatives(original),
              child: const Text('View swap'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _offlineNotice(HomeState state, HomeCubit cubit) {
    final c = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(Icons.wifi_off, size: 18, color: c.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              state.errorMessage ?? 'Offline mode - showing saved recipes.',
              style: TextStyle(fontSize: 12, color: c.onSurfaceVariant),
            ),
          ),
          TextButton(onPressed: cubit.refresh, child: const Text('Retry')),
        ],
      ),
    );
  }

  Widget _mealCard(MealModel meal, HomeState state, HomeCubit cubit) {
    final c = Theme.of(context).colorScheme;
    final fav = state.favoriteIds.contains(meal.idMeal);
    final calories = state.mealNutrition?.calories;

    return InkWell(
      onTap: () => _openMealDetails(meal, cubit),
      borderRadius: BorderRadius.circular(24),
      child: Container(
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
              child: Image.network(
                meal.strMealThumb,
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _imageFallback(height: 180),
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          meal.strMeal,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: c.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${meal.strCategory ?? 'Meal'} - ${meal.strArea ?? 'International'}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color: c.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 10),

                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        calories == null
                            ? '- kcal'
                            : '${calories.toStringAsFixed(0)} kcal',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13.5,
                          color: c.onSurface,
                        ),
                      ),

                      const SizedBox(height: 4),

                      IconButton(
                        constraints: const BoxConstraints(
                          minWidth: 40,
                          minHeight: 40,
                        ),
                        padding: EdgeInsets.zero,
                        onPressed: () => _toggleFavorite(meal),
                        tooltip: fav
                            ? 'Remove from favorites'
                            : 'Add to favorites',
                        icon: Icon(
                          fav ? Icons.favorite : Icons.favorite_border,
                          color: fav
                              ? AppColors.accentHeart
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
      ),
    );
  }

  Widget _nutritionCard(HomeState state) {
    final c = Theme.of(context).colorScheme;
    final nutrition = state.mealNutrition;

    String value(double? number, String unit) {
      if (number == null) return '--';

      return '${number.toStringAsFixed(1)}$unit';
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Meal Nutrition',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: c.onSurface,
            ),
          ),

          const SizedBox(height: 5),

          Text(
            'Nutrition values for the whole recipe',
            style: TextStyle(fontSize: 11.5, color: c.onSurfaceVariant),
          ),

          const SizedBox(height: 16),

          if (state.isNutritionLoading)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: CircularProgressIndicator(color: c.primary),
              ),
            )
          else if (nutrition == null)
            Column(
              children: [
                Text(
                  state.nutritionError ??
                      'Nutrition data is not available yet.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: c.onSurfaceVariant),
                ),

                const SizedBox(height: 8),

                TextButton(
                  onPressed: state.mealOfDay == null
                      ? null
                      : () => context.read<HomeCubit>().loadMealNutrition(
                          state.mealOfDay!,
                        ),
                  child: const Text('Retry'),
                ),
              ],
            )
          else ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _macroRing(
                  value(nutrition.calories, ''),
                  'Calories\nkcal',
                  true,
                ),
                _macroRing(value(nutrition.protein, 'g'), 'Protein', false),
                _macroRing(value(nutrition.carbohydrates, 'g'), 'Carbs', false),
                _macroRing(value(nutrition.fat, 'g'), 'Fat', false),
              ],
            ),

            const SizedBox(height: 14),

            Text(
              !nutrition.isComplete
                  ? 'Some ingredients or nutrients could not be calculated. Displayed values may be incomplete.'
                  : nutrition.isEstimated
                  ? 'Some ingredient quantities were estimated.'
                  : 'All available ingredient quantities were calculated.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: c.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }

  Widget _macroRing(String value, String label, bool primary) {
    final c = Theme.of(context).colorScheme;

    return Column(
      children: [
        Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: primary ? AppColors.accentHeart : c.outline,
              width: 3.5,
            ),
          ),
          child: Center(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: c.onSurface,
              ),
            ),
          ),
        ),

        const SizedBox(height: 6),

        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 10,
            color: c.onSurfaceVariant,
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
    VoidCallback onOpen,
  ) {
    final c = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onOpen,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.network(
                meal.strMealThumb,
                width: 65,
                height: 65,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) =>
                    _imageFallback(width: 65, height: 65),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    meal.strMeal,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: c.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${meal.strCategory ?? 'Recipe'} - ${meal.strArea ?? 'International'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: c.onSurfaceVariant),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Open recipe details',
                    style: TextStyle(fontSize: 11.5, color: c.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: onTap,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              icon: Icon(
                fav ? Icons.favorite : Icons.favorite_border,
                color: fav ? AppColors.accentHeart : c.onSurfaceVariant,
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyCard(String message) {
    final c = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Text(message, style: TextStyle(color: c.onSurfaceVariant)),
    );
  }

  Widget _imageFallback({double? width, double? height}) {
    final c = Theme.of(context).colorScheme;

    return Container(
      width: width,
      height: height,
      color: c.outline,
      alignment: Alignment.center,
      child: Icon(Icons.restaurant, color: c.onSurfaceVariant),
    );
  }
}