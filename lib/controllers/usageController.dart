import 'package:dio/dio.dart';
import 'package:eal_scanner/models/company.dart';
import 'package:eal_scanner/models/items.dart';
import 'package:eal_scanner/models/packSize.dart';
import 'package:eal_scanner/models/grouping_order.dart';
import 'package:eal_scanner/models/usage.dart';
import 'package:eal_scanner/models/usage_grouping.dart';
import 'package:eal_scanner/services/dioClient.dart';
import 'package:eal_scanner/utils/api_error.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

class UsageController extends GetxController {
  /// The span the list covers. The server takes a start and an end, so a
  /// single day is simply a span where both are the same date.
  Rx<DateTime> fromDate = _today().obs;
  Rx<DateTime> toDate = _today().obs;
  RxBool isLoading = false.obs;
  RxList<UsageModel> ealUsages = <UsageModel>[].obs;
  RxList<Company> companies = <Company>[].obs;
  RxList<PackSize> packs = <PackSize>[].obs;
  RxList<Item> items = <Item>[].obs;
  RxList<UsageModel> currentProduction = <UsageModel>[].obs;

  /// The three things the list is grouped by, which are the three worth
  /// filtering on. Empty means any, and the options come from the entries
  /// on screen rather than a separate fetch.
  RxString filterCompany = ''.obs;
  RxString filterMarket = ''.obs;
  RxString filterItem = ''.obs;

  /// Shown inline on the list rather than thrown as a snackbar.
  RxString errorMessage = ''.obs;

  /// Why the item list could not be read, where it could not be. A role may
  /// hold usage:create without masterdata:view, which lets someone open this
  /// screen and then be refused the list of items to record against — so the
  /// reason has to reach the screen rather than a snackbar that has gone by
  /// the time the picker opens.
  RxString itemsError = ''.obs;

  List<UsageModel> get filteredUsages {
    final company = filterCompany.value;
    final market = filterMarket.value;
    final item = filterItem.value;
    if (company.isEmpty && market.isEmpty && item.isEmpty) return ealUsages;

    return ealUsages.where((u) {
      if (company.isNotEmpty && u.companyName != company) return false;
      if (market.isNotEmpty && u.market.toLowerCase() != market) return false;
      if (item.isNotEmpty && u.itemName != item) return false;
      return true;
    }).toList();
  }

  /// What the list draws: the filtered entries, by company and market then
  /// item.
  List<UsageGroup> get groupedUsages => groupUsages(filteredUsages);

  int get activeFilterCount => [
    filterCompany.value,
    filterMarket.value,
    filterItem.value,
  ].where((f) => f.isNotEmpty).length;

  bool get hasFilters => activeFilterCount > 0;

  /// Options come from the entries on screen, so a filter can never be set
  /// to something there is nothing of.
  List<String> get companyOptions =>
      ealUsages.map((u) => u.companyName).toSet().toList()
        ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

  List<String> get itemOptions =>
      ealUsages.map((u) => u.itemName).toSet().toList()
        ..sort((a, b) => compareBySize(a, b));

  void clearFilters() {
    filterCompany.value = '';
    filterMarket.value = '';
    filterItem.value = '';
  }

  /// The strip above the list shows what is on screen, so the totals follow
  /// the filters.
  int get totalCases =>
      filteredUsages.fold<int>(0, (sum, u) => sum + u.usedQuantityInCases);

  int get totalLabels =>
      filteredUsages.fold<int>(0, (sum, u) => sum + u.usedQuantity);

  /// Cases produced in these dates that have not gone out on a dispatch.
  int get totalWaiting =>
      filteredUsages.fold<int>(0, (sum, u) => sum + u.balanceQuantityInCases);

  static DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
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
    fetchEALUsage();
  }

  void setLastDays(int days) {
    final today = _today();
    setSpan(today.subtract(Duration(days: days - 1)), today);
  }

  void setYesterday() {
    final yesterday = _today().subtract(const Duration(days: 1));
    setSpan(yesterday, yesterday);
  }

  void fetchEALUsage() async {
    final start = fromDate.value;
    final end = toDate.value;
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
      errorMessage.value = readableDioError(
        e,
        'Could not load production entries.',
      );
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

      final res = await dio.get(
        'companies',
        options: Options(extra: const {'silent': true}),
      );
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
      Get.snackbar('Error', readableError(e, 'Could not load that list.'));
    } finally {
      isLoading.value = false;
    }
  }

  void fetchPackSizes() async {
    try {
      isLoading.value = true;
      final Dio dio = DioClient().dio;

      final res = await dio.get(
        'packs',
        options: Options(extra: const {'silent': true}),
      );
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
      Get.snackbar('Error', readableError(e, 'Could not load that list.'));
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> fetchItems() async {
    try {
      isLoading.value = true;
      itemsError.value = '';
      final Dio dio = DioClient().dio;

      final res = await dio.get(
        'items',
        queryParameters: {'isActive': 'true'},
        options: Options(extra: const {'silent': true}),
      );
      if (res.statusCode == 200) {
        items.value = (res.data['data'] as List)
            .map((e) => Item.fromJson(e))
            .where((item) => item.isActive)
            .toList();
        return true;
      }

      items.clear();
      itemsError.value = readableResponseError(res, 'Could not load items.');
      return false;
    } catch (e) {
      items.clear();
      itemsError.value = readableError(e, 'Could not load items.');
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
