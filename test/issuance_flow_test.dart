import 'package:eal_scanner/controllers/issuanceController.dart';
import 'package:eal_scanner/screens/issuance/issuanceListScreen.dart';
import 'package:eal_scanner/screens/issuance/issuance_filter_sheet.dart';
import 'package:eal_scanner/screens/issuance/sticker_details_sheet.dart';
import 'package:eal_scanner/services/dioClient.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'support/api_test_support.dart';

/// Scoped to a sheet, because the list stays on screen behind it and names
/// the same markets and packs.
Finder inSheet(Type sheet, Finder matching) =>
    find.descendant(of: find.byType(sheet), matching: matching);

/// Entering an issuance is one sheet off the list: date, company, pack size
/// and market, then the scanner. There is no entry screen in between, so the
/// list's Add button and the sheet's four fields are what these pin.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeTestStorage();
  });

  Map<String, dynamic> issuanceJson({
    String company = 'Blue Ocean Beverages Pvt. Ltd.',
    String pack = '90ml',
    int bottlesPerCase = 96,
    String market = 'local',
    String prefix = 'EXT',
    required int from,
    required int to,
    int used = 0,
  }) {
    final issued = to - from + 1;
    return {
      '_id': '64a0000000000000000000${from % 100}',
      'company': {'_id': 'c1', 'name': company},
      'pack': {'_id': 'p1', 'name': pack, 'bottlesPerCase': bottlesPerCase},
      'dateIssued': '2026-10-21T00:00:00.000Z',
      'issuedQuantity': issued,
      'balanceQuantity': issued - used,
      'market': market,
      'prefix': prefix,
      'serialFrom': from,
      'serialTo': to,
      'usedSerialRanges': <dynamic>[],
    };
  }

  late Issuancecontroller controller;

  setUp(() {
    controller = Get.put(Issuancecontroller());
    DioClient().dio.httpClientAdapter = FakeApiRouter({
      'eal_issuance': {
        'count': 3,
        'data': [
          issuanceJson(from: 2804736001, to: 2804832000, used: 57600),
          issuanceJson(pack: '180ml', bottlesPerCase: 48,
              from: 19450001, to: 19498000),
          issuanceJson(company: 'Zenith Distillers', pack: '750ml',
              bottlesPerCase: 12, market: 'export', prefix: 'EXP',
              from: 200001, to: 236000),
        ],
      },
      'companies': {'count': 1, 'data': [companyResponse()]},
      'packs': {'count': 1, 'data': [packResponse()]},
    });
  });

  tearDown(() => Get.reset());

  Future<void> pumpList(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.8125;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const GetMaterialApp(home: IssuanceListScreen()));
    await tester.pumpAndSettle();
  }

  testWidgets('the list groups by company and market, then pack size', (
    tester,
  ) async {
    await pumpList(tester);

    expect(controller.ealIssuance, hasLength(3));
    expect(find.text('3 records'), findsOneWidget);

    // Two company-and-market cards, three pack bands between them.
    expect(find.text('Blue Ocean Beverages Pvt. Ltd.'), findsOneWidget);
    expect(find.text('Zenith Distillers'), findsOneWidget);
    expect(find.text('90ml'), findsOneWidget);
    expect(find.text('180ml'), findsOneWidget);
    expect(find.text('750ml'), findsOneWidget);

    expect(tester.takeException(), isNull);
  });

  testWidgets('there is no search box, only a filter button', (tester) async {
    await pumpList(tester);

    expect(find.byType(TextField), findsNothing);
    expect(find.byIcon(Icons.filter_list_rounded), findsOneWidget);
  });

  testWidgets('the filter button opens the sheet, which applies on confirm', (
    tester,
  ) async {
    await pumpList(tester);

    await tester.tap(find.byIcon(Icons.filter_list_rounded));
    await tester.pumpAndSettle();

    expect(find.byType(IssuanceFilterSheet), findsOneWidget);
    expect(find.text('COMPANY'), findsOneWidget);
    expect(find.text('MARKET'), findsOneWidget);
    expect(find.text('PACK SIZE'), findsOneWidget);

    // Choosing is not applying: the list is untouched until the button.
    await tester.tap(inSheet(IssuanceFilterSheet, find.text('Export')));
    await tester.pumpAndSettle();
    expect(controller.filterMarket.value, '');
    expect(find.text('Show 1 record'), findsOneWidget);

    await tester.tap(find.text('Show 1 record'));
    await tester.pumpAndSettle();

    expect(controller.filterMarket.value, 'export');
    expect(controller.activeFilterCount, 1);
    expect(find.text('Zenith Distillers'), findsOneWidget);
    expect(find.text('Blue Ocean Beverages Pvt. Ltd.'), findsNothing);
  });

  testWidgets('the date control opens a range sheet that takes one day', (
    tester,
  ) async {
    await pumpList(tester);

    // Last in a scrolling row of shortcuts, so bring it into view first.
    final datePill = find.byIcon(Icons.calendar_today_rounded);
    await tester.scrollUntilVisible(datePill, 120, scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await tester.tap(datePill);
    await tester.pumpAndSettle();

    expect(find.text('Dates'), findsOneWidget);
    expect(
      find.text('Tap a day, then the last day. One day on its own is fine.'),
      findsOneWidget,
    );
    expect(find.text('Show these dates'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Add opens the sticker sheet, asking for all four', (
    tester,
  ) async {
    await pumpList(tester);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    expect(find.byType(StickerDetailsSheet), findsOneWidget);
    expect(find.text('Date issued'), findsOneWidget);
    expect(find.text('Company'), findsOneWidget);
    expect(find.text('Pack size'), findsOneWidget);
    expect(find.text('Market'), findsOneWidget);
    expect(inSheet(StickerDetailsSheet, find.text('Local')), findsOneWidget);
    expect(inSheet(StickerDetailsSheet, find.text('Export')), findsOneWidget);

    // The date is filled in; the other three are not, so scanning waits.
    expect(
      inSheet(StickerDetailsSheet, find.textContaining('today')),
      findsOneWidget,
    );
    final button = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Continue to scan'),
    );
    expect(button.onPressed, isNull);
    expect(find.text('Choose a company first'), findsOneWidget);
  });

  testWidgets('the sheet carries the last entry forward', (tester) async {
    await pumpList(tester);

    // The lists the pickers choose from, as the sheet would load them.
    controller.fetchCompanies();
    controller.fetchPackSizes();
    await tester.pumpAndSettle();

    // As if a range had just been recorded against these.
    controller.lastEntry = (
      company: controller.companies.first,
      pack: controller.packs.first,
      market: 'export',
    );

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    expect(find.byType(StickerDetailsSheet), findsOneWidget);
    expect(
      inSheet(StickerDetailsSheet, find.text(controller.companies.first.name)),
      findsOneWidget,
    );
    expect(
      inSheet(StickerDetailsSheet, find.text('90ml · 96 per case')),
      findsOneWidget,
    );

    // Carried over, so scanning is ready without answering anything again.
    final button = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Continue to scan'),
    );
    expect(button.onPressed, isNotNull);
    expect(
      find.textContaining('carried over from your last entry'),
      findsOneWidget,
    );
  });
}
