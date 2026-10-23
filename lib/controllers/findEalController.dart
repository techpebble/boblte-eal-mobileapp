import 'package:dio/dio.dart';
import 'package:get/get.dart';

import 'package:eal_scanner/models/eal_trace.dart';
import 'package:eal_scanner/services/dioClient.dart';
import 'package:eal_scanner/utils/api_error.dart';

/// Looks one label up and holds what came back.
///
/// The server takes the number with or without its prefix, so whatever is
/// typed or scanned goes straight through; what it cannot take is an empty
/// query, which is why nothing is sent until there are digits.
class FindEalController extends GetxController {
  final query = ''.obs;
  final isLoading = false.obs;
  final isOffline = false.obs;
  final errorMessage = ''.obs;
  final notFound = false.obs;
  final result = Rxn<EalTrace>();

  /// True once a search has been run, so the screen can tell "nothing
  /// looked up yet" from "looked up, and there is nothing".
  final hasSearched = false.obs;

  bool get canSearch => RegExp(r'\d').hasMatch(query.value);

  void clear() {
    query.value = '';
    result.value = null;
    errorMessage.value = '';
    notFound.value = false;
    hasSearched.value = false;
  }

  Future<void> search() async {
    final number = query.value.trim();
    if (number.isEmpty) return;

    isLoading.value = true;
    errorMessage.value = '';
    notFound.value = false;
    isOffline.value = false;
    hasSearched.value = true;

    try {
      final Dio dio = DioClient().dio;
      final res = await dio.get(
        'eal_usage/find',
        queryParameters: {'ealNumber': number},
        options: Options(
          // 404 is an answer here, not a failure: the number may belong to
          // another company, which this account cannot see.
          validateStatus: (status) => status != null && status < 500,
          extra: const {'silent': true},
        ),
      );

      if (res.statusCode == 200) {
        result.value = EalTrace.fromJson(res.data as Map<String, dynamic>);
        return;
      }

      result.value = null;

      if (res.statusCode == 404) {
        notFound.value = true;
        return;
      }

      errorMessage.value = readableResponseError(
        res,
        'Could not look that label up.',
      );
    } on DioException catch (e) {
      result.value = null;
      isOffline.value = isConnectionFailure(e);
      errorMessage.value = readableDioError(e, 'Could not look that label up.');
    } catch (_) {
      result.value = null;
      errorMessage.value = 'Could not look that label up.';
    } finally {
      isLoading.value = false;
    }
  }
}
