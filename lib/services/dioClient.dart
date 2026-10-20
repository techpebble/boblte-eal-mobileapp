import 'package:dio/dio.dart';
import 'package:eal_scanner/services/authService.dart';
import 'package:get/get.dart';

class DioClient {
  static final DioClient _instance = DioClient._internal();
  factory DioClient() => _instance;

  late Dio dio;

  DioClient._internal() {
    dio = Dio(
      BaseOptions(
        baseUrl:
            'https://boblte-eal-api.techpebble.com/api/v1/', // Replace with your base URL
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
          Get.snackbar('Error', e.message ?? 'Something went wrong');
          return handler.next(e);
        },
      ),
    );
  }
}
