import 'package:dio/dio.dart';
import 'package:eal_scanner/models/company.dart';
import 'package:eal_scanner/models/items.dart';
import 'package:eal_scanner/models/packSize.dart';
import 'package:eal_scanner/models/usage.dart';
import 'package:eal_scanner/services/dioClient.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

class UsageController extends GetxController {
  Rx<DateTime> selectedDate = DateTime.now().obs;
  RxBool isLoading = false.obs;
  RxList<UsageModel> ealUsages = <UsageModel>[].obs;
  RxList<Company> companies = <Company>[].obs;
  RxList<PackSize> packs = <PackSize>[].obs;
  RxList<Item> items = <Item>[].obs;
  RxList<UsageModel> currentProduction = <UsageModel>[].obs;

  void pickDate() async {
    DateTime? picked = await showDatePicker(
      context: Get.context!,
      initialDate: selectedDate.value,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      selectedDate.value = picked;
      fetchEALUsage();
    }
  }

  void fetchEALUsage() async {
    final String formattedDate = DateFormat(
      'yyyy-MM-dd',
    ).format(selectedDate.value);
    final url = 'eal_usage?startDate=$formattedDate&endDate=$formattedDate';

    try {
      isLoading.value = true;
      final Dio dio = DioClient().dio;

      final res = await dio.get(url);
      if (res.statusCode == 200) {
        ealUsages.value = (res.data['data'] as List)
            .map((e) => UsageModel.fromJson(e))
            .toList();
      } else {
        isLoading.value = false;
        Get.snackbar('Error', 'Failed to load EAL Issuance');
      }
    } catch (e) {
      isLoading.value = false;
      Get.snackbar('Error', e.toString());
    } finally {
      isLoading.value = false;
    }
  }

  void fetchCompanies() async {
    try {
      isLoading.value = true;
      final Dio dio = DioClient().dio;

      final res = await dio.get('companies');
      if (res.statusCode == 200) {
        companies.value = (res.data['data'] as List)
            .map((e) => Company.fromJson(e))
            .toList();
      } else {
        isLoading.value = false;
        Get.snackbar('Error', 'Failed to load companies');
      }
    } catch (e) {
      isLoading.value = false;
      Get.snackbar('Error', e.toString());
    } finally {
      isLoading.value = false;
    }
  }

  void fetchPackSizes() async {
    try {
      isLoading.value = true;
      final Dio dio = DioClient().dio;

      final res = await dio.get('packs');
      if (res.statusCode == 200) {
        packs.value = (res.data['data'] as List)
            .map((e) => PackSize.fromJson(e))
            .toList();
      } else {
        isLoading.value = false;
        Get.snackbar('Error', 'Failed to load Pack Sizes');
      }
    } catch (e) {
      isLoading.value = false;
      Get.snackbar('Error', e.toString());
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> fetchItems() async {
    try {
      isLoading.value = true;
      final Dio dio = DioClient().dio;

      final res = await dio.get('items', queryParameters: {'isActive': 'true'});
      if (res.statusCode == 200) {
        items.value = (res.data['data'] as List)
            .map((e) => Item.fromJson(e))
            .where((item) => item.isActive)
            .toList();
        return true;
      } else {
        items.clear();
        isLoading.value = false;
        Get.snackbar('Error', 'Failed to load items');
        return false;
      }
    } catch (e) {
      items.clear();
      isLoading.value = false;
      Get.snackbar('Error', e.toString());
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> addEALUsage({
    required String company,
    required DateTime dateUsed,
    required String market,
    required String item,
    required String pack,
    required String prefix,
    required String serialFrom,
    required String serialTo,
    required int usedQuantity,
    required int usedQuantityInCases,
  }) async {
    final data = {
      "company": company,
      "dateUsed": DateFormat('dd-MMM-yyyy').format(dateUsed),
      "item": item,
      "market": market,
      "pack": pack,
      "prefix": prefix.toUpperCase(),
      "serialFrom": serialFrom,
      "serialTo": serialTo,
      "usedQuantity": usedQuantity,
      "usedQuantityInCases": usedQuantityInCases,
    };

    try {
      isLoading.value = true;
      final Dio dio = DioClient().dio;

      final res = await dio.post(
        'eal_usage',
        data: data,
        options: Options(
          validateStatus: (status) =>
              status != null && status < 500, // Accept 400-499
        ),
      );

      if (res.statusCode == 201) {
        isLoading.value = false;
        Get.snackbar('Success', 'EAL linked successfully');
        currentProduction.add(
          UsageModel(
            id: '',
            companyName: company,
            itemName: item,
            packName: pack,
            dateUsed: dateUsed,
            usedQuantity: usedQuantity,
            usedQuantityInCases: usedQuantityInCases,
            balanceQuantity: 0,
            balanceQuantityInCases: 0,
            market: market,
            prefix: prefix,
            serialFrom: serialFrom,
            serialTo: serialTo,
            usedSerialRanges: [],
          ),
        );
        return true;
      } else {
        isLoading.value = false;
        Get.snackbar(
          'Failed',
          res.data['message'] ?? 'Server responded with ${res.statusCode}',
          duration: const Duration(seconds: 5),
          backgroundColor: Colors.red[100],
          colorText: Colors.red[900],
          icon: const Icon(Icons.warning_amber_rounded, color: Colors.red),
        );
        return false;
      }
    } catch (e) {
      isLoading.value = false;
      Get.snackbar('Error', 'Failed to submit: $e');
      return false;
    } finally {
      isLoading.value = false;
    }
  }
}
