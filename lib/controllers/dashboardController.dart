import 'package:dio/dio.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import 'package:eal_scanner/models/dashboard.dart';
import 'package:eal_scanner/services/dioClient.dart';

/// Which window the home screen is reporting on.
enum DashboardPeriod { today, week, month }

/// Backs the home screen off a single `GET /dashboard` call.
///
/// The app writes straight to the server, so a failed fetch is a first-class
/// state here rather than a snackbar: [isOffline] drives the blocking
/// "No connection" screen.
class DashboardController extends GetxController {
  final isLoading = false.obs;
  final isRefreshing = false.obs;
  final isOffline = false.obs;
  final errorMessage = ''.obs;
  final period = DashboardPeriod.today.obs;
  final lastUpdated = Rxn<DateTime>();
  final data = Rxn<DashboardData>();

  static final DateFormat _apiDate = DateFormat('yyyy-MM-dd');

  String get periodLabel => switch (period.value) {
    DashboardPeriod.today => 'Today',
    DashboardPeriod.week => 'Last 7 days',
    DashboardPeriod.month => 'This month',
  };

  String get lastUpdatedLabel {
    final at = lastUpdated.value;
    if (at == null) return '—';
    return DateFormat('HH:mm').format(at);
  }

  ({DateTime start, DateTime end}) get _window {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return switch (period.value) {
      DashboardPeriod.today => (start: today, end: today),
      DashboardPeriod.week => (
        start: today.subtract(const Duration(days: 6)),
        end: today,
      ),
      DashboardPeriod.month => (
        start: DateTime(now.year, now.month, 1),
        end: today,
      ),
    };
  }

  @override
  void onInit() {
    super.onInit();
    fetch();
  }

  Future<void> setPeriod(DashboardPeriod next) async {
    if (period.value == next) return;
    period.value = next;
    await fetch();
  }

  /// [background] keeps the existing figures on screen and shows only the
  /// thin progress strip, which is what pull-to-refresh wants.
  Future<void> fetch({bool background = false}) async {
    if (isLoading.value || isRefreshing.value) return;

    if (background && data.value != null) {
      isRefreshing.value = true;
    } else {
      isLoading.value = true;
    }
    errorMessage.value = '';

    final window = _window;

    try {
      final response = await DioClient().dio.get(
        'dashboard',
        queryParameters: {
          'startDate': _apiDate.format(window.start),
          'endDate': _apiDate.format(window.end),
        },
        options: Options(extra: const {'silent': true}),
      );

      final body = response.data;
      if (body is Map) {
        data.value = DashboardData.fromJson(Map<String, dynamic>.from(body));
        lastUpdated.value = DateTime.now();
        isOffline.value = false;
      } else {
        errorMessage.value = 'The server sent an unexpected response.';
      }
    } on DioException catch (e) {
      if (_isConnectionFailure(e)) {
        isOffline.value = true;
      } else {
        errorMessage.value = _readableError(e);
      }
    } catch (_) {
      errorMessage.value = 'Could not load the overview.';
    } finally {
      isLoading.value = false;
      isRefreshing.value = false;
    }
  }

  /// Distinguishes "the network is gone" from "the server said no", because
  /// only the first one justifies blocking the whole screen.
  bool _isConnectionFailure(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionError:
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return true;
      case DioExceptionType.unknown:
        return e.response == null;
      default:
        return false;
    }
  }

  String _readableError(DioException e) {
    final body = e.response?.data;
    if (body is Map) {
      final message = body['error'] ?? body['message'];
      if (message != null) return message.toString();
    }
    return e.message ?? 'Could not load the overview.';
  }
}
