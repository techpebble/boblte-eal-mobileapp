/// What this build tells the server about itself.
///
/// The server refuses a build older than its minimum, so that a handset
/// somebody forgot to update cannot keep writing records against rules it
/// does not know about. A request carrying no version at all is read the same
/// way: no app released before that gate existed sent one.
///
/// [build] has to match the `+N` half of `version:` in pubspec.yaml.
/// `test/app_version_test.dart` fails if the two drift apart, because the
/// number the server checks would otherwise quietly stop matching the number
/// the APK was built as.
class AppVersion {
  const AppVersion._();

  /// The `+N` half of pubspec's `version:`.
  static const int build = 3;

  /// The `1.0.2` half, for the About page.
  static const String name = '1.0.2';

  /// Carried by every request, including sign-in — an operator should learn
  /// their app is out of date at the sign-in screen, not halfway through a
  /// scan.
  static Map<String, String> get headers => {
    'X-App-Version': '$build',
    'X-Client': 'mobile',
  };

  /// The same, with a bearer token alongside, for the two calls made outside
  /// [DioClient].
  static Map<String, String> headersWithToken(String token) => {
    ...headers,
    'Authorization': 'Bearer $token',
  };
}
