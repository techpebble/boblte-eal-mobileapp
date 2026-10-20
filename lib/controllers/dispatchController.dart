import 'package:dio/dio.dart';
import 'package:eal_scanner/models/dispatch.dart';
import 'package:eal_scanner/services/dioClient.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

class DispatchController extends GetxController {
  Rx<DateTime> selectedDate = DateTime.now().obs;
  RxBool isLoading = false.obs;
  RxList<DispatchModel> dispatches = <DispatchModel>[].obs;
  RxString searchQuery = ''.obs;

  RxList<DispatchModel> get filteredDispatches {
    final query = searchQuery.value.toLowerCase();
    if (query.isEmpty) return dispatches;

    return dispatches
        .where((d) => d.depotName.toLowerCase().contains(query))
        .toList()
        .obs;
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
      fetchDispatches();
    }
  }

  void fetchDispatches() async {
    isLoading.value = true;
    final String formattedDate = DateFormat(
      'yyyy-MM-dd',
    ).format(selectedDate.value);
    final url = 'dispatch?startDate=$formattedDate&endDate=$formattedDate';

    try {
      final Dio dio = DioClient().dio;

      final res = await dio.get(url);
      if (res.statusCode == 200) {
        dispatches.value = (res.data['data'] as List)
            .map((e) => DispatchModel.fromJson(e))
            .toList();
      } else {
        Get.snackbar('Error', 'Failed to load dispatches');
      }
    } catch (e) {
      Get.snackbar('Error', e.toString());
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> submitEALLink({
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
        ),
      );
      if (res.statusCode == 200) {
        // Get.snackbar('Success', 'EAL linked successfully');
        isLoading.value = false;

        // 🛠️ Find the dispatch
        int dispatchIndex = dispatches.indexWhere((d) => d.id == dispatchId);
        if (dispatchIndex != -1) {
          // Force the list to update UI by re-assigning
          dispatches[dispatchIndex] = DispatchModel.fromJson(
            res.data['updatedDispatch'],
          );
        }

        return true;
      } else {
        Get.snackbar(
          'Failed',
          res.data['message'] ?? 'Server responded with ${res.statusCode}',
          duration: const Duration(seconds: 5),
          backgroundColor: Colors.red[100],
          colorText: Colors.red[900],
          icon: const Icon(Icons.warning_amber_rounded, color: Colors.red),
        );
        isLoading.value = false;
        return false;
      }
    } catch (e) {
      Get.snackbar('Error', 'Failed to submit: $e');
      isLoading.value = false;
      return false;
    }
  }

  Future<bool> updateVehicleDetails({
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
    print(data);
    try {
      final Dio dio = DioClient().dio;
      final res = await dio.put(
        'dispatch/$dispatchId/vehicle',
        data: data,
        options: Options(
          validateStatus: (status) =>
              status != null && status < 500, // Accept 400-499
        ),
      );

      if (res.statusCode == 200) {
        // Get.snackbar('Success', 'EAL linked successfully');
        isLoading.value = false;

        // 🛠️ Find the dispatch
        int dispatchIndex = dispatches.indexWhere((d) => d.id == dispatchId);
        if (dispatchIndex != -1) {
          final updated = dispatches[dispatchIndex].copyWith(
            vehicleNumber: vehicleNumber,
            driverName: driverName,
            driverContact: driverContact,
            status: status,
          );

          dispatches[dispatchIndex] = updated; // ✅ This triggers Obx rebuilds
        }

        return true;
      } else {
        Get.snackbar(
          'Failed',
          res.data['message'] ?? 'Server responded with ${res.statusCode}',
          duration: const Duration(seconds: 5),
          backgroundColor: Colors.red[100],
          colorText: Colors.red[900],
          icon: const Icon(Icons.warning_amber_rounded, color: Colors.red),
        );
        isLoading.value = false;
        return false;
      }
    } catch (e) {
      Get.snackbar('Error', 'Failed to submit: $e');
      isLoading.value = false;
      return false;
    }
  }

  Future<bool> removeEALLink({
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
        ),
      );

      int dispatchIndex = dispatches.indexWhere((d) => d.id == dispatchId);

      if (res.statusCode == 200) {
        // 🛠️ Find the dispatch
        if (dispatchIndex != -1) {
          // Force the list to update UI by re-assigning
          dispatches[dispatchIndex] = DispatchModel.fromJson(
            res.data['updatedDispatch'],
          );
        }
        isLoading.value = false;
        return true;
      } else {
        Get.snackbar(
          'Failed',
          res.data['message'] ?? 'Server responded with ${res.statusCode}',
          duration: const Duration(seconds: 5),
          backgroundColor: Colors.red[100],
          colorText: Colors.red[900],
          icon: const Icon(Icons.warning_amber_rounded, color: Colors.red),
        );
        isLoading.value = false;
        return false;
      }
    } catch (e) {
      Get.snackbar('Error', 'Failed to remove EAL link: $e');
      isLoading.value = false;
      return false;
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
