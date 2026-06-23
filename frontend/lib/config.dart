/// Runtime configuration via `--dart-define`.
///
/// ```bash
/// flutter run \
///   --dart-define=API_BASE_URL=http://localhost:8080 \
///   --dart-define=MARKETPLACE_BASE_URL=http://localhost:8081 \
///   --dart-define=API_KEY=your-secret-key \
///   --dart-define=FIREBASE_WEB_API_KEY=your-firebase-web-api-key
/// ```
class AppConfig {
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8080',
  );

  static const String marketplaceBaseUrl = String.fromEnvironment(
    'MARKETPLACE_BASE_URL',
    defaultValue: 'http://localhost:8081',
  );

  static const String apiKey = String.fromEnvironment(
    'API_KEY',
    defaultValue: '',
  );

  static bool get hasApiKey => apiKey.isNotEmpty;

  static const String firebaseWebApiKey = String.fromEnvironment(
    'FIREBASE_WEB_API_KEY',
    defaultValue: '',
  );

  static bool get hasFirebaseWebApiKey => firebaseWebApiKey.isNotEmpty;
}
