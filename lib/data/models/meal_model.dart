class MealIngredient {
  final String name;
  final String measure;

  const MealIngredient({
    required this.name,
    required this.measure,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'measure': measure,
  };
}

class MealModel {
  final String idMeal;
  final String strMeal;
  final String? strCategory;
  final String? strArea;
  final String strMealThumb;
  final String? strInstructions;
  final String? strYoutube;
  final bool detailsLoaded;
  final List<MealIngredient> ingredients;

  const MealModel({
    required this.idMeal,
    required this.strMeal,
    this.strCategory,
    this.strArea,
    required this.strMealThumb,
    this.strInstructions,
    this.strYoutube,
    this.detailsLoaded = false,
    this.ingredients = const [],
  });

  // Cleans optional text:
  // null, empty string, or whitespace-only string -> null
  static String? _optionalText(Object? value) {
    if (value == null) return null;

    final text = value.toString().trim();

    return text.isEmpty ? null : text;
  }

  factory MealModel.fromJson(Map<String, dynamic> json) {
    final ingredients = <MealIngredient>[];

    for (var i = 1; i <= 20; i++) {
      final name = (json['strIngredient$i'] ?? '').toString().trim();
      final measure = (json['strMeasure$i'] ?? '').toString().trim();

      if (name.isNotEmpty) {
        ingredients.add(
          MealIngredient(
            name: name,
            measure: measure,
          ),
        );
      }
    }

    final instructions = _optionalText(json['strInstructions']);

    return MealModel(
      idMeal: (json['idMeal'] ?? '').toString(),
      strMeal: (json['strMeal'] ?? '').toString(),
      strCategory: _optionalText(json['strCategory']),
      strArea: _optionalText(json['strArea']),
      strMealThumb: (json['strMealThumb'] ?? '').toString(),
      strInstructions: instructions,
      strYoutube: _optionalText(json['strYoutube']),

      // مهم:
      // التفاصيل تعتبر loaded فقط لو instructions فيها نص فعلي.
      detailsLoaded: instructions != null,

      ingredients: ingredients,
    );
  }

  factory MealModel.fromFilterJson(
      Map<String, dynamic> json, {
        String? category,
        String? area,
      }) =>
      MealModel(
        idMeal: (json['idMeal'] ?? '').toString(),
        strMeal: (json['strMeal'] ?? '').toString(),
        strCategory: _optionalText(category ?? json['strCategory']),
        strArea: _optionalText(area ?? json['strArea']),
        strMealThumb: (json['strMealThumb'] ?? '').toString(),
      );

  factory MealModel.fromDbMap(Map<String, Object?> map) => MealModel(
    idMeal: (map['idMeal'] ?? '').toString(),
    strMeal: (map['strMeal'] ?? '').toString(),
    strCategory: _optionalText(map['strCategory']),
    strArea: _optionalText(map['strArea']),
    strMealThumb: (map['strMealThumb'] ?? '').toString(),
    strInstructions: _optionalText(map['strInstructions']),
    strYoutube: _optionalText(map['strYoutube']),
    detailsLoaded: (map['detailsLoaded'] as int? ?? 0) == 1,
  );

  Map<String, Object?> toDbMap() => {
    'idMeal': idMeal,
    'strMeal': strMeal,
    'strCategory': strCategory,
    'strArea': strArea,
    'strMealThumb': strMealThumb,
    'strInstructions': strInstructions,
    'strYoutube': strYoutube,
    'detailsLoaded': detailsLoaded ? 1 : 0,
  };

  MealModel mergeDetails(MealModel details) => MealModel(
    idMeal: idMeal,
    strMeal: details.strMeal.isNotEmpty ? details.strMeal : strMeal,
    strCategory: details.strCategory ?? strCategory,
    strArea: details.strArea ?? strArea,
    strMealThumb: details.strMealThumb.isNotEmpty
        ? details.strMealThumb
        : strMealThumb,
    strInstructions: details.strInstructions,
    strYoutube: details.strYoutube,
    detailsLoaded: details.detailsLoaded,
    ingredients: details.ingredients.isNotEmpty
        ? details.ingredients
        : ingredients,
  );
}