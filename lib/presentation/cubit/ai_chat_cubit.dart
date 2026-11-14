import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/network/api_exception.dart';
import '../../data/models/meal_analysis_request.dart';
import '../../data/repositories/ai_repository.dart';
import 'ai_chat_state.dart';

class AiChatCubit extends Cubit<AiChatState> {
  AiChatCubit({
    required AiRepository repository,
  })  : _repository = repository,
        super(const AiChatState());

  final AiRepository _repository;

  Future<void> analyzeMeal(
    MealAnalysisRequest request,
  ) async {
    emit(state.copyWith(
      status: AiChatStatus.loading,
      operation: AiChatOperation.mealAnalysis,
      clearAnalysis: true,
      clearAlternatives: true,
      clearError: true,
    ));

    try {
      final result = await _repository.analyzeMeal(request);

      emit(state.copyWith(
        status: AiChatStatus.success,
        analysisResult: result,
      ));
    } on DioException catch (error) {
      _emitError(ApiException.fromDio(error).message);
    } on ApiException catch (error) {
      _emitError(error.message);
    } on FormatException catch (error) {
      _emitError(error.message);
    } catch (_) {
      _emitError('Could not analyze this meal. Please try again.');
    }
  }

  Future<void> findHealthyAlternatives(
    MealAnalysisRequest request,
  ) async {
    emit(state.copyWith(
      status: AiChatStatus.loading,
      operation: AiChatOperation.healthyAlternatives,
      clearAnalysis: true,
      clearAlternatives: true,
      clearError: true,
    ));

    try {
      final alternatives =
          await _repository.findHealthyAlternatives(request);

      emit(state.copyWith(
        status: AiChatStatus.success,
        alternatives: alternatives,
      ));
    } on DioException catch (error) {
      _emitError(ApiException.fromDio(error).message);
    } on ApiException catch (error) {
      _emitError(error.message);
    } on FormatException catch (error) {
      _emitError(error.message);
    } catch (_) {
      _emitError(
        'Could not find alternatives. Please try again.',
      );
    }
  }

  void _emitError(String message) {
    emit(state.copyWith(
      status: AiChatStatus.failure,
      errorMessage: message,
    ));
  }

  void reset() {
    emit(const AiChatState());
  }

  @override
  Future<void> close() {
    _repository.dispose();
    return super.close();
  }
}