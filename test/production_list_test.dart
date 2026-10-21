import 'package:eal_scanner/controllers/usageController.dart';
import 'package:eal_scanner/screens/usages/production_filter_sheet.dart';
import 'package:eal_scanner/screens/usages/usagesListScreen.dart';
import 'package:eal_scanner/services/dioClient.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'support/api_test_support.dart';

/// The production list reads like the issuance one, but counts in cases and
/// groups by item. These pin both, and the header geometry the two share.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeTestStorage();
  });

  Finder inSheet(Type sheet, Finder matching) =>
      find.descendant(of: find.byType(sheet), matching: matching);

  Map<String, dynamic> usageJson({
    String company = 'Blue Ocean Beverages Pvt. Ltd.',
    String item = 'OC Deluxe 750ml',
    String market = 'local',
    required int cases,
    required int perCase,
    int hour = 9,
  }) {
    return {
      '_id': '$item$cases$hour',
      'company': {'_id': 'c1', 'name': company},
      'item': {'_id': 'i1', 'name': item, 'alias': item},
      'pack': {'_id': 'p1', 'name': 'pack'},
      'dateUsed': '2026-10-21T0${hour}:00:00.000Z',
      'usedQuantity': cases * perCase,
      'usedQuantityInCases': cases,
      'balanceQuantity': 0,
      'balanceQuantityInCases': 0,
      'market': market,
      'prefix': 'ML',
      'serialFrom': 12001,
      'serialTo': 12001 + cases * perCase - 1,
      'usedSerialRanges': <dynamic>[],
    };
  }

  late UsageController controller;

  setUp(() {
    controller = Get.put(UsageController());
    DioClient().dio.httpClientAdapter = FakeApiRouter({
      'eal_usage': {
        'count': 3,
        'data': [
          usageJson(cases: 200, perCase: 12, hour: 9),
          usageJson(item: 'Old Monk 375ml', cases: 73, perCase: 24, hour: 1),
          usageJson(item: 'OC Reserve 180ml', market: 'export',
              cases: 50, perCase: 48, hour: 3),
        ],
      },
    });
  });

  tearDown(() => Get.reset());

  Future<void> pumpList(WidgetTester tester, {double width = 384}) async {
    tester.view.physicalSize = Size(width * 2, 1600);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const GetMaterialApp(home: UsagesListScreen()));
    await tester.pumpAndSettle();
  }

  testWidgets('it groups by company and market, then item', (tester) async {
    await pumpList(tester);

    expect(controller.ealUsages, hasLength(3));
    expect(find.text('3 entries'), findsOneWidget);
    expect(find.text('Blue Ocean Beverages Pvt. Ltd.'), findsNWidgets(2));
    expect(find.textContaining('OC Deluxe 750ml'), findsOneWidget);
    expect(find.textContaining('Old Monk 375ml'), findsOneWidget);
    expect(find.textContaining('OC Reserve 180ml'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cases lead and labels follow', (tester) async {
    await pumpList(tester);

    // 200×12 + 73×24 = 4,152 labels local; plus 50×48 export = 6,552.
    expect(find.text('cases entered'), findsOneWidget);
    expect(find.text('labels consumed'), findsOneWidget);
    expect(find.text('323'), findsOneWidget, reason: '200 + 73 + 50 cases');
    expect(find.text('6,552'), findsOneWidget);

    // The derived bottles-per-case is shown on the item band.
    expect(find.textContaining('12 per case'), findsOneWidget);
  });

  testWidgets('there is no search box, only a filter button', (tester) async {
    await pumpList(tester);

    expect(find.byType(TextField), findsNothing);
    expect(find.byIcon(Icons.filter_list_rounded), findsOneWidget);
  });

  testWidgets('the filter sheet narrows by item, on confirm', (tester) async {
    await pumpList(tester);

    await tester.tap(find.byIcon(Icons.filter_list_rounded));
    await tester.pumpAndSettle();

    expect(find.byType(ProductionFilterSheet), findsOneWidget);
    expect(find.text('ITEM'), findsOneWidget);

    await tester.tap(inSheet(ProductionFilterSheet, find.text('Export')));
    await tester.pumpAndSettle();
    expect(controller.filterMarket.value, '', reason: 'not applied yet');

    await tester.tap(find.text('Show 1 entry'));
    await tester.pumpAndSettle();

    expect(controller.filterMarket.value, 'export');
    expect(controller.totalCases, 50);
    expect(find.textContaining('OC Deluxe 750ml'), findsNothing);
  });

  testWidgets('the date control opens the shared range sheet', (tester) async {
    await pumpList(tester);

    final datePill = find.byIcon(Icons.calendar_today_rounded);
    await tester.scrollUntilVisible(datePill, 120,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await tester.tap(datePill);
    await tester.pumpAndSettle();

    expect(find.text('Dates'), findsOneWidget);
    expect(find.text('Show these dates'), findsOneWidget);
  });

  testWidgets('the filter button sits hard against the right edge', (
    tester,
  ) async {
    // Same two widths as the issuance list: the drift only shows where the
    // title is narrower than the space it was handed.
    for (final width in const [384.0, 1200.0]) {
      await pumpList(tester, width: width);

      final button = tester.getRect(find.byIcon(Icons.filter_list_rounded));
      expect(
        button.right,
        closeTo(width - 18 - 13 - 1.5, 2),
        reason: 'at ${width}px the filter button drifted from the right edge',
      );
    }
  });
}
