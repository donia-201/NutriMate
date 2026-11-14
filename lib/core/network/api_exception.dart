import 'package:dio/dio.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;

  const ApiException({
    required this.message,
    this.statusCode,
  });

  factory ApiException.fromDio(DioException error) {
    String message;

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        message = 'Connection timed out. Please try again.';

      case DioExceptionType.connectionError:
        message = 'No internet connection.';

      case DioExceptionType.badResponse:
        message = 'Server error. Please try again later.';

      case DioExceptionType.cancel:
        message = 'Request was cancelled.';

      default:
        message = 'Something went wrong. Please try again.';
    }

    return ApiException(
      message: message,
      statusCode: error.response?.statusCode,
    );
  }

  @override
  String toString() => message;
}