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
  final books = <TraceBook>[].obs;

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

  /// Looks the number up.
  ///
  /// The server settles the choice where it can: one book holding the
  /// serial and it traces that one, several and it answers needsChoice
  /// with the candidates. So a search is one request, and the reading
  /// comes back with it where there was nothing to ask.
  Future<TraceOutcome> search() async {
    final number = query.value.trim();
    if (number.isEmpty) {
      return const TraceOutcome(
        trace: null,
        error: '',
        isOffline: false,
        notFound: false,
      );
    }

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
    books.value = outcome.trace?.candidates ?? const [];

    return outcome;
  }

  /// The label's story within one book, once the operator has said which.
  ///
  /// This one answers rather than publishing. The reading has a screen of
  /// its own, which keeps its own loading and error state: writing to the
  /// shared ones from there would mark the screen behind it dirty while
  /// the new one is still being built.
  Future<TraceOutcome> trace(TraceBook book) =>
      _request(query.value.trim(), issuanceId: book.id);

  Future<TraceOutcome> _request(String number, {String? issuanceId}) async {
    try {
      final Dio dio = DioClient().dio;
      final res = await dio.get(
        'eal_usage/find',
        queryParameters: {
          'ealNumber': number,
          // Which book, where the operator has said. The server takes the
          // issuance itself rather than a pack: two books of the same
          // pack size can hold the same serial.
          if (issuanceId != null) 'issuanceId': issuanceId,
        },
        options: Options(
          // 404 is an answer here, not a failure: the number may belong to
          // another company, which this account cannot see.
          validateStatus: (status) => status != null && status < 500,
          extra: const {'silent': true},
        ),
      );

      if (res.statusCode == 200) {
        final trace = EalTrace.fromJson(res.data as Map<String, dynamic>);

        // A 200 that carries neither a book nor a choice is an answer
        // this app cannot use. Reading it as "nothing yet" left the
        // button looking broken: pressed, and the page unchanged.
        if (!trace.needsChoice && trace.book == null) {
          return TraceOutcome(
            trace: null,
            error:
                'The answer could not be read: it named no book and no '
                'choice between books.',
            isOffline: false,
            notFound: false,
          );
        }

        return TraceOutcome(
          trace: trace,
          error: '',
          isOffline: false,
          notFound: false,
        );
      }

      if (res.statusCode == 404) {
        // The server says which prefix and serial it could not place.
        return TraceOutcome(
          trace: null,
          error: readableResponseError(res, ''),
          isOffline: false,
          notFound: true,
        );
      }

      // The status, where the body says nothing. "Could not look that
      // label up" named neither what was asked nor what came back, so
      // there was nothing for anyone to act on.
      return TraceOutcome(
        trace: null,
        error: readableResponseError(
          res,
          'The server answered ${res.statusCode} and said nothing more.',
        ),
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
    } catch (error) {
      // Anything else is the answer not being what this app expects —
      // a record shaped differently from the rest. Naming it is the
      // difference between a bug report and a shrug.
      return TraceOutcome(
        trace: null,
        error: 'The answer could not be read: $error',
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
