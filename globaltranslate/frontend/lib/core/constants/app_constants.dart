class AppConstants {
  /// URL base da API. Em produção, definir via --dart-define=API_BASE_URL=...
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8000/api/v1',
  );

  /// Atraso da tradução em tempo real enquanto o utilizador escreve.
  static const Duration translateDebounce = Duration(milliseconds: 450);

  static const int maxTextLength = 10000;
}
