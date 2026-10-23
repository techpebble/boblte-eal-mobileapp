import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:eal_scanner/controllers/dashboardController.dart';
import 'package:eal_scanner/controllers/dispatchController.dart';
import 'package:eal_scanner/controllers/issuanceController.dart';
import 'package:eal_scanner/controllers/usageController.dart';
import 'package:eal_scanner/models/company.dart';
import 'package:eal_scanner/models/packSize.dart';
import 'package:eal_scanner/services/dioClient.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'support/api_test_support.dart';

/// Keeping the lists current.
///
/// Every tab is built once and kept alive, and each one used to ask the
/// server for its records exactly once. A production entry recorded on one
/// tab left the issuance list showing a balance that had already moved, and
/// the production list itself showing nothing of the entry at all.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeTestStorage();
  });

  late _CountingAdapter api;

  setUp(() {
    api = _CountingAdapter();
    DioClient().dio.httpClientAdapter = api;

    Get.put(Issuancecontroller());
    Get.put(UsageController());
    Get.put(DispatchController());
    Get.put(DashboardController());
  });

  tearDown(() => Get.reset());

  Future<String?> recordProduction() => Get.find<UsageController>().addEALUsage(
    company: 'c1',
    dateUsed: DateTime(2026, 10, 23),
    market: 'local',
    item: 'i1',
    pack: 'p1',
    prefix: 'AAA',
    serialFrom: '0000000001',
    serialTo: '0000004800',
    usedQuantity: 4800,
    usedQuantityInCases: 100,
  );

  test('recording production fetches the list it was recorded from', () async {
    api.reset();
    expect(await recordProduction(), isNull);
    await Future<void>.delayed(const Duration(milliseconds: 50));

    // The entry was added to the scan flow's own tally before this, and the
    // list behind it stayed as it was.
    expect(api.gets('eal_usage'), 1);
  });

  test('a write reaches the lists it was not made from', () async {
    final issuance = Get.find<Issuancecontroller>();
    final dispatch = Get.find<DispatchController>();
    final dashboard = Get.find<DashboardController>();

    expect(issuance.isStale.value, isFalse);

    await recordProduction();

    // Applying labels moves the issuance balance and the day's totals.
    expect(issuance.isStale.value, isTrue);
    expect(dispatch.isStale.value, isTrue);
    expect(dashboard.isStale.value, isTrue);
  });

  test('a tab catches up once, and only when something changed', () async {
    final issuance = Get.find<Issuancecontroller>();

    await recordProduction();
    api.reset();

    await issuance.refreshIfStale();
    expect(api.gets('eal_issuance'), 1);

    // Crossing back and forth between tabs is not a reason to ask the
    // server anything.
    await issuance.refreshIfStale();
    await issuance.refreshIfStale();
    expect(api.gets('eal_issuance'), 1);
  });

  test('recording an issuance leaves its own list fresh', () async {
    final issuance = Get.find<Issuancecontroller>();

    // It fetches itself at once, being the list behind the sheet, so it has
    // nothing left to catch up on.
    await issuance.addEALIssuance(
      company: Company(id: 'c1', code: 'BO', name: 'Blue Ocean', address: ''),
      dateIssued: DateTime(2026, 10, 23),
      market: 'local',
      pack: PackSize(id: 'p1', name: '180ml', bottlesPerCase: 48, pack: 48),
      prefix: 'AAA',
      serialFrom: '0000000001',
      serialTo: '0000009600',
      issuedQuantity: 9600,
    );
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(issuance.isStale.value, isFalse);
  });
}

/// Counts what was asked of the server, by path.
class _CountingAdapter implements HttpClientAdapter {
  final List<String> paths = [];

  void reset() => paths.clear();

  int gets(String path) => paths.where((p) => p.contains(path)).length;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.method == 'GET') paths.add(options.path);

    return ResponseBody.fromString(
      jsonEncode({'data': <dynamic>[]}),
      options.method == 'POST' ? 201 : 200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
