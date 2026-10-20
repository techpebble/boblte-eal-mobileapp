import 'package:dio/dio.dart';
import 'package:eal_scanner/config/api_config.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

class AuthService {
  static final GetStorage _storage = GetStorage();
  static const String _tokenKey = 'auth_token';
  static const String _userKey = 'auth_user';

  static String? get token => _storage.read(_tokenKey);
  static Map<String, dynamic>? get user => _storage.read(_userKey);

  static bool validateCredentials(String email, String password, RxString message) {
    if (email.trim().isEmpty || password.trim().isEmpty) {
      message.value = 'Email and password cannot be empty';
      return false;
    }
    return true;
  }

  static Future<bool> login(String email, String password, RxString message) async {
    final Dio dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 5)));
    final String url = ApiConfig.endpoint('auth/login');

    try {
      final response = await dio.post(url, data: {
        'email': email,
        'password': password,
      });

      if (response.statusCode == 200) {
        await saveLoginSession(response.data);
        return true;
      } else {
        message.value = response.data['message'] ?? 'Login failed';
        return false;
      }
    } catch (e) {
      message.value = 'Login error: $e';
      return false;
    }
  }

  static Future<void> saveLoginSession(Map<String, dynamic> data) async {
    await _storage.write(_tokenKey, data['token']);
    await _storage.write(_userKey, data['user']);
  }

  static Future<void> clearSession() async {
    await _storage.erase();
  }

  static bool isLoggedIn() {
    final token = _storage.read(_tokenKey);
    return token != null && token.toString().isNotEmpty;
  }

}
