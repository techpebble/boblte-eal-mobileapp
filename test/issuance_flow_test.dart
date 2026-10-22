import 'package:eal_scanner/controllers/issuanceController.dart';
import 'package:eal_scanner/screens/issuance/issuanceListScreen.dart';
import 'package:eal_scanner/screens/issuance/issuance_filter_sheet.dart';
import 'package:eal_scanner/screens/issuance/sticker_details_sheet.dart';
import 'package:eal_scanner/services/dioClient.dart';
import 'package:eal_scanner/widgets/ui/serial_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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
          issuanceJson(
            pack: '180ml',
            bottlesPerCase: 48,
            from: 19450001,
            to: 19498000,
          ),
          issuanceJson(
            company: 'Zenith Distillers',
            pack: '750ml',
            bottlesPerCase: 12,
            market: 'export',
            prefix: 'EXP',
            from: 200001,
            to: 236000,
          ),
        ],
      },
      'companies': {
        'count': 1,
        'data': [companyResponse()],
      },
      'packs': {
        'count': 1,
        'data': [packResponse()],
      },
    });
  });

  tearDown(() => Get.reset());

  Future<void> pumpList(WidgetTester tester, {double width = 384}) async {
    tester.view.physicalSize = Size(width * 2, 1600);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const GetMaterialApp(home: IssuanceListScreen()));
    await tester.pumpAndSettle();
  }

  testWidgets('the list groups by company and market, then pack size', (
    tester,
  ) async {
    await pumpList(tester);

    expect(controller.ealIssuance, hasLength(3));
    expect(find.text('3 ranges'), findsOneWidget);
    expect(find.textContaining('issued'), findsWidgets);

    // Two company-and-market cards, three pack bands between them.
    expect(find.text('Blue Ocean Beverages Pvt. Ltd.'), findsOneWidget);
    expect(find.text('Zenith Distillers'), findsOneWidget);
    expect(find.text('90ml'), findsOneWidget);
    expect(find.text('180ml'), findsOneWidget);
    expect(find.text('750ml'), findsOneWidget);

    expect(tester.takeException(), isNull);
  });

  testWidgets('ranges are folded away until a pack size is opened', (
    tester,
  ) async {
    await pumpList(tester);

    // Collapsed by default: the pack card says how many it holds, and shows
    // none of them.
    expect(find.byType(SerialRangeText), findsNothing);
    expect(find.text('1 range'), findsNWidgets(3));

    await tester.tap(find.text('90ml'));
    await tester.pumpAndSettle();
    expect(find.byType(SerialRangeText), findsOneWidget);

    await tester.tap(find.text('90ml'));
    await tester.pumpAndSettle();
    expect(find.byType(SerialRangeText), findsNothing);
  });

  testWidgets('changing the dates folds everything away again', (tester) async {
    await pumpList(tester);

    await tester.tap(find.text('90ml'));
    await tester.pumpAndSettle();
    expect(find.byType(SerialRangeText), findsOneWidget);

    // A pack left open from the last date would be one nobody opened.
    await tester.tap(find.byIcon(Icons.calendar_today_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Today'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Show these dates'));
    await tester.pumpAndSettle();

    expect(find.byType(SerialRangeText), findsNothing);
  });

  testWidgets('the add button is round', (tester) async {
    await pumpList(tester);

    final fab = tester.widget<FloatingActionButton>(
      find.byType(FloatingActionButton),
    );
    expect(fab.shape, isA<CircleBorder>());
  });

  testWidgets('there is no search box, only a filter button', (tester) async {
    await pumpList(tester);

    expect(find.byType(TextField), findsNothing);
    expect(find.byIcon(Icons.filter_list_rounded), findsOneWidget);
  });

  testWidgets('the filter button sits hard against the right edge', (
    tester,
  ) async {
    // Checked at two widths on purpose. The bug this guards against only
    // shows when the title is NARROWER than the space it was given — a
    // flexible slot then holds the slack and the button drifts inwards. In
    // the test font the title fills a phone-width slot, so a phone-width
    // check alone passes while the device shows the gap.
    for (final width in const [384.0, 1200.0]) {
      await pumpList(tester, width: width);

      final button = tester.getRect(find.byIcon(Icons.filter_list_rounded));

      // 18 is the screen gutter; the icon sits 13 inside its own 1.5px
      // border.
      expect(
        button.right,
        closeTo(width - 18 - 10 - 1.5, 2),
        reason:
            'at ${width}px wide the filter button drifted from the right '
            'edge, ending at ${button.right}',
      );

      final title = tester.getRect(find.text('EAL issuance'));
      expect(title.left, closeTo(18, 1));
      expect(title.right, lessThan(button.left));
    }
  });

  testWidgets('the total sits in the list, and only with two companies', (
    tester,
  ) async {
    await pumpList(tester);

    // Two companies here, so the strip earns its line.
    expect(find.text('ALL COMPANIES'), findsOneWidget);

    // Narrowed to one company, the heading below says the same numbers, so
    // the strip goes.
    controller.filterCompany.value = 'Zenith Distillers';
    await tester.pumpAndSettle();
    expect(find.text('ALL COMPANIES'), findsNothing);
  });

  testWidgets('a pack keeps issued and left on one line when they fit', (
    tester,
  ) async {
    await pumpList(tester);

    // The two halves wrap only when they have to. A Row inside a Wrap
    // claims the whole width unless told otherwise, which put each half
    // on a line of its own however small the numbers were.
    final issued = tester.getRect(find.text('issued').first);
    final left = tester.getRect(find.text('left').first);
    expect(left.top, closeTo(issued.top, 2));

    // And 'left' stays at the card's far edge, where it reads as the second
    // of two figures rather than a word trailing the first.
    final width = tester.view.physicalSize.width / tester.view.devicePixelRatio;
    expect(left.right, greaterThan(width * 0.7));
  });

  testWidgets('a month of figures is not cut off in the total', (tester) async {
    // Two companies, seven digits each — a month's worth.
    DioClient().dio.httpClientAdapter = FakeApiRouter({
      'eal_issuance': {
        'count': 2,
        'data': [
          issuanceJson(from: 1, to: 13095339, used: 6159120),
          issuanceJson(
            company: 'Zenith Distillers',
            market: 'export',
            pack: '750ml',
            from: 20000001,
            to: 26936219,
          ),
        ],
      },
    });

    await pumpList(tester);

    expect(find.text('ALL COMPANIES'), findsOneWidget);

    // Every figure reads in full: inside the screen, and not ellipsised.
    // A Row split between two Flexibles gave each half the width whatever
    // it needed, so seven digits lost their tail while the label beside
    // them sat on space it had no use for.
    final width = tester.view.physicalSize.width / tester.view.devicePixelRatio;
    for (final figure in [
      ...find.textContaining('issued').evaluate(),
      ...find.textContaining('left').evaluate(),
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
        reason: 'a figure was clipped',
      );
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('the summary reads from the gutter, under the title', (
    tester,
  ) async {
    await pumpList(tester);

    // A line that sizes to its content centres itself unless the column
    // stretches it.
    final title = tester.getRect(find.text('EAL issuance'));
    final summary = tester.getRect(find.text('3 ranges'));
    expect(summary.left, closeTo(title.left, 1));
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

    await tester.tap(find.byIcon(Icons.calendar_today_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Dates'), findsOneWidget);
    expect(
      find.text(
        'Or tap a day, then the last day. One day on its own is '
        'fine.',
      ),
      findsOneWidget,
    );

    // The shortcuts came with the row that left the list.
    for (final preset in ['Today', 'Yesterday', '7 days']) {
      expect(find.text(preset), findsOneWidget, reason: '$preset is missing');
    }

    // The row scrolls, so the last one is reached rather than on screen —
    // in the test font the four are wider than a phone.
    await tester.dragUntilVisible(
      find.text('This month'),
      find.text('Today'),
      const Offset(-120, 0),
    );
    expect(find.text('This month'), findsOneWidget);

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
