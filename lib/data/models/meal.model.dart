class MealModel {
  final String idMeal;
  final String strMeal;
  final String? strCategory;
  final String? strArea;
  final String strMealThumb;
  final String? strInstructions;
  final String? strYoutube;
  final bool detailsLoaded;

  const MealModel({
    required this.idMeal,
    required this.strMeal,
    this.strCategory,
    this.strArea,
    required this.strMealThumb,
    this.strInstructions,
    this.strYoutube,
    this.detailsLoaded = false,
  });

  factory MealModel.fromJson(Map<String, dynamic> json) => MealModel(
    idMeal: (json['idMeal'] ?? '').toString(),
    strMeal: (json['strMeal'] ?? '').toString(),
    strCategory: json['strCategory']?.toString(),
    strArea: json['strArea']?.toString(),
    strMealThumb: (json['strMealThumb'] ?? '').toString(),
    strInstructions: json['strInstructions']?.toString(),
    strYoutube: json['strYoutube']?.toString(),
    detailsLoaded: json['strInstructions'] != null,
  );

  factory MealModel.fromFilterJson(Map<String, dynamic> json, {String? category}) => MealModel(
    idMeal: (json['idMeal'] ?? '').toString(),
    strMeal: (json['strMeal'] ?? '').toString(),
    strCategory: category ?? json['strCategory']?.toString(),
    strArea: json['strArea']?.toString(),
    strMealThumb: (json['strMealThumb'] ?? '').toString(),
  );

  factory MealModel.fromDbMap(Map<String, Object?> map) => MealModel(
    idMeal: (map['idMeal'] ?? '').toString(),
    strMeal: (map['strMeal'] ?? '').toString(),
    strCategory: map['strCategory']?.toString(),
    strArea: map['strArea']?.toString(),
    strMealThumb: (map['strMealThumb'] ?? '').toString(),
    strInstructions: map['strInstructions']?.toString(),
    strYoutube: map['strYoutube']?.toString(),
    detailsLoaded: (map['detailsLoaded'] as int? ?? 0) == 1,
  );

  Map<String, Object?> toDbMap() => {
    'idMeal': idMeal, 'strMeal': strMeal, 'strCategory': strCategory,
    'strArea': strArea, 'strMealThumb': strMealThumb,
    'strInstructions': strInstructions, 'strYoutube': strYoutube,
    'detailsLoaded': detailsLoaded ? 1 : 0,
  };

  MealModel mergeDetails(MealModel details) => MealModel(
    idMeal: idMeal,
    strMeal: details.strMeal.isNotEmpty ? details.strMeal : strMeal,
    strCategory: details.strCategory ?? strCategory,
    strArea: details.strArea ?? strArea,
    strMealThumb: details.strMealThumb.isNotEmpty ? details.strMealThumb : strMealThumb,
    strInstructions: details.strInstructions,
    strYoutube: details.strYoutube,
    detailsLoaded: details.detailsLoaded,
  );
}
