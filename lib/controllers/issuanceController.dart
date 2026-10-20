import 'package:dio/dio.dart';
import 'package:eal_scanner/models/company.dart';
import 'package:eal_scanner/models/issuance.dart';
import 'package:eal_scanner/models/items.dart';
import 'package:eal_scanner/models/packSize.dart';
import 'package:eal_scanner/services/dioClient.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

class Issuancecontroller extends GetxController {
  Rx<DateTime> selectedDate = DateTime.now().obs;
  RxBool isLoading = false.obs;
  RxList<IssuanceModel> ealIssuance = <IssuanceModel>[].obs;
  RxList<Item> items = <Item>[].obs;
  RxList<Company> companies = <Company>[].obs;
  RxList<PackSize> packs = <PackSize>[].obs;
  RxList<IssuanceModel> currentEalIssuance = <IssuanceModel>[].obs;

  void pickDate() async {
    DateTime? picked = await showDatePicker(
      context: Get.context!,
      initialDate: selectedDate.value,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      selectedDate.value = picked;
      fetchEALIssuance();
    }
  }

  void fetchEALIssuance() async {
    final String formattedDate = DateFormat(
      'yyyy-MM-dd',
    ).format(selectedDate.value);
    final url = 'eal_issuance?startDate=$formattedDate&endDate=$formattedDate';

    try {
      isLoading.value = true;
      final Dio dio = DioClient().dio;

      final res = await dio.get(url);
      if (res.statusCode == 200) {
        ealIssuance.value = (res.data['data'] as List)
            .map((e) => IssuanceModel.fromJson(e))
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

  Future<bool> addEALIssuance({
    required Company? company,
    required DateTime dateIssued,
    required String market,
    required PackSize? pack,
    required String prefix,
    required String serialFrom,
    required String serialTo,
    required int issuedQuantity,
  }) async {
    final data = {
      "company": company?.id,
      "dateIssued": DateFormat('dd-MMM-yyyy').format(dateIssued),
      "market": market,
      "pack": pack?.id,
      "prefix": prefix.toUpperCase(),
      "serialFrom": serialFrom,
      "serialTo": serialTo,
      "issuedQuantity": issuedQuantity,
    };

    try {
      isLoading.value = true;
      final Dio dio = DioClient().dio;

      final res = await dio.post(
        'eal_issuance',
        data: data,
        options: Options(
          validateStatus: (status) =>
              status != null && status < 500, // Accept 400-499
        ),
      );
      if (res.statusCode == 201) {
        currentEalIssuance.add(
          IssuanceModel(
            companyName: company!.name,
            market: market,
            packName: pack!.name,
            prefix: prefix.toUpperCase(),
            serialFrom: serialFrom,
            serialTo: serialTo,
            issuedQuantity: issuedQuantity,
            dateIssued: DateTime.now(),
            id: '',
            balanceQuantity: 0,
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
