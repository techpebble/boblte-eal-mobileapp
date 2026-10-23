import 'package:dio/dio.dart';
import 'package:eal_scanner/models/company.dart';
import 'package:eal_scanner/models/issuance.dart';
import 'package:eal_scanner/models/issuance_grouping.dart';
import 'package:eal_scanner/models/items.dart';
import 'package:eal_scanner/models/packSize.dart';
import 'package:eal_scanner/services/dioClient.dart';
import 'package:eal_scanner/utils/api_error.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

class Issuancecontroller extends GetxController {
  /// The span the list covers. The server takes a start and an end, so a
  /// single day is simply a span where both are the same date.
  Rx<DateTime> fromDate = _today().obs;
  Rx<DateTime> toDate = _today().obs;
  RxBool isLoading = false.obs;
  RxList<IssuanceModel> ealIssuance = <IssuanceModel>[].obs;
  RxList<Item> items = <Item>[].obs;
  RxList<Company> companies = <Company>[].obs;
  RxList<PackSize> packs = <PackSize>[].obs;

  /// What the last entry was recorded against, so the next sheet can start
  /// from it instead of asking the same three questions again. A purchase is
  /// usually several sets from one company on one day.
  ({Company company, PackSize pack, String market})? lastEntry;

  /// The three things the records are grouped by, so they are also the three
  /// things worth filtering on. Empty means any. Held as names because that
  /// is what a record carries, and the options come from the records on
  /// screen rather than a separate fetch.
  RxString filterCompany = ''.obs;
  RxString filterMarket = ''.obs;
  RxString filterPack = ''.obs;

  /// Shown inline on the list rather than thrown as a snackbar.
  RxString errorMessage = ''.obs;

  /// Whether that failure was the network rather than the server. A lost
  /// connection is not an error the operator did anything about, and it
  /// gets its own state instead of a red banner.
  RxBool isOffline = false.obs;

  /// Why the company or pack list could not be read. The sheet waits on both
  /// before it can record anything, so a refusal has to be said rather than
  /// left as a progress bar that never finishes.
  RxString listsError = ''.obs;

  List<IssuanceModel> get filteredIssuance {
    final company = filterCompany.value;
    final market = filterMarket.value;
    final pack = filterPack.value;
    if (company.isEmpty && market.isEmpty && pack.isEmpty) return ealIssuance;

    return ealIssuance.where((i) {
      if (company.isNotEmpty && i.companyName != company) return false;
      if (market.isNotEmpty && i.market.toLowerCase() != market) return false;
      if (pack.isNotEmpty && i.packName != pack) return false;
      return true;
    }).toList();
  }

  /// What the list draws: the filtered records, by company and market then
  /// pack size.
  List<IssuanceGroup> get groupedIssuance => groupIssuances(filteredIssuance);

  int get activeFilterCount => [
    filterCompany.value,
    filterMarket.value,
    filterPack.value,
  ].where((f) => f.isNotEmpty).length;

  bool get hasFilters => activeFilterCount > 0;

  /// Filter options come from the records on screen, so a filter can never
  /// be set to something there is nothing of.
  List<String> get companyOptions =>
      ealIssuance.map((i) => i.companyName).toSet().toList()
        ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

  List<String> get packOptions =>
      ealIssuance.map((i) => i.packName).toSet().toList()..sort();

  void clearFilters() {
    filterCompany.value = '';
    filterMarket.value = '';
    filterPack.value = '';
  }

  /// Totals for the strip above the list, which shows what is on screen —
  /// so they follow the filters.
  int get totalIssued =>
      filteredIssuance.fold<int>(0, (sum, i) => sum + i.issuedQuantity);

  int get totalUnused =>
      filteredIssuance.fold<int>(0, (sum, i) => sum + i.balanceQuantity);

  static DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  /// True while the span is exactly the last [days] days ending today, which
  /// is what lights the matching shortcut.
  bool isPreset(int days) {
    final today = _today();
    return toDate.value == today &&
        fromDate.value == today.subtract(Duration(days: days - 1));
  }

  /// True while the span is the single day before today.
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
    fetchEALIssuance();
  }

  /// The last [days] days, ending today.
  void setLastDays(int days) {
    final today = _today();
    setSpan(today.subtract(Duration(days: days - 1)), today);
  }

  void setYesterday() {
    final yesterday = _today().subtract(const Duration(days: 1));
    setSpan(yesterday, yesterday);
  }

  /// The first of this month up to today, which is the span an excise
  /// return is usually asked for.
  void setThisMonth() {
    final today = _today();
    setSpan(DateTime(today.year, today.month), today);
  }

  bool get isThisMonth {
    final today = _today();
    return fromDate.value == DateTime(today.year, today.month) &&
        toDate.value == today;
  }

  void fetchEALIssuance() async {
    final start = fromDate.value;
    final end = toDate.value;
    final formatter = DateFormat('yyyy-MM-dd');
    final url =
        'eal_issuance?startDate=${formatter.format(start)}&endDate=${formatter.format(end)}';

    try {
      isLoading.value = true;
      errorMessage.value = '';
      isOffline.value = false;
      isOffline.value = false;
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
      isOffline.value = isConnectionFailure(e);
      errorMessage.value = readableDioError(
        e,
        'Could not load issuance records.',
      );
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
        listsError.value = 'Could not load companies.';
      }
    } catch (e) {
      isLoading.value = false;
      listsError.value = readableError(e, 'Could not load that list.');
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
        listsError.value = 'Could not load pack sizes.';
      }
    } catch (e) {
      isLoading.value = false;
      listsError.value = readableError(e, 'Could not load that list.');
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

    /// Typed rather than scanned. The record keeps it, and a role without
    /// scan:manual is refused: a transposed digit reads as a real label.
    bool enteredByHand = false,
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
      "enteredByHand": enteredByHand,
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
        if (company != null && pack != null) {
          lastEntry = (company: company, pack: pack, market: market);
        }
        // The list is what shows the result now, so it is refetched rather
        // than patched: the server owns the balance and the record id.
        fetchEALIssuance();
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
