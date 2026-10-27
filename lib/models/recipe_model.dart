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
    if (json['nutrition'] != null && json['nutrition']['nutrients'] != null) {
      var caloriesNutrient = (json['nutrition']['nutrients'] as List).firstWhere(
        (element) => element['name'] == 'Calories',
        orElse: () => null,
      );
      if (caloriesNutrient != null) {
        caloriesVal = (caloriesNutrient['amount'] as num).round();
      }
    }

    return RecipeModel(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      image: json['image'] ?? '',
      calories: caloriesVal,
      cuisine: (json['cuisines'] != null && (json['cuisines'] as List).isNotEmpty)
          ? json['cuisines'][0]
          : 'International',
      category: (json['dishTypes'] != null && (json['dishTypes'] as List).isNotEmpty)
          ? json['dishTypes'][0]
          : 'General',
    );
  }
}