import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nutri_mate/core/app_theme.dart';
import 'package:nutri_mate/data/models/meal_model.dart';
import 'package:nutri_mate/presentation/cubit/favorites_state.dart';
import 'package:nutri_mate/presentation/pages/meal_details_page.dart';

import '../cubit/favorites_cubit.dart';

enum _FavoritesView { all, grid, list }

/// Favorite meals of the signed-in user.
/// Reads from the root-level [FavoritesCubit], which reloads by itself
/// whenever the account changes.
class FavoritesScreen extends StatefulWidget {
  final bool embedded;

  const FavoritesScreen({super.key, this.embedded = false});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  _FavoritesView _view = _FavoritesView.all;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;

    final content = SafeArea(
      child: BlocBuilder<FavoritesCubit, FavoritesState>(
        builder: (context, state) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _header(context, c),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: _filters(state, c),
            ),
            Expanded(child: _body(context, state, c)),
          ],
        ),
      ),
    );
    return widget.embedded ? content : Scaffold(body: content);
  }

  // ---------------------------------------------------------------------------
  // Header + filters
  // ---------------------------------------------------------------------------

  Widget _header(BuildContext context, ColorScheme c) => Padding(
    padding: const EdgeInsets.fromLTRB(8, 12, 20, 0),
    child: Row(
      children: [
        if (!widget.embedded) ...[
          IconButton(
            onPressed: () => Navigator.maybePop(context),
            icon: const Icon(Icons.arrow_back),
          ),
          const SizedBox(width: 4),
        ] else
          const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Your favorite meals',
                style: AppTheme.titleBold.copyWith(
                  fontSize: 24,
                  color: c.onSurface,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'A little collection of good things',
                style: AppTheme.small.copyWith(color: c.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _filters(FavoritesState state, ColorScheme c) {
    Widget chip(String label, bool selected, VoidCallback onTap) => Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        selected: selected,
        label: Text(label),
        onSelected: (_) => onTap(),
        labelStyle: AppTheme.label.copyWith(
          color: selected ? c.onPrimary : c.onSurface,
        ),
        selectedColor: c.primary,
        backgroundColor: c.surface,
        side: BorderSide(color: selected ? c.primary : c.outline),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        ),
      ),
    );

    return Row(
      children: [
        chip(
          'All - ${state.meals.length}',
          _view == _FavoritesView.all,
          () => setState(() => _view = _FavoritesView.all),
        ),
        chip(
          'Grid',
          _view == _FavoritesView.grid,
          () => setState(() => _view = _FavoritesView.grid),
        ),
        chip(
          'List',
          _view == _FavoritesView.list,
          () => setState(() => _view = _FavoritesView.list),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Body
  // ---------------------------------------------------------------------------

  Widget _body(BuildContext context, FavoritesState state, ColorScheme c) {
    if (state.isLoading && state.meals.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.errorMessage != null && state.meals.isEmpty) {
      return _centered(
        c,
        icon: Icons.error_outline,
        title: state.errorMessage!,
        action: TextButton(
          onPressed: context.read<FavoritesCubit>().load,
          child: const Text('Try again'),
        ),
      );
    }

    if (state.meals.isEmpty) {
      return _centered(
        c,
        icon: Icons.favorite_border,
        title: 'No favorites yet',
        subtitle: 'Tap the heart on any recipe to save it here.',
      );
    }

    final meals = state.meals;

    if (_view == _FavoritesView.grid) {
      return CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverGrid.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: AppTheme.gridGap,
                crossAxisSpacing: AppTheme.gridGap,
                childAspectRatio: 0.82,
              ),
              itemCount: meals.length,
              itemBuilder: (_, i) => _GridCard(meal: meals[i]),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            sliver: SliverToBoxAdapter(child: _hint(c)),
          ),
        ],
      );
    }

    final featured = _view == _FavoritesView.all ? meals.first : null;
    final rest = featured == null ? meals : meals.skip(1).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      children: [
        if (featured != null) ...[
          _FeaturedCard(meal: featured),
          const SizedBox(height: AppTheme.gridGap),
        ],
        for (final meal in rest) ...[
          _MealTile(meal: meal),
          const SizedBox(height: AppTheme.gridGap),
        ],
        const SizedBox(height: 4),
        _hint(c),
      ],
    );
  }

  Widget _hint(ColorScheme c) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    decoration: BoxDecoration(
      color: c.primary.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(AppTheme.cardRadius),
    ),
    child: Row(
      children: [
        Icon(Icons.favorite_border, size: 20, color: c.onSurface),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            'Tap a filled heart to remove a favorite.',
            style: AppTheme.body.copyWith(color: c.onSurface),
          ),
        ),
      ],
    ),
  );

  Widget _centered(
    ColorScheme c, {
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? action,
  }) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: c.primary),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppTheme.label.copyWith(fontSize: 16, color: c.onSurface),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: AppTheme.body.copyWith(color: c.onSurfaceVariant),
            ),
          ],
          if (action != null) ...[const SizedBox(height: 8), action],
        ],
      ),
    ),
  );
}

