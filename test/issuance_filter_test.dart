import 'package:eal_scanner/controllers/issuanceController.dart';
import 'package:eal_scanner/models/issuance.dart';
import 'package:eal_scanner/services/dioClient.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'support/api_test_support.dart';

/// The list is filtered and dated entirely in the controller, so the rules
/// are pinned here without a screen.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeTestStorage();
  });

  tearDown(() => Get.reset());

  IssuanceModel record({
    String company = 'Blue Ocean',
    String pack = '90ml',
    String market = 'local',
    required int from,
    required int to,
    int used = 0,
  }) {
    final issued = to - from + 1;
    return IssuanceModel(
      id: '$from',
      companyName: company,
      packName: pack,
      dateIssued: DateTime(2026, 10, 21),
      issuedQuantity: issued,
      balanceQuantity: issued - used,
      market: market,
      prefix: 'EXT',
      serialFrom: from.toString(),
      serialTo: to.toString(),
      usedSerialRanges: [],
    );
  }

  Issuancecontroller seeded() {
    final c = Get.put(Issuancecontroller());
    c.ealIssuance.value = [
      record(from: 1, to: 1000, used: 400),
      record(pack: '180ml', from: 1001, to: 2000),
      record(
        company: 'Zenith',
        market: 'export',
        pack: '750ml',
        from: 2001,
        to: 3000,
      ),
    ];
    return c;
  }

  test('no filters shows everything', () {
    final c = seeded();
    expect(c.filteredIssuance, hasLength(3));
    expect(c.activeFilterCount, 0);
    expect(c.hasFilters, isFalse);
  });

  test('each filter narrows, and they combine', () {
    final c = seeded();

    c.filterCompany.value = 'Blue Ocean';
    expect(c.filteredIssuance, hasLength(2));
    expect(c.activeFilterCount, 1);

    c.filterPack.value = '180ml';
    expect(c.filteredIssuance, hasLength(1));
    expect(c.activeFilterCount, 2);

    c.filterMarket.value = 'export';
    expect(c.filteredIssuance, isEmpty, reason: 'that pack is local only');
    expect(c.activeFilterCount, 3);

    c.clearFilters();
    expect(c.filteredIssuance, hasLength(3));
    expect(c.hasFilters, isFalse);
  });

  test('the totals follow the filters, because the strip shows what is on '
      'screen', () {
    final c = seeded();
    expect(c.totalIssued, 3000);
    expect(c.totalUnused, 2600);

    c.filterCompany.value = 'Zenith';
    expect(c.totalIssued, 1000);
    expect(c.totalUnused, 1000);
  });

  test('filter options come from the records, not a fetch', () {
    final c = seeded();
    expect(c.companyOptions, ['Blue Ocean', 'Zenith']);
    expect(c.packOptions, ['180ml', '750ml', '90ml']);
  });

  test('grouping runs over the filtered records', () {
    final c = seeded();
    expect(c.groupedIssuance, hasLength(2));

    c.filterMarket.value = 'export';
    expect(c.groupedIssuance, hasLength(1));
    expect(c.groupedIssuance.single.companyName, 'Zenith');
  });

  test('a span is stored low to high, whichever way it is given', () {
    final c = Get.put(Issuancecontroller());
    DioClient().dio.httpClientAdapter = FakeApiAdapter({
      'count': 0,
      'data': [],
    });

    c.setSpan(DateTime(2026, 10, 21), DateTime(2026, 10, 15));
    expect(c.fromDate.value, DateTime(2026, 10, 15));
    expect(c.toDate.value, DateTime(2026, 10, 21));
    expect(c.isSingleDay, isFalse);
  });

  test('the shortcuts set spans the shortcuts then recognise', () {
    final c = Get.put(Issuancecontroller());
    DioClient().dio.httpClientAdapter = FakeApiAdapter({
      'count': 0,
      'data': [],
    });

    c.setLastDays(1);
    expect(c.isPreset(1), isTrue);
    expect(c.isSingleDay, isTrue);

    c.setLastDays(7);
    expect(c.isPreset(7), isTrue);
    expect(c.isPreset(1), isFalse);
    expect(c.toDate.value.difference(c.fromDate.value).inDays, 6);

    c.setYesterday();
    expect(c.isYesterday, isTrue);
    expect(c.isPreset(1), isFalse);
  });
}
