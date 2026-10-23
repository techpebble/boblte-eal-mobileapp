import 'package:eal_scanner/controllers/record_changes.dart';
import 'package:dio/dio.dart';
import 'package:eal_scanner/models/dispatch.dart';
import 'package:eal_scanner/models/dispatch_grouping.dart';
import 'package:eal_scanner/services/dioClient.dart';
import 'package:eal_scanner/utils/api_error.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

class DispatchController extends GetxController with StaleRecords {
  @override
  Future<void> refreshRecords() => fetchDispatches();

  /// The span the list covers, as on the other two lists. The server takes
  /// a start and an end, so a single day is a span where both are the same.
  Rx<DateTime> fromDate = _today().obs;
  Rx<DateTime> toDate = _today().obs;

  RxBool isLoading = false.obs;
  RxList<DispatchModel> dispatches = <DispatchModel>[].obs;

  /// Search stays here, unlike on issuance and production. A note is looked
  /// up by the depot it is going to, the vehicle at the gate or the driver
  /// asking for it, and none of those is something to narrow to from a
  /// sheet of what exists.
  RxString searchQuery = ''.obs;

  /// The two the list is grouped by, plus the depot it is going to and the
  /// stage it has reached.
  RxString filterCompany = ''.obs;
  RxString filterMarket = ''.obs;
  RxString filterDepot = ''.obs;

  /// Shown inline on the list rather than thrown as a snackbar.
  RxString errorMessage = ''.obs;

  /// Whether that failure was the network rather than the server. A lost
  /// connection is not an error the operator did anything about, and it
  /// gets its own state instead of a red banner.
  RxBool isOffline = false.obs;

  /// `''` for all, `'short'` for notes still missing EAL links, otherwise a
  /// lifecycle stage. The API takes no status parameter, so this filters the
  /// day's records on the device.
  RxString statusFilter = ''.obs;

  static DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  /// A note is short while its linked case count is below its total. Matches
  /// the tolerance the backend uses when moving `final` to `loaded`.
  bool isShortOfLabels(DispatchModel d) => d.issuedQty + 1e-6 < d.totalQuantity;

  int get shortCount => dispatches.where(isShortOfLabels).length;

  List<DispatchModel> get filteredDispatches {
    final query = searchQuery.value.trim().toLowerCase();
    final status = statusFilter.value;
    final company = filterCompany.value;
    final market = filterMarket.value;
    final depot = filterDepot.value;

    return dispatches.where((d) {
      if (status == 'short' && !isShortOfLabels(d)) return false;
      if (status.isNotEmpty &&
          status != 'short' &&
          d.status.toLowerCase() != status) {
        return false;
      }

      if (company.isNotEmpty && d.companyName != company) return false;
      if (market.isNotEmpty && d.market.toLowerCase() != market) return false;
      if (depot.isNotEmpty && d.depotName != depot) return false;

      if (query.isEmpty) return true;

      return d.depotName.toLowerCase().contains(query) ||
          d.companyName.toLowerCase().contains(query) ||
          d.vehicleNumber.toLowerCase().contains(query) ||
          d.driverName.toLowerCase().contains(query);
    }).toList();
  }

  /// What the list draws: the filtered notes, by company and market.
  List<DispatchGroup> get groupedDispatches =>
      groupDispatches(filteredDispatches);

  /// Options come from the notes on screen, so a filter can never be set to
  /// something there is nothing of.
  List<String> get companyOptions =>
      dispatches.map((d) => d.companyName).toSet().toList()
        ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

  List<String> get depotOptions =>
      dispatches.map((d) => d.depotName).toSet().toList()
        ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

  int get activeFilterCount => [
    filterCompany.value,
    filterMarket.value,
    filterDepot.value,
    statusFilter.value,
  ].where((f) => f.isNotEmpty).length;

  bool get hasFilters => activeFilterCount > 0;

  void clearFilters() {
    filterCompany.value = '';
    filterMarket.value = '';
    filterDepot.value = '';
    statusFilter.value = '';
  }