// -----------------------------------------------------------------------------
// Shared helpers
// -----------------------------------------------------------------------------

String _meta(MealModel meal) => [meal.strCategory, meal.strArea]
    .whereType<String>()
    .map((v) => v.trim())
    .where((v) => v.isNotEmpty)
    .join(' - ');

void _openDetails(BuildContext context, MealModel meal) {
  Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => MealDetailsPage(meal: meal)),
  );
}

Future<void> _remove(BuildContext context, MealModel meal) async {
  final cubit = context.read<FavoritesCubit>();
  final ok = await cubit.toggle(meal);
  if (!context.mounted) return;

  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      content: Text(
        ok
            ? 'Removed ${meal.strMeal} from favorites'
            : (cubit.state.errorMessage ?? 'Could not update favorites.'),
      ),
      action: ok
          ? SnackBarAction(label: 'Undo', onPressed: () => cubit.toggle(meal))
          : null,
    ),
  );
}

class _Thumb extends StatelessWidget {
  final String url;
  final double? width;
  final double? height;
  final BorderRadius radius;

  const _Thumb({
    required this.url,
    required this.radius,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final placeholder = Container(
      width: width,
      height: height,
      color: c.surfaceContainerHighest,
      child: Icon(Icons.restaurant, color: c.onSurfaceVariant),
    );

    return ClipRRect(
      borderRadius: radius,
      child: url.isEmpty
          ? placeholder
          : Image.network(
              url,
              width: width,
              height: height,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => placeholder,
            ),
    );
  }
}

class _HeartButton extends StatelessWidget {
  final MealModel meal;
  const _HeartButton({required this.meal});

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: 'Remove from favorites',
    onPressed: () => _remove(context, meal),
    icon: const Icon(Icons.favorite, color: AppColors.heart, size: 28),
  );
}

// -----------------------------------------------------------------------------
// Cards
// -----------------------------------------------------------------------------

/// Big card used for the first meal in the "All" view.
class _FeaturedCard extends StatelessWidget {
  final MealModel meal;
  const _FeaturedCard({required this.meal});

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;

    return Material(
      color: c.surface,
      borderRadius: BorderRadius.circular(AppTheme.cardRadius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openDetails(context, meal),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Thumb(
              url: meal.strMealThumb,
              width: double.infinity,
              height: 150,
              radius: BorderRadius.zero,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
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
                          style: AppTheme.label.copyWith(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: c.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _meta(meal),
                          style: AppTheme.small.copyWith(
                            color: c.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _HeartButton(meal: meal),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact row used in the "All" (after the first) and "List" views.
class _MealTile extends StatelessWidget {
  final MealModel meal;
  const _MealTile({required this.meal});

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;

    return Material(
      color: c.surface,
      borderRadius: BorderRadius.circular(AppTheme.cardRadius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openDetails(context, meal),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              _Thumb(
                url: meal.strMealThumb,
                width: 76,
                height: 76,
                radius: BorderRadius.circular(AppTheme.smallRadius + 4),
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
                      style: AppTheme.label.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: c.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _meta(meal),
                      style: AppTheme.small.copyWith(color: c.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              _HeartButton(meal: meal),
            ],
          ),
        ),
      ),
    );
  }
}

/// Card used in the "Grid" view.
class _GridCard extends StatelessWidget {
  final MealModel meal;
  const _GridCard({required this.meal});

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;

    return Material(
      color: c.surface,
      borderRadius: BorderRadius.circular(AppTheme.cardRadius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openDetails(context, meal),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _Thumb(url: meal.strMealThumb, radius: BorderRadius.zero),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: c.surface.withValues(alpha: 0.85),
                        shape: BoxShape.circle,
                      ),
                      child: _HeartButton(meal: meal),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    meal.strMeal,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.label.copyWith(
                      fontWeight: FontWeight.w700,
                      color: c.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _meta(meal),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.small.copyWith(color: c.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
