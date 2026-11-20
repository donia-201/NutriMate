import '../../data/models/healthy_alternative.dart';
import '../../data/models/meal_analysis_result.dart';

enum AiChatStatus {
  initial,
  loading,
  success,
  failure,
}

enum AiChatOperation {
  none,
  mealAnalysis,
  healthyAlternatives,
}

class AiChatState {
  final AiChatStatus status;
  final AiChatOperation operation;
  final MealAnalysisResult? analysisResult;
  final List<HealthyAlternative> alternatives;
  final String? errorMessage;

  const AiChatState({
    this.status = AiChatStatus.initial,
    this.operation = AiChatOperation.none,
    this.analysisResult,
    this.alternatives = const [],
    this.errorMessage,
  });

  AiChatState copyWith({
    AiChatStatus? status,
    AiChatOperation? operation,
    MealAnalysisResult? analysisResult,
    List<HealthyAlternative>? alternatives,
    String? errorMessage,
    bool clearAnalysis = false,
    bool clearAlternatives = false,
    bool clearError = false,
  }) {
    return AiChatState(
      status: status ?? this.status,
      operation: operation ?? this.operation,
      analysisResult:
          clearAnalysis ? null : analysisResult ?? this.analysisResult,
      alternatives:
          clearAlternatives ? [] : alternatives ?? this.alternatives,
      errorMessage:
          clearError ? null : errorMessage ?? this.errorMessage,
    );
  }

  bool get isLoading => status == AiChatStatus.loading;
}