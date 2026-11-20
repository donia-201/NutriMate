import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/network/api_exception.dart';
import '../../data/models/meal_analysis_request.dart';
import '../../data/repositories/ai_repository.dart';
import 'ai_chat_state.dart';

class AiChatCubit extends Cubit<AiChatState> {
  AiChatCubit({required this._repository})
    : super(const AiChatState());

  final AiRepository _repository;

  int _requestGeneration = 0;

  Future<void> analyzeMeal(MealAnalysisRequest request) async {
    final generation = ++_requestGeneration;

    emit(
      state.copyWith(
        status: AiChatStatus.loading,
        operation: AiChatOperation.mealAnalysis,
        clearAnalysis: true,
        clearAlternatives: true,
        clearError: true,
      ),
    );

    try {
      final result = await _repository.analyzeMeal(request);

      if (isClosed || generation != _requestGeneration) return;

      emit(
        state.copyWith(status: AiChatStatus.success, analysisResult: result),
      );
    } on DioException catch (error) {
      _emitError(generation, ApiException.fromDio(error).message);
    } on ApiException catch (error) {
      _emitError(generation, error.message);
    } on FormatException catch (error) {
      _emitError(generation, error.message);
    } catch (_) {
      _emitError(generation, 'Could not analyze this meal. Please try again.');
    }
  }

  Future<void> findHealthyAlternatives(MealAnalysisRequest request) async {
    final generation = ++_requestGeneration;

    emit(
      state.copyWith(
        status: AiChatStatus.loading,
        operation: AiChatOperation.healthyAlternatives,
        clearAnalysis: true,
        clearAlternatives: true,
        clearError: true,
      ),
    );

    try {
      final alternatives = await _repository.findHealthyAlternatives(request);

      if (isClosed || generation != _requestGeneration) return;

      emit(
        state.copyWith(
          status: AiChatStatus.success,
          alternatives: alternatives,
        ),
      );
    } on DioException catch (error) {
      _emitError(generation, ApiException.fromDio(error).message);
    } on ApiException catch (error) {
      _emitError(generation, error.message);
    } on FormatException catch (error) {
      _emitError(generation, error.message);
    } catch (_) {
      _emitError(generation, 'Could not find alternatives. Please try again.');
    }
  }

  void _emitError(int generation, String message) {
    if (isClosed || generation != _requestGeneration) return;

    emit(state.copyWith(status: AiChatStatus.failure, errorMessage: message));
  }

  void reset() {
    _requestGeneration++;
    emit(const AiChatState());
  }

  @override
  Future<void> close() {
    _requestGeneration++;
    _repository.dispose();

    return super.close();
  }
}
