import 'package:dio/dio.dart';
import 'package:eal_scanner/config/api_config.dart';
import 'package:eal_scanner/screens/login.dart';
import 'package:eal_scanner/services/authService.dart';
import 'package:eal_scanner/utils/api_error.dart';
import 'package:get/get.dart';

class DioClient {
  static final DioClient _instance = DioClient._internal();
  factory DioClient() => _instance;

  late Dio dio;

  DioClient._internal() {
    dio = Dio(
      BaseOptions(
        baseUrl: ApiConfig.baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
      ),
    );

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final authToken = AuthService.token;
          if (authToken != null && authToken.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $authToken';
          } else {
            options.headers.remove('Authorization');
          }
          handler.next(options);
        },
        onError: (DioException e, handler) {
          if (endsTheSession(e)) {
            _endSession(e);
            return handler.next(e);
          }

          // Screens that present their own inline error state opt out of the
          // global snackbar by setting `extra: {'silent': true}` on the
          // request, so a failure is reported once rather than twice.
          if (e.requestOptions.extra['silent'] != true) {
            // The server's own sentence, not Dio's: the API answers a
            // refusal with wording written for this app, and "invalid
            // status code of 403" tells an operator nothing.
            Get.snackbar('Error', readableDioError(e, 'Something went wrong'));
          }
          return handler.next(e);
        },
      ),
    );
  }

  /// True once the session has been ended, so a screenful of requests
  /// failing together sends the operator to sign-in once rather than five
  /// times over.
  static bool _ending = false;

  static Future<void> _endSession(DioException e) async {
    if (_ending) return;
    _ending = true;

    await AuthService.clearSession();

    final body = e.response?.data;
    final said = body is Map ? body['message']?.toString() : null;

    Get.offAll(() => const LoginScreen());
    Get.snackbar(
      'Signed out',
      said != null && said.trim().isNotEmpty
          ? said
          : 'Your session has ended. Sign in again to continue.',
    );

    _ending = false;
  }
}
