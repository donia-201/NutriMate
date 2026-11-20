
class AiApiConfig {
  AiApiConfig._();

  static const String _configuredBaseUrl = String.fromEnvironment(
    'AI_API_BASE_URL',
    defaultValue: 'https://nutrimate-production.up.railway.app/',
  );

  static String get baseUrl {
    final value = _configuredBaseUrl.trim();
    if (value.isEmpty) return '';
    return value.endsWith('/') ? value : '$value/';
  }

  static const String mealAnalysisPath = 'api/ai/meal-analysis';
  static const String healthyAlternativesPath =
      'api/ai/healthy-alternatives';

  static bool get isConfigured {
    final uri = Uri.tryParse(baseUrl);
    return uri != null &&
        (uri.scheme == 'https' || uri.scheme == 'http') &&
        uri.host.isNotEmpty;
  }
}
