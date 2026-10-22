import 'package:dio/dio.dart';
import 'package:eal_scanner/config/api_config.dart';
import 'package:eal_scanner/utils/api_error.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

class AuthService {
  static final GetStorage _storage = GetStorage();
  static const String _tokenKey = 'auth_token';
  static const String _userKey = 'auth_user';

  static String? get token => _storage.read(_tokenKey);
  static Map<String, dynamic>? get user => _storage.read(_userKey);

  /// The role record the server sent with the login, where it sent one.
  static Map? get _role {
    final role = user?['role'];
    return role is Map ? role : null;
  }

  /// The role's name, whichever shape it arrived in. It was a word before
  /// roles became records on the server and is a record now, so a session
  /// saved under either has to read.
  static String get roleName {
    final role = user?['role'];
    if (role is Map) return (role['name'] ?? '').toString().trim();
    return role?.toString().trim() ?? '';
  }

  /// The unrestricted role. The server lets it do everything regardless of
  /// the list it carries, so the app has to agree.
  static bool get isSystemRole => _role?['isSystem'] == true;

  static Set<String> get permissions {
    final list = _role?['permissions'];
    if (list is! List) return const {};
    return list.map((e) => e.toString()).toSet();
  }

  /// Whether this session knows what the account may do. A login saved
  /// before roles became records carries only a word.
  static bool get knowsRole => isSystemRole || _role?['permissions'] is List;

  /// Whether to offer something. This grants nothing: the server re-reads
  /// the role on every request and refuses on its own. It only keeps a
  /// screen or a button from being offered to someone it would refuse.
  ///
  /// Unknown means yes. Hiding the whole app from a session whose shape we
  /// cannot read would be worse than offering a screen that then says no.
  static bool can(String key) {
    if (!knowsRole) return true;
    if (isSystemRole) return true;
    return permissions.contains(key);
  }

  /// Holding any one of these is enough, matching the server's `authorize`,
  /// which takes several keys and accepts the first that fits.
  static bool canAny(List<String> keys) => keys.any(can);

  /// Re-reads the account from the server.
  ///
  /// The role is cached from the login, and a token lasts a year — so an
  /// admin changing someone's role would otherwise never reach the app. The
  /// server already re-reads permissions per request; this keeps what the
  /// app offers in step with that.
  static Future<void> refreshUser() async {
    final authToken = token;
    if (authToken == null || authToken.isEmpty) return;

    try {
      final dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 8)));
      final response = await dio.get(
        ApiConfig.endpoint('auth/getUser'),
        options: Options(headers: {'Authorization': 'Bearer $authToken'}),
      );

      final data = response.data;
      if (response.statusCode == 200 && data is Map) {
        await _storage.write(_userKey, Map<String, dynamic>.from(data));
      }
    } catch (_) {
      // Nothing to do: the session stays as it was and the screens still
      // work, since the server is what actually decides.
    }
  }

  static bool validateCredentials(
    String email,
    String password,
    RxString message,
  ) {
    if (email.trim().isEmpty || password.trim().isEmpty) {
      message.value = 'Email and password cannot be empty';
      return false;
    }
    return true;
  }

  static Future<bool> login(
    String email,
    String password,
    RxString message,
  ) async {
    final Dio dio = Dio(
      BaseOptions(connectTimeout: const Duration(seconds: 5)),
    );
    final String url = ApiConfig.endpoint('auth/login');

    try {
      final response = await dio.post(
        url,
        data: {'email': email, 'password': password},
      );

      if (response.statusCode == 200) {
        await saveLoginSession(response.data);
        return true;
      } else {
        message.value = response.data['message'] ?? 'Login failed';
        return false;
      }
    } on DioException catch (e) {
      // This printed the whole DioException — status code, the advice to
      // "fix the server code", and a link to MDN — at whoever was trying
      // to sign in.
      message.value = readableDioError(e, 'Could not sign in. Try again.');
      return false;
    } catch (_) {
      message.value = 'Could not sign in. Try again.';
      return false;
    }
  }

  static Future<void> saveLoginSession(Map<String, dynamic> data) async {
    await _storage.write(_tokenKey, data['token']);
    await _storage.write(_userKey, data['user']);
  }

  /// Ends the session and nothing else.
  ///
  /// This erased the whole store, and the scanning preferences share it —
  /// so signing out, or a token the server stopped taking, also took the
  /// torch default, the scan feedback and the default prefix with it. Those
  /// belong to the phone and the person holding it, not to the session: an
  /// expired token should not leave someone in a dark bottling hall with
  /// the torch off.
  static Future<void> clearSession() async {
    await _storage.remove(_tokenKey);
    await _storage.remove(_userKey);
  }

  static bool isLoggedIn() {
    final token = _storage.read(_tokenKey);
    return token != null && token.toString().isNotEmpty;
  }
}
