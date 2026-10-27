import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/utils/app_colors.dart';
import '../../data/models/meal.model.dart';
import '../cubit/home_cubit.dart';
import '../cubit/home_state.dart';
import '../widgets/bottom_nav.dart';

class HomePage extends StatelessWidget {
  final String userName;
  const HomePage({super.key, this.userName = 'user'});

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => HomeCubit()..initialize(),
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

  @override
  Widget build(BuildContext context) => BlocBuilder<HomeCubit, HomeState>(
    builder: (context, state) {
      final cubit = context.read<HomeCubit>();
      return Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Hello, ${widget.userName}', style: const TextStyle(
                    fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                  const SizedBox(height: 2),
                  const Text("Let's make today feel good.",
                    style: TextStyle(fontSize: 14, color: AppColors.textMuted)),
                ]),
                Container(width: 40, height: 40,
                  decoration: const BoxDecoration(color: AppColors.surface, shape: BoxShape.circle),
                  child: const Icon(Icons.person_outline, color: AppColors.textDark, size: 22)),
              ]),
              const SizedBox(height: 20),
              Container(height: 52, padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(30),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha : .02), blurRadius: 10,
                    offset: const Offset(0, 2))]),
                child: Row(children: const [
                  Icon(Icons.search, color: AppColors.textDark, size: 22), SizedBox(width: 10),
                  Expanded(child: TextField(decoration: InputDecoration(
                    hintText: 'Search recipes, cuisines, ingredients',
                    hintStyle: TextStyle(color: AppColors.textHint, fontSize: 13.5),
                    border: InputBorder.none, isDense: true))),
                  Icon(Icons.tune, color: AppColors.textDark, size: 20),
                ])),
              const SizedBox(height: 14),
              if (!state.isOnline) _offlineNotice(state, cubit),
              const SizedBox(height: 10),
              const Text('Meal of the Day', style: TextStyle(fontSize: 18,
                fontWeight: FontWeight.bold, color: AppColors.textDark)),
              const SizedBox(height: 12),
              if (state.isLoading && state.mealOfDay == null)
                Container(height: 240, decoration: BoxDecoration(color: AppColors.surface,
                  borderRadius: BorderRadius.circular(24)),
                  child: const Center(child: CircularProgressIndicator(color: AppColors.primaryGreen)))
              else if (state.mealOfDay != null)
                _mealCard(state.mealOfDay!, state, cubit)
              else
                _emptyCard(state.errorMessage ?? 'No recipes available. Check your connection.'),
              const SizedBox(height: 24),
              _nutritionCard(),
              const SizedBox(height: 20),
              if (state.categories.isNotEmpty)
                Wrap(spacing: 8, runSpacing: 10, children: state.categories.map((category) =>
                  Container(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(25)),
                    child: Text(category, style: const TextStyle(color: AppColors.textDark,
                      fontSize: 13.5, fontWeight: FontWeight.w500)))).toList())
              else if (state.isLoading)
                const LinearProgressIndicator(color: AppColors.primaryGreen),
              const SizedBox(height: 20),
              Row(children: [
                Expanded(child: ElevatedButton(onPressed: () {}, style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen, elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                  padding: const EdgeInsets.symmetric(vertical: 14)),
                  child: const Text('Log a meal', style: TextStyle(color: AppColors.buttonText,
                    fontWeight: FontWeight.w600, fontSize: 14)))),
                const SizedBox(width: 12),
                Expanded(child: OutlinedButton(onPressed: () {}, style: OutlinedButton.styleFrom(
                  backgroundColor: AppColors.surface, side: BorderSide.none,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                  padding: const EdgeInsets.symmetric(vertical: 14)),
                  child: const Text('Meal Log / Insights', style: TextStyle(color: AppColors.textDark,
                    fontWeight: FontWeight.w600, fontSize: 13.5)))),
              ]),
              const SizedBox(height: 32),
              const Text('For your everyday', style: TextStyle(fontSize: 20,
                fontWeight: FontWeight.bold, color: AppColors.textDark)),
              const Text('Home feed • scroll continuation',
                style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
              const SizedBox(height: 20),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: const [
                Text('Popular Recipes', style: TextStyle(fontSize: 18,
                  fontWeight: FontWeight.bold, color: AppColors.textDark)),
                Text('See all', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
              ]),
              const SizedBox(height: 12),
              if (state.popularMeals.isEmpty && state.isLoading)
                const Center(child: CircularProgressIndicator(color: AppColors.primaryGreen))
              else if (state.popularMeals.isEmpty)
                const Text('No cached popular recipes available.',
                  style: TextStyle(color: AppColors.textMuted))
              else
                ...state.popularMeals.map((meal) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _popularTile(meal, state.favoriteIds.contains(meal.idMeal),
                    () => cubit.toggleFavorite(meal)))),
              const SizedBox(height: 16),
              const Text('Healthy Swaps', style: TextStyle(fontSize: 18,
                fontWeight: FontWeight.bold, color: AppColors.textDark)),
              const SizedBox(height: 12),
              Container(padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(24)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Try this instead', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(12),
                      child: Image.network('https://images.unsplash.com/photo-1578985545062-69928b1d9587?w=400',
                        height: 90, fit: BoxFit.cover, errorBuilder: (_ , _ ,  _ ) => _imageFallback(height: 90)))),
                    const Padding(padding: EdgeInsets.symmetric(horizontal: 10),
                      child: Icon(Icons.arrow_forward, color: AppColors.textDark, size: 20)),
                    Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(12),
                      child: Image.network('https://images.unsplash.com/photo-1488477181946-6428a0291777?w=400',
                        height: 90, fit: BoxFit.cover, errorBuilder: (_ , _ ,  _ ) => _imageFallback(height: 90)))),
                  ]),
                  const SizedBox(height: 12),
                  const Text('Chocolate Cake → Greek Yogurt Berry Bowl',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.textDark)),
                  const SizedBox(height: 4),
                  const Text('More protein, less added sugar. Still a sweet moment.',
                    style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                  const SizedBox(height: 14),
                  SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () {},
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.background, elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      padding: const EdgeInsets.symmetric(vertical: 12)),
                    child: const Text('View swap', style: TextStyle(color: AppColors.textDark,
                      fontWeight: FontWeight.w600, fontSize: 13.5)))),
                ])),
              const SizedBox(height: 20),
            ]),
          ),
        ),
        bottomNavigationBar: BottomNavBar(currentIndex: _currentBottomNavIndex,
          onTap: (index) => setState(() => _currentBottomNavIndex = index)),
      );
    },
  );

  Widget _offlineNotice(HomeState state, HomeCubit cubit) => Container(
    width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(color: AppColors.warning.withValues(alpha : .12),
      borderRadius: BorderRadius.circular(14)),
    child: Row(children: [
      const Icon(Icons.wifi_off, size: 18, color: AppColors.textMuted),
      const SizedBox(width: 8),
      Expanded(child: Text(state.errorMessage ?? 'Offline mode — showing saved recipes.',
        style: const TextStyle(fontSize: 12, color: AppColors.textMuted))),
      TextButton(onPressed: cubit.refresh, child: const Text('Retry')),
    ]),
  );

  Widget _mealCard(MealModel meal, HomeState state, HomeCubit cubit) {
    final fav = state.favoriteIds.contains(meal.idMeal);
    return Container(decoration: BoxDecoration(color: AppColors.surface,
      borderRadius: BorderRadius.circular(24)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        ClipRRect(borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: Image.network(meal.strMealThumb, height: 180, width: double.infinity, fit: BoxFit.cover,
            errorBuilder: (_ , _ ,  _ ) => _imageFallback(height: 180))),
        Padding(padding: const EdgeInsets.all(16), child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(meal.strMeal, maxLines: 2, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textDark)),
            const SizedBox(height: 4),
            Text('${meal.strCategory ?? 'Meal'} • ${meal.strArea ?? 'International'}',
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, color: AppColors.textMuted)),
          ])),
          const SizedBox(width: 10),
          Column(children: [
            const Text('— kcal', style: TextStyle(fontWeight: FontWeight.w700,
              fontSize: 13.5, color: AppColors.textDark)),
            IconButton(constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              padding: EdgeInsets.zero, onPressed: () => cubit.toggleFavorite(meal),
              tooltip: fav ? 'Remove from favorites' : 'Add to favorites',
              icon: Icon(fav ? Icons.favorite : Icons.favorite_border,
                color: fav ? AppColors.accentHeart : AppColors.textMuted, size: 22)),
          ]),
        ])),
      ]),
    );
  }

  Widget _nutritionCard() => Container(padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(24)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text("Today's Nutrition", style: TextStyle(fontSize: 18,
        fontWeight: FontWeight.bold, color: AppColors.textDark)),
      const SizedBox(height: 16),
      Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
        _macroRing('1,240', 'Calories', true), _macroRing('76g', 'Protein\nTarget not set', false),
        _macroRing('142g', 'Carbs\nTarget not set', false), _macroRing('41g', 'Fat\nTarget not set', false),
      ]),
      const SizedBox(height: 14),
      const Center(child: Text('Calories: 1,240 / 2,000 kcal • Macro targets not set',
        textAlign: TextAlign.center, style: TextStyle(fontSize: 11.5, color: AppColors.textMuted))),
    ]),
  );

  Widget _macroRing(String value, String label, bool primary) => Column(children: [
    Container(width: 58, height: 58, decoration: BoxDecoration(shape: BoxShape.circle,
      border: Border.all(color: primary ? AppColors.accentHeart : AppColors.divider, width: 3.5)),
      child: Center(child: Text(value, style: const TextStyle(fontSize: 12,
        fontWeight: FontWeight.bold, color: AppColors.textDark)))),
    const SizedBox(height: 6),
    Text(label, textAlign: TextAlign.center,
      style: const TextStyle(fontSize: 10, color: AppColors.textMuted, height: 1.2)),
  ]);

  Widget _popularTile(MealModel meal, bool fav, VoidCallback onTap) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20)),
    child: Row(children: [
      ClipRRect(borderRadius: BorderRadius.circular(14),
        child: Image.network(meal.strMealThumb, width: 65, height: 65, fit: BoxFit.cover,
          errorBuilder: (_ , _ ,  _ ) => _imageFallback(width: 65, height: 65))),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(meal.strMeal, maxLines: 2, overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.textDark)),
        const SizedBox(height: 2),
        Text('${meal.strCategory ?? 'Recipe'} • ${meal.strArea ?? 'International'}',
          maxLines: 1, overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
        const SizedBox(height: 2),
        const Text('Nutrition data unavailable', style: TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
      ])),
      IconButton(onPressed: onTap, padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
        icon: Icon(fav ? Icons.favorite : Icons.favorite_border,
          color: fav ? AppColors.accentHeart : AppColors.textMuted, size: 20)),
    ]),
  );

  Widget _emptyCard(String message) => Container(width: double.infinity, padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(24)),
    child: Text(message, style: const TextStyle(color: AppColors.textMuted)));

  Widget _imageFallback({double? width, double? height}) => Container(
    width: width, height: height, color: AppColors.divider,
    alignment: Alignment.center, child: const Icon(Icons.restaurant, color: AppColors.textMuted));
}
