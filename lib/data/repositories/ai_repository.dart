import '../dataresource/ai_remote_darasource.dart';
import '../models/meal_analysis_request.dart';
import '../models/meal_analysis_result.dart';
import '../models/healthy_alternative.dart';

class AiRepository {
  final AiRemoteDataSource _dataSource;

  AiRepository({
    required AiRemoteDataSource dataSource,
  }) : _dataSource = dataSource;

  Future<MealAnalysisResult> analyzeMeal(
    MealAnalysisRequest request,
  ) {
    return _dataSource.analyzeMeal(request);
  }

  Future<List<HealthyAlternative>> findHealthyAlternatives(
    MealAnalysisRequest request,
  ) {
    return _dataSource.findHealthyAlternatives(request);
  }

  void dispose() {
  _dataSource.dispose();
}
}