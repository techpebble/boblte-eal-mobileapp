import 'package:eal_scanner/controllers/usageController.dart';
import 'package:eal_scanner/screens/usages/production_filter_sheet.dart';
import 'package:eal_scanner/screens/usages/usagesListScreen.dart';
import 'package:eal_scanner/services/dioClient.dart';
import 'package:eal_scanner/utils/formatting.dart';
import 'package:eal_scanner/widgets/ui/serial_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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
    int waiting = 0,
  }) {
    return {
      '_id': '$item$cases$hour',
      'company': {'_id': 'c1', 'name': company},
      'item': {'_id': 'i1', 'name': item, 'alias': item},
      'pack': {'_id': 'p1', 'name': 'pack'},
      'dateUsed': '2026-10-21T0${hour}:00:00.000Z',
      'usedQuantity': cases * perCase,
      'usedQuantityInCases': cases,
      'balanceQuantity': waiting * perCase,
      'balanceQuantityInCases': waiting,
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
          usageJson(cases: 200, perCase: 12, hour: 9, waiting: 20),
          usageJson(
            item: 'Old Monk 375ml',
            cases: 73,
            perCase: 24,
            hour: 1,
            waiting: 73,
          ),
          // Nothing left waiting: this one has all gone out.
          usageJson(
            item: 'OC Reserve 180ml',
            market: 'export',
            cases: 50,
            perCase: 48,
            hour: 3,
          ),
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

  testWidgets('cases lead, and the labels ride with the pack size', (
    tester,
  ) async {
    await pumpList(tester);

    // Cases are the figure on the card: 200 of this item, 20 of them not
    // yet dispatched.
    expect(find.text('200'), findsOneWidget);
    expect(find.text('cases'), findsNWidgets(3));
    expect(find.text('20'), findsOneWidget);
    expect(find.text('waiting'), findsNWidgets(2));

    // The labels sit in the small line with the derived bottles per case,
    // not beside the figure. 200 × 12 = 2,400.
    expect(find.textContaining('12 per case · 2,400 labels'), findsOneWidget);

    // Totalled above the companies: 200 + 73 + 50 produced, 20 + 73 waiting.
    expect(find.text('ALL COMPANIES'), findsOneWidget);
    expect(
      find.textContaining('323 produced'),
      findsOneWidget,
      reason: 'the total counts cases, not labels',
    );
    // Twice over: the total, and the one company that has any waiting.
    expect(find.textContaining('93 waiting'), findsNWidgets(2));
  });

  testWidgets('an item with nothing waiting says so, not zero', (tester) async {
    await pumpList(tester);

    // A bare 0 in the waiting slot reads as missing data; the finished
    // state reads as finished.
    expect(find.text('All dispatched'), findsOneWidget);
    expect(find.text('0'), findsNothing);
  });

  testWidgets('entries are folded away until an item is opened', (
    tester,
  ) async {
    await pumpList(tester);

    expect(find.byType(SerialRangeText), findsNothing);

    await tester.tap(find.text('OC Deluxe 750ml'));
    await tester.pumpAndSettle();
    expect(find.byType(SerialRangeText), findsOneWidget);

    await tester.tap(find.text('OC Deluxe 750ml'));
    await tester.pumpAndSettle();
    expect(find.byType(SerialRangeText), findsNothing);
  });

  testWidgets('changing the dates folds everything away again', (tester) async {
    await pumpList(tester);

    await tester.tap(find.text('OC Deluxe 750ml'));
    await tester.pumpAndSettle();
    expect(find.byType(SerialRangeText), findsOneWidget);

    await tester.tap(find.byIcon(Icons.calendar_today_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Today'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Show these dates'));
    await tester.pumpAndSettle();

    // An item left open from the last span is one nobody opened.
    expect(find.byType(SerialRangeText), findsNothing);
  });

  testWidgets('a month of figures is not cut off anywhere', (tester) async {
    // Two companies at month scale, where the figures run to seven digits.
    DioClient().dio.httpClientAdapter = FakeApiRouter({
      'eal_usage': {
        'count': 2,
        'data': [
          usageJson(cases: 196500, perCase: 12, waiting: 84200),
          usageJson(
            company: 'Zenith Distillers',
            item: 'Reserve 180ml',
            market: 'export',
            cases: 123456,
            perCase: 48,
            waiting: 99999,
          ),
        ],
      },
    });

    await pumpList(tester);

    // Every figure reads in full: inside the screen, and not ellipsised.
    final width = tester.view.physicalSize.width / tester.view.devicePixelRatio;
    for (final figure in [
      ...find.textContaining('produced').evaluate(),
      ...find.textContaining('waiting').evaluate(),
      ...find.textContaining('labels').evaluate(),
    ]) {
      final at = find.byWidget(figure.widget);
      expect(
        tester.getRect(at).right,
        lessThanOrEqualTo(width + 0.5),
        reason: 'a figure runs past the right edge',
      );
      expect(
        tester.renderObject<RenderParagraph>(at).didExceedMaxLines,
        isFalse,
        reason: 'a figure was cut off',
      );
    }
    expect(tester.takeException(), isNull);
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

    await tester.tap(find.byIcon(Icons.calendar_today_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Dates'), findsOneWidget);
    expect(find.text('Show these dates'), findsOneWidget);
  });

  testWidgets('the empty state names the date it is empty for', (tester) async {
    DioClient().dio.httpClientAdapter = FakeApiRouter({
      'eal_usage': {'count': 0, 'data': []},
    });

    await pumpList(tester);

    // The whole point of this screen's empty state is saying which dates it
    // covers, so the date has to be a date — not an un-run interpolation.
    expect(find.textContaining('Nothing entered on'), findsOneWidget);
    expect(
      find.textContaining(r'${'),
      findsNothing,
      reason: 'a Dart interpolation reached the screen as literal text',
    );
    expect(
      find.textContaining(formatDayMonthYear(controller.fromDate.value)),
      findsOneWidget,
    );
    expect(find.text('Record a production entry'), findsOneWidget);
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
        closeTo(width - 18 - 10 - 1.5, 2),
        reason: 'at ${width}px the filter button drifted from the right edge',
      );
    }
  });
}
