import 'package:dio/dio.dart';
import 'package:get/get.dart';

import 'package:eal_scanner/models/eal_trace.dart';
import 'package:eal_scanner/services/dioClient.dart';
import 'package:eal_scanner/utils/api_error.dart';

/// Looks one label up, in two steps.
///
/// A serial is unique within a book, not across them: the same number can
/// sit in a 180ml book and a 1000ml one under the same prefix. So the
/// first request asks which books carry the number, the operator says
/// which one is in their hand, and the second request reads that book
/// alone. Reporting both at once put an issuance with nothing used above
/// a run that had drawn its labels from the other.
class FindEalController extends GetxController {
  final query = ''.obs;
  final isLoading = false.obs;
  final isOffline = false.obs;
  final errorMessage = ''.obs;
  final notFound = false.obs;

  /// The books that carry the number, for the operator to choose from.
  final books = <TraceIssuance>[].obs;

  /// True once a search has been run, so the screen can tell "nothing
  /// looked up yet" from "looked up, and there is nothing".
  final hasSearched = false.obs;

  bool get canSearch => RegExp(r'\d').hasMatch(query.value);

  void clear() {
    query.value = '';
    books.clear();
    errorMessage.value = '';
    notFound.value = false;
    hasSearched.value = false;
  }

  /// Which books carry the number. Returns the only one where there is
  /// only one, so the screen can go straight to it.
  Future<TraceIssuance?> search() async {
    final number = query.value.trim();
    if (number.isEmpty) return null;

    isLoading.value = true;
    errorMessage.value = '';
    notFound.value = false;
    isOffline.value = false;
    hasSearched.value = true;

    final outcome = await _request(number);

    isLoading.value = false;
    errorMessage.value = outcome.error;
    notFound.value = outcome.notFound;
    isOffline.value = outcome.isOffline;
    books.value = outcome.trace?.issuances ?? const [];

    return books.length == 1 ? books.first : null;
  }

  /// The label's story within one book.
  ///
  /// This one answers rather than publishing. The reading has a screen of
  /// its own, which keeps its own loading and error state: writing to the
  /// shared ones from there would mark the screen behind it dirty while
  /// the new one is still being built.
  Future<TraceOutcome> trace(TraceIssuance book) => _request(
    query.value.trim(),
    packId: book.packId.isEmpty ? null : book.packId,
  );

  Future<TraceOutcome> _request(String number, {String? packId}) async {
    try {
      final Dio dio = DioClient().dio;
      final res = await dio.get(
        'eal_usage/find',
        queryParameters: {
          'ealNumber': number,
          if (packId != null) 'pack': packId,
        },
        options: Options(
          // 404 is an answer here, not a failure: the number may belong to
          // another company, which this account cannot see.
          validateStatus: (status) => status != null && status < 500,
          extra: const {'silent': true},
        ),
      );

      if (res.statusCode == 200) {
        return TraceOutcome(
          trace: EalTrace.fromJson(res.data as Map<String, dynamic>),
          error: '',
          isOffline: false,
          notFound: false,
        );
      }

      if (res.statusCode == 404) {
        return const TraceOutcome(
          trace: null,
          error: '',
          isOffline: false,
          notFound: true,
        );
      }

      return TraceOutcome(
        trace: null,
        error: readableResponseError(res, 'Could not look that label up.'),
        isOffline: false,
        notFound: false,
      );
    } on DioException catch (e) {
      return TraceOutcome(
        trace: null,
        error: readableDioError(e, 'Could not look that label up.'),
        isOffline: isConnectionFailure(e),
        notFound: false,
      );
    } catch (_) {
      return const TraceOutcome(
        trace: null,
        error: 'Could not look that label up.',
        isOffline: false,
        notFound: false,
      );
    }
  }
}

/// What one reading came back as.
class TraceOutcome {
  const TraceOutcome({
    required this.trace,
    required this.error,
    required this.isOffline,
    required this.notFound,
  });

  final EalTrace? trace;
  final String error;
  final bool isOffline;
  final bool notFound;
}
