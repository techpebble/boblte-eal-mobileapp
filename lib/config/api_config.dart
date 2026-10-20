/// Which server the app talks to.
///
/// The default is the live API. A test build points somewhere else at build
/// time, without editing any code:
///
/// ```sh
/// flutter build apk --dart-define=EAL_API_BASE_URL=http://192.168.1.7:8000/api/v1/
/// ```
///
/// The URL lived in two places before this: `DioClient` and, separately,
/// the login call in `AuthService`. Pointing one at a test server would have
/// left sign-in going to the live one.
class ApiConfig {
  const ApiConfig._();

  static const String productionBaseUrl =
      'https://boblte-eal-api.techpebble.com/api/v1/';

  /// Always ends with a slash, so paths resolve against it cleanly.
  static const String baseUrl = String.fromEnvironment(
    'EAL_API_BASE_URL',
    defaultValue: productionBaseUrl,
  );

  static bool get isProduction => baseUrl == productionBaseUrl;

  /// Host and port only, for the sign-in and account screens. A tester
  /// should never have to wonder which server they are writing to.
  static String get label {
    final uri = Uri.tryParse(baseUrl);
    if (uri == null || uri.host.isEmpty) return baseUrl;
    return uri.hasPort ? '${uri.host}:${uri.port}' : uri.host;
  }

  /// Absolute URL for a path, for the one call made outside [DioClient].
  static String endpoint(String path) =>
      Uri.parse(baseUrl).resolve(path).toString();
}
