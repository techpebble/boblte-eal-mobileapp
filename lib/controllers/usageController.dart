import 'package:dio/dio.dart';
import 'package:eal_scanner/models/company.dart';
import 'package:eal_scanner/models/items.dart';
import 'package:eal_scanner/models/packSize.dart';
import 'package:eal_scanner/models/usage.dart';
import 'package:eal_scanner/services/dioClient.dart';
import 'package:eal_scanner/utils/api_error.dart';
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

  /// Free-text filter over item, pack and company.
  RxString searchQuery = ''.obs;

  /// How many days the list covers, counting back from [selectedDate].
  RxInt rangeDays = 1.obs;

  /// Shown inline on the list rather than thrown as a snackbar.
  RxString errorMessage = ''.obs;

  List<UsageModel> get filteredUsages {
    final query = searchQuery.value.trim().toLowerCase();
    if (query.isEmpty) return ealUsages;

    return ealUsages.where((u) {
      return u.itemName.toLowerCase().contains(query) ||
          u.packName.toLowerCase().contains(query) ||
          u.companyName.toLowerCase().contains(query) ||
          u.prefix.toLowerCase().contains(query);
    }).toList();
  }

  int get totalCases =>
      ealUsages.fold<int>(0, (sum, u) => sum + u.usedQuantityInCases);

  int get totalLabels =>
      ealUsages.fold<int>(0, (sum, u) => sum + u.usedQuantity);

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
      fetchEALUsage();
    }
  }

  void setRange({required DateTime endDate, int days = 1}) {
    selectedDate.value = endDate;
    rangeDays.value = days;
    fetchEALUsage();
  }

  void fetchEALUsage() async {
    final end = selectedDate.value;
    final start =
        end.subtract(Duration(days: (rangeDays.value - 1).clamp(0, 365)));
    final formatter = DateFormat('yyyy-MM-dd');
    final url =
        'eal_usage?startDate=${formatter.format(start)}&endDate=${formatter.format(end)}';

    try {
      isLoading.value = true;
      errorMessage.value = '';
      final Dio dio = DioClient().dio;

      final res = await dio.get(
        url,
        options: Options(extra: const {'silent': true}),
      );
      if (res.statusCode == 200) {
        ealUsages.value = (res.data['data'] as List)
            .map((e) => UsageModel.fromJson(e))
            .toList();
      } else {
        errorMessage.value = 'Could not load production entries.';
      }
    } on DioException catch (e) {
      errorMessage.value =
          readableDioError(e, 'Could not load production entries.');
    } catch (_) {
      errorMessage.value = 'Could not load production entries.';
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

  /// Records one production entry. Returns null when the server accepted
  /// it, otherwise the message to show the operator inline.
  Future<String?> addEALUsage({
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
          extra: const {'silent': true},
        ),
      );

      if (res.statusCode == 201) {
        isLoading.value = false;
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
        return null;
      }

      return readableResponseError(
        res,
        'The server would not record this production entry.',
      );
    } on DioException catch (e) {
      return readableDioError(e, 'Could not record this production entry.');
    } catch (_) {
      return 'Could not record this production entry.';
    } finally {
      isLoading.value = false;
    }
  }
}
