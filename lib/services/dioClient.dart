// dio_client.dart
import 'package:dio/dio.dart';
import 'package:eal_scanner/services/authService.dart';
import 'package:get/get.dart';

// class DioInterceptor {
//   static Future<Dio> dioWithAuth() async {
//     final dio = Dio();

//     final authToken = AuthService.token; // You can modify this

//     dio.interceptors.add(
//       InterceptorsWrapper(
//         onRequest: (options, handler) {
//           if (authToken != null && authToken.isNotEmpty) {
//             options.headers['Authorization'] = 'Bearer $authToken';
//           }
//           return handler.next(options);
//         },
//       ),
//     );

//     return dio;
//   }
// }

class DioClient {
  static final DioClient _instance = DioClient._internal();
  factory DioClient() => _instance;
  final authToken = AuthService.token;

  late Dio dio;

  DioClient._internal() {
    dio = Dio(BaseOptions(
      baseUrl: 'https://boblte-eal-api.techpebble.com/api/v1/', // Replace with your base URL
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ));

    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        // Fetch token from storage or a service
        if (authToken != null && authToken!.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $authToken';
        }
        handler.next(options);
      },
      onError: (DioException e, handler) {
        Get.snackbar('Error', e.message ?? 'Something went wrong');
        return handler.next(e);
      },
    ));
  }

}