  /// The strip above the list shows what is on screen, so the totals follow
  /// the filters and the search.
  int get totalCases =>
      filteredDispatches.fold<int>(0, (sum, d) => sum + d.totalQuantity);

  int get totalShort => filteredDispatches.fold<int>(
    0,
    (sum, d) => sum + (d.totalQuantity - d.issuedQty).clamp(0, d.totalQuantity),
  );

  void setStatusFilter(String value) {
    statusFilter.value = statusFilter.value == value ? '' : value;
  }

  bool isPreset(int days) {
    final today = _today();
    return toDate.value == today &&
        fromDate.value == today.subtract(Duration(days: days - 1));
  }

  bool get isYesterday {
    final yesterday = _today().subtract(const Duration(days: 1));
    return fromDate.value == yesterday && toDate.value == yesterday;
  }

  bool get isSingleDay => fromDate.value == toDate.value;

  void setSpan(DateTime from, DateTime to) {
    final a = DateTime(from.year, from.month, from.day);
    final b = DateTime(to.year, to.month, to.day);
    fromDate.value = a.isAfter(b) ? b : a;
    toDate.value = a.isAfter(b) ? a : b;
    fetchDispatches();
  }

  void setLastDays(int days) {
    final today = _today();
    setSpan(today.subtract(Duration(days: days - 1)), today);
  }

  void setYesterday() {
    final yesterday = _today().subtract(const Duration(days: 1));
    setSpan(yesterday, yesterday);
  }

  Future<void> fetchDispatches() async {
    isStale.value = false;
    isLoading.value = true;
    errorMessage.value = '';
    isOffline.value = false;

    final start = fromDate.value;
    final end = toDate.value;
    final formatter = DateFormat('yyyy-MM-dd');
    final url =
        'dispatch?startDate=${formatter.format(start)}&endDate=${formatter.format(end)}';

    try {
      final Dio dio = DioClient().dio;

      final res = await dio.get(
        url,
        options: Options(extra: const {'silent': true}),
      );
      if (res.statusCode == 200) {
        dispatches.value = (res.data['data'] as List)
            .map((e) => DispatchModel.fromJson(e))
            .toList();
      } else {
        errorMessage.value = 'Could not load dispatches.';
      }
    } on DioException catch (e) {
      isOffline.value = isConnectionFailure(e);
      errorMessage.value = readableDioError(e, 'Could not load dispatches.');
    } catch (_) {
      errorMessage.value = 'Could not load dispatches.';
    } finally {
      isLoading.value = false;
    }
  }

  /// Links a serial range to a dispatch line. Returns null on success,
  /// otherwise the server's own wording — it rejects overlapping ranges and
  /// over-linking with messages worth reading verbatim.
  Future<String?> submitEALLink({
    required String dispatchId,
    required String itemId,
    required String prefix,
    required String serialFrom,
    required String serialTo,

    /// Typed rather than scanned. The record keeps it, and a role without
    /// scan:manual is refused: a transposed digit reads as a real label.
    bool enteredByHand = false,
  }) async {
    isLoading.value = true;

    final data = {
      "dispatchId": dispatchId,
      "itemId": itemId,
      "prefix": prefix.toUpperCase(),
      "serialFrom": serialFrom,
      "serialTo": serialTo,
      "enteredByHand": enteredByHand,
    };

    try {
      final Dio dio = DioClient().dio;

      final res = await dio.post(
        'dispatch/eal/add_eal_link',
        data: data,
        options: Options(
          validateStatus: (status) =>
              status != null && status < 500, // Accept 400-499
          extra: const {'silent': true},
        ),
      );
      if (res.statusCode == 200) {
        final dispatchIndex = dispatches.indexWhere((d) => d.id == dispatchId);
        if (dispatchIndex != -1 && res.data['updatedDispatch'] != null) {
          // Re-assigning is what triggers the Obx rebuild.
          dispatches[dispatchIndex] = DispatchModel.fromJson(
            res.data['updatedDispatch'],
          );
        }

        // Linking a range moves the production run's waiting count, which
        // is read on another tab.
        recordsChanged();
        return null;
      }

      return readableResponseError(
        res,
        'The server would not link this range.',
      );
    } on DioException catch (e) {
      return readableDioError(e, 'Could not link this range.');
    } catch (_) {
      return 'Could not link this range.';
    } finally {
      isLoading.value = false;
    }
  }

