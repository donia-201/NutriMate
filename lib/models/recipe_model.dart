class RecipeModel {
  final int id;
  final String title;
  final String image;
  final int calories;
  final String cuisine;
  final String category;
  final bool isFavorite;

  RecipeModel({
    required this.id,
    required this.title,
    required this.image,
    required this.calories,
    required this.cuisine,
    required this.category,
    this.isFavorite = false,
  });

  factory RecipeModel.fromSpoonacularJson(Map<String, dynamic> json) {
    int caloriesVal = 0;
    final nutrition = json['nutrition'];
    if (nutrition is Map) {
      final nutrients = nutrition['nutrients'];
      if (nutrients is List) {
        for (final value in nutrients.whereType<Map>()) {
          if (value['name']?.toString() == 'Calories') {
            final amount = value['amount'];
            if (amount is num) caloriesVal = amount.round();
            break;
          }
        }
      }
    }

    final cuisines = json['cuisines'];
    final dishTypes = json['dishTypes'];
    return RecipeModel(
      id: json['id'] is int ? json['id'] as int : 0,
      title: json['title']?.toString() ?? '',
      image: json['image']?.toString() ?? '',
      calories: caloriesVal,
      cuisine: cuisines is List && cuisines.isNotEmpty
          ? cuisines.first.toString()
          : 'International',
      category: dishTypes is List && dishTypes.isNotEmpty
          ? dishTypes.first.toString()
          : 'General',
    );
  }
}
