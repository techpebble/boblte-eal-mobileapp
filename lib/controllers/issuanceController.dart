import 'package:dio/dio.dart';
import 'package:eal_scanner/models/company.dart';
import 'package:eal_scanner/models/issuance.dart';
import 'package:eal_scanner/models/items.dart';
import 'package:eal_scanner/models/packSize.dart';
import 'package:eal_scanner/services/dioClient.dart';
import 'package:eal_scanner/utils/api_error.dart';
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

  /// Free-text filter over pack, market and company.
  RxString searchQuery = ''.obs;

  /// How many days the list covers, counting back from [selectedDate]. 1 is
  /// the single day the old build was fixed to.
  RxInt rangeDays = 1.obs;

  /// Shown inline on the list rather than thrown as a snackbar.
  RxString errorMessage = ''.obs;

  List<IssuanceModel> get filteredIssuance {
    final query = searchQuery.value.trim().toLowerCase();
    if (query.isEmpty) return ealIssuance;

    return ealIssuance.where((i) {
      return i.packName.toLowerCase().contains(query) ||
          i.market.toLowerCase().contains(query) ||
          i.companyName.toLowerCase().contains(query) ||
          i.prefix.toLowerCase().contains(query);
    }).toList();
  }

  /// Totals for the summary strip above the list.
  int get totalIssued =>
      ealIssuance.fold<int>(0, (sum, i) => sum + i.issuedQuantity);

  int get totalUnused =>
      ealIssuance.fold<int>(0, (sum, i) => sum + i.balanceQuantity);

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
      fetchEALIssuance();
    }
  }

  void setRange({required DateTime endDate, int days = 1}) {
    selectedDate.value = endDate;
    rangeDays.value = days;
    fetchEALIssuance();
  }

  void fetchEALIssuance() async {
    final end = selectedDate.value;
    final start = end.subtract(Duration(days: (rangeDays.value - 1).clamp(0, 365)));
    final formatter = DateFormat('yyyy-MM-dd');
    final url =
        'eal_issuance?startDate=${formatter.format(start)}&endDate=${formatter.format(end)}';

    try {
      isLoading.value = true;
      errorMessage.value = '';
      final Dio dio = DioClient().dio;

      final res = await dio.get(
        url,
        options: Options(extra: const {'silent': true}),
      );
      if (res.statusCode == 200) {
        ealIssuance.value = (res.data['data'] as List)
            .map((e) => IssuanceModel.fromJson(e))
            .toList();
      } else {
        errorMessage.value = 'Could not load issuance records.';
      }
    } on DioException catch (e) {
      errorMessage.value = readableDioError(e, 'Could not load issuance records.');
    } catch (_) {
      errorMessage.value = 'Could not load issuance records.';
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

  /// Records one issuance. Returns null when the server accepted it,
  /// otherwise the message to show the operator inline.
  Future<String?> addEALIssuance({
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
          extra: const {'silent': true},
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
        return null;
      }

      return readableResponseError(
        res,
        'The server would not record this issuance.',
      );
    } on DioException catch (e) {
      return readableDioError(e, 'Could not record this issuance.');
    } catch (_) {
      return 'Could not record this issuance.';
    } finally {
      isLoading.value = false;
    }
  }

  /// Removes an issuance that has not been drawn on.
  ///
  /// The server is the authority here: it refuses while any production entry
  /// points at the issuance, so the check in the UI is a courtesy, not the
  /// guard. Returns null on success, otherwise the message to show.
  Future<String?> deleteEALIssuance(String id) async {
    if (id.trim().isEmpty) {
      return 'This issuance has no ID, so it cannot be removed.';
    }

    try {
      isLoading.value = true;
      final Dio dio = DioClient().dio;

      final res = await dio.delete(
        'eal_issuance/$id',
        options: Options(
          validateStatus: (status) => status != null && status < 500,
          extra: const {'silent': true},
        ),
      );

      if (res.statusCode == 200) {
        ealIssuance.removeWhere((i) => i.id == id);
        return null;
      }

      return readableResponseError(
        res,
        'The server would not remove this issuance.',
      );
    } on DioException catch (e) {
      return readableDioError(e, 'Could not remove this issuance.');
    } catch (_) {
      return 'Could not remove this issuance.';
    } finally {
      isLoading.value = false;
    }
  }
}