  /// Updates vehicle, driver and stage. Returns null on success, otherwise
  /// the server's message — it refuses a stage that skips ahead, and refuses
  /// `loaded` outright while any line is short of EAL links.
  Future<String?> updateVehicleDetails({
    required String dispatchId,
    required String vehicleNumber,
    required String driverName,
    required String driverContact,
    required String status,
  }) async {
    isLoading.value = true;

    final data = {
      "vehicleNumber": vehicleNumber,
      "driverName": driverName,
      "driverContact": driverContact,
      "status": status,
    };

    try {
      final Dio dio = DioClient().dio;
      final res = await dio.put(
        'dispatch/$dispatchId/vehicle',
        data: data,
        options: Options(
          validateStatus: (status) =>
              status != null && status < 500, // Accept 400-499
          extra: const {'silent': true},
        ),
      );

      if (res.statusCode == 200) {
        final dispatchIndex = dispatches.indexWhere((d) => d.id == dispatchId);
        if (dispatchIndex != -1) {
          dispatches[dispatchIndex] = dispatches[dispatchIndex].copyWith(
            vehicleNumber: vehicleNumber,
            driverName: driverName,
            driverContact: driverContact,
            status: status,
          );
        }

        recordsChanged();
        return null;
      }

      return readableResponseError(
        res,
        'The server would not accept this update.',
      );
    } on DioException catch (e) {
      return readableDioError(e, 'Could not update this dispatch.');
    } catch (_) {
      return 'Could not update this dispatch.';
    } finally {
      isLoading.value = false;
    }
  }

  /// Unlinks a range, returning those labels to the production pool.
  /// Returns null on success, otherwise the server's message.
  Future<String?> removeEALLink({
    required String dispatchId,
    required String itemId,
    required String prefix,
    required String serialFrom,
    required String serialTo,
  }) async {
    isLoading.value = true;

    final data = {
      "dispatchId": dispatchId,
      "itemId": itemId,
      "prefix": prefix.toUpperCase(),
      "serialFrom": serialFrom,
      "serialTo": serialTo,
    };

    try {
      final Dio dio = DioClient().dio;

      final res = await dio.post(
        'dispatch/eal/remove_eal_link',
        data: data,
        options: Options(
          validateStatus: (status) =>
              status != null && status < 500, // Accept 400-499
          extra: const {'silent': true},
        ),
      );

      if (res.statusCode == 200) {
        final dispatchIndex = dispatches.indexWhere((d) => d.id == dispatchId);
        if (dispatchIndex != -1 && res.data['updatedDispatch'] != null) {
          dispatches[dispatchIndex] = DispatchModel.fromJson(
            res.data['updatedDispatch'],
          );
        }
        recordsChanged();
        return null;
      }

      return readableResponseError(
        res,
        'The server would not unlink this range.',
      );
    } on DioException catch (e) {
      return readableDioError(e, 'Could not unlink this range.');
    } catch (_) {
      return 'Could not unlink this range.';
    } finally {
      isLoading.value = false;
    }
  }

  // Utility function to get color based on status
  Color getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'draft':
        return Colors.grey.shade100;
      case 'final':
        return Colors.orange.shade100;
      case 'loaded':
        return Colors.blue.shade100;
      case 'dispatched':
        return Colors.teal.shade100;
      case 'delivered':
        return Colors.green.shade100;
      default:
        return Colors.purple.shade50;
    }
  }

  Color getStatusChipColor(String status) {
    switch (status.toLowerCase()) {
      case 'draft':
        return Colors.grey;
      case 'final':
        return Colors.orange;
      case 'loaded':
        return Colors.blue;
      case 'dispatched':
        return Colors.teal;
      case 'delivered':
        return Colors.green;
      default:
        return Colors.purple;
    }
  }
}
