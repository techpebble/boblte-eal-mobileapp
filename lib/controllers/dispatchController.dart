import 'package:dio/dio.dart';
import 'package:eal_scanner/models/dispatch.dart';
import 'package:eal_scanner/services/dioClient.dart';
import 'package:eal_scanner/utils/api_error.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

class DispatchController extends GetxController {
  Rx<DateTime> selectedDate = DateTime.now().obs;
  RxBool isLoading = false.obs;
  RxList<DispatchModel> dispatches = <DispatchModel>[].obs;
  RxString searchQuery = ''.obs;

  /// How many days the list covers, counting back from [selectedDate].
  RxInt rangeDays = 1.obs;

  /// Shown inline on the list rather than thrown as a snackbar.
  RxString errorMessage = ''.obs;

  /// `''` for all, `'short'` for notes still missing EAL links, otherwise a
  /// lifecycle stage. The API takes no status parameter, so this filters the
  /// day's records on the device.
  RxString statusFilter = ''.obs;

  /// A note is short while its linked case count is below its total. Matches
  /// the tolerance the backend uses when moving `final` to `loaded`.
  bool isShortOfLabels(DispatchModel d) => d.issuedQty + 1e-6 < d.totalQuantity;

  int get shortCount => dispatches.where(isShortOfLabels).length;

  List<DispatchModel> get filteredDispatches {
    final query = searchQuery.value.trim().toLowerCase();
    final status = statusFilter.value;

    return dispatches.where((d) {
      if (status == 'short' && !isShortOfLabels(d)) return false;
      if (status.isNotEmpty &&
          status != 'short' &&
          d.status.toLowerCase() != status) {
        return false;
      }

      if (query.isEmpty) return true;

      return d.depotName.toLowerCase().contains(query) ||
          d.companyName.toLowerCase().contains(query) ||
          d.vehicleNumber.toLowerCase().contains(query) ||
          d.driverName.toLowerCase().contains(query);
    }).toList();
  }

  void setStatusFilter(String value) {
    statusFilter.value = statusFilter.value == value ? '' : value;
  }

  void pickDate() async {
    DateTime? picked = await showDatePicker(
      context: Get.context!,
      initialDate: selectedDate.value,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      selectedDate.value = picked;
      rangeDays.value = 1;
      fetchDispatches();
    }
  }

  void setRange({required DateTime endDate, int days = 1}) {
    selectedDate.value = endDate;
    rangeDays.value = days;
    fetchDispatches();
  }

  void fetchDispatches() async {
    isLoading.value = true;
    errorMessage.value = '';

    final end = selectedDate.value;
    final start = end.subtract(
      Duration(days: (rangeDays.value - 1).clamp(0, 365)),
    );
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
