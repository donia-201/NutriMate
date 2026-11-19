import 'package:dio/dio.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;

  const ApiException({required this.message, this.statusCode});

  factory ApiException.fromDio(DioException error) {
    final statusCode = error.response?.statusCode;
    final responseData = error.response?.data;
    String? serverMessage;

    if (responseData is Map) {
      final rawError = responseData['error'];
      final nestedErrorMessage =
          rawError is Map ? rawError['message'] : null;
      final rawMessage = responseData['message'] ??
          nestedErrorMessage ??
          (rawError is String ? rawError : null);
      if (rawMessage != null) serverMessage = rawMessage.toString();
    }

    final message = switch (error.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout =>
        'The request timed out. Please try again.',
      DioExceptionType.connectionError => 'No internet connection.',
      DioExceptionType.cancel => 'The request was cancelled.',
      DioExceptionType.badResponse =>
        serverMessage?.isNotEmpty == true
            ? serverMessage!
            : _statusMessage(statusCode),
      _ => 'Something went wrong. Please try again.',
    };

    return ApiException(message: message, statusCode: statusCode);
  }

  static String _statusMessage(int? statusCode) {
    if (statusCode == 400 || statusCode == 422) {
      return 'Please check the submitted information and try again.';
    }
    if (statusCode == 401 || statusCode == 403) {
      return 'You are not authorized to use this service.';
    }
    if (statusCode == 404) return 'The requested AI service was not found.';
    if (statusCode == 429) {
      return 'The AI service is busy. Please try again shortly.';
    }
    if (statusCode != null && statusCode >= 500) {
      return 'The AI server is temporarily unavailable.';
    }
    return 'The server could not complete your request.';
  }

  @override
  String toString() => message;
}
