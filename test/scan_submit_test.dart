import 'package:eal_scanner/screens/scan/scan_flow_screen.dart';
import 'package:eal_scanner/screens/scan/scan_target.dart';
import 'package:eal_scanner/theme/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/api_test_support.dart';

/// The step screen records the range itself, with no review screen between.
///
/// That screen used to own the submit, the server's rejection message and the
/// dispatch line arithmetic. Folding it in moved all of that, so the whole
/// path is walked here: type both ends, read the figures, send it.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeTestStorage();
  });

  ScanTarget target({
    required Future<String?> Function(ScanDraft) submit,
    ScanUnit unit = ScanUnit.labels,
    int? requiredCases,
    int? alreadyLinkedCases,
    String? subjectName,
    String? subjectMarket,
    AppModule module = AppModule.issuance,
  }) {
    return ScanTarget(
      module: module,
      title: 'Record issuance',
      contextLine: '90ml · Local · Blue Ocean Beverages Pvt. Ltd.',
      bottlesPerCase: 96,
      unit: unit,
      initialPrefix: 'EXT',
      requiredCases: requiredCases,
      alreadyLinkedCases: alreadyLinkedCases,
      subjectName: subjectName,
      subjectMarket: subjectMarket,
      submit: submit,
    );
  }

  Future<void> pump(WidgetTester tester, ScanTarget t) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.8125;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(home: ScanFlowScreen(target: t)));
    await tester.pumpAndSettle();
  }

  /// Fills the end on offer by typing it, since a camera cannot be driven
  /// from a test.
  Future<void> typeEnd(WidgetTester tester, String digits) async {
    await tester.tap(find.text('Label damaged? Type it by hand'));
    await tester.pumpAndSettle();

    for (final digit in digits.split('')) {
      await tester.tap(find.text(digit));
      await tester.pump();
    }
    await tester.pumpAndSettle();

    await tester.tap(find.text('Use this serial'));
    await tester.pumpAndSettle();
  }

  /// 2804736001 to 2804832000 is 96,000 labels, or 1,000 cases of 96.
  Future<void> typeWholeRange(WidgetTester tester) async {
    await typeEnd(tester, '2804736001');
    await typeEnd(tester, '2804832000');
  }

  testWidgets('the finished range and its figures sit on one screen', (
    tester,
  ) async {
    await pump(tester, target(submit: (_) async => null));

    await typeWholeRange(tester);

    // What the review screen used to say, now in place.
    expect(find.text('RANGE TO RECORD'), findsOneWidget);
    expect(find.text('96,000'), findsOneWidget);
    expect(find.text('labels'), findsOneWidget);
    expect(find.text('1,000'), findsOneWidget);
    expect(find.text('cases · 96 per case'), findsOneWidget);
    expect(find.text('by hand'), findsOneWidget);
    expect(find.text('Saved to the server straight away'), findsOneWidget);

    // And no second screen to walk through.
    expect(find.text('Continue to summary'), findsNothing);
    expect(find.text('Check before sending'), findsNothing);
  });

  testWidgets('the button sends the range it shows', (tester) async {
    ScanDraft? sent;

    await pump(
      tester,
      target(
        submit: (draft) async {
          sent = draft;
          return null;
        },
      ),
    );

    await typeWholeRange(tester);

    await tester.tap(find.text('Record 96,000 labels'));
    await tester.pumpAndSettle();

    expect(sent, isNotNull);
    expect(sent!.prefix, 'EXT');
    expect(sent!.serialFrom, '2804736001');
    expect(sent!.serialTo, '2804832000');

    // Straight to the confirmation, with nothing in between.
    expect(find.text('96,000 labels recorded'), findsOneWidget);
  });

  testWidgets('a rejection from the server is shown in the server\'s own '
      'words', (tester) async {
    await pump(
      tester,
      target(
        submit: (_) async => 'That range overlaps EXT 2804736001 — 2804750000.',
      ),
    );

    await typeWholeRange(tester);
    await tester.tap(find.text('Record 96,000 labels'));
    await tester.pumpAndSettle();

    expect(find.text('The server would not accept this'), findsOneWidget);
    expect(
      find.text('That range overlaps EXT 2804736001 — 2804750000.'),
      findsOneWidget,
    );

    // Still here, still sendable once the range is put right.
    expect(find.text('Record 96,000 labels'), findsOneWidget);
  });

  testWidgets('a dispatch line still says where it stands', (tester) async {
    await pump(
      tester,
      target(
        submit: (_) async => null,
        unit: ScanUnit.cases,
        requiredCases: 1000,
        alreadyLinkedCases: 0,
      ),
    );

    await typeWholeRange(tester);

    expect(find.text('This completes the line'), findsOneWidget);
    // A dispatch counts in cases, so the button leads with those.
    expect(find.text('Record 1,000 cases'), findsOneWidget);
  });

  testWidgets('a second range counts on top of the first, not instead', (
    tester,
  ) async {
    // Two pallets of 1,000 cases against a line of 2,000. The count the
    // screen is handed is how the line stood when it opened, and recording
    // another range stays on this screen — so the second range used to be
    // measured against an empty line: 1,000 of 2,000, with 1,000 short,
    // when the line was in fact full.
    await pump(
      tester,
      target(
        module: AppModule.dispatch,
        submit: (_) async => null,
        unit: ScanUnit.cases,
        requiredCases: 2000,
        alreadyLinkedCases: 0,
      ),
    );

    await typeWholeRange(tester);
    await tester.tap(find.text('Link 1,000 cases'));
    await tester.pumpAndSettle();

    expect(find.text('1,000 / 2,000'), findsOneWidget);

    await tester.tap(find.text('Record another range'));
    await tester.pumpAndSettle();

    // The line as it now stands, before the next range is even scanned.
    expect(find.textContaining('1,000 already linked'), findsOneWidget);

    await typeEnd(tester, '2804832001');
    await typeEnd(tester, '2804928000');

    expect(find.text('This completes the line'), findsOneWidget);

    await tester.tap(find.text('Link 1,000 cases'));
    await tester.pumpAndSettle();

    expect(find.text('2,000 / 2,000'), findsOneWidget);
  });

  testWidgets('a part case never reaches the screen', (tester) async {
    await pump(tester, target(submit: (_) async => null));
    await typeEnd(tester, '2804736001');

    // One label over 1,000 whole cases of 96. Manual entry refuses to hand
    // it back, so the range is never completed and there is nothing to send.
    await tester.tap(find.text('Label damaged? Type it by hand'));
    await tester.pumpAndSettle();
    for (final digit in '2804832001'.split('')) {
      await tester.tap(find.text(digit));
      await tester.pump();
    }
    await tester.pumpAndSettle();

    expect(find.text('Not a whole number of cases'), findsOneWidget);

    final use = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Use this serial'),
    );
    expect(use.onPressed, isNull);
  });

  testWidgets('linking checks the same count, in its own words', (
    tester,
  ) async {
    // The same card production uses, because the act is the same one: a
    // figure checked against what is on the pallet. Only the words and the
    // colour belong to dispatch.
    await pump(
      tester,
      target(
        module: AppModule.dispatch,
        unit: ScanUnit.cases,
        subjectName: 'Reserve Whisky 750ml',
        subjectMarket: 'local',
        requiredCases: 1000,
        alreadyLinkedCases: 0,
        submit: (_) async => null,
      ),
    );
    await typeWholeRange(tester);

    expect(find.text('Reserve Whisky 750ml'), findsOneWidget);
    expect(find.text('cases to link'), findsOneWidget);
    expect(find.text('cases produced'), findsNothing);

    final cases = tester.widget<Text>(find.text('1,000'));
    expect(cases.style?.fontSize, 52);
    expect(cases.style?.color, AppColors.amberDeep);

    // The button says what it does with them, not "Record".
    expect(
      find.widgetWithText(ElevatedButton, 'Link 1,000 cases'),
      findsOneWidget,
    );
  });

  testWidgets('production checks the case count on a card of its own', (
    tester,
  ) async {
    await pump(
      tester,
      target(
        unit: ScanUnit.cases,
        subjectName: 'OC Deluxe 750ml',
        subjectMarket: 'local',
        submit: (_) async => null,
      ),
    );
    await typeWholeRange(tester);

    // The item is named beside the figure, so the count can be checked
    // against the day sheet without reading the app bar.
    expect(find.text('OC Deluxe 750ml'), findsOneWidget);
    expect(find.text('cases produced'), findsOneWidget);

    // One large figure and nothing else large on the screen.
    final cases = tester.widget<Text>(find.text('1,000'));
    expect(cases.style?.fontSize, 52);
    for (final other in find.byType(Text).evaluate()) {
      final size = (other.widget as Text).style?.fontSize ?? 0;
      if (identical(other.widget, cases)) continue;
      expect(
        size,
        lessThan(30),
        reason: 'something else on the screen competes with the count',
      );
    }

    // The arithmetic behind it stays, in the small line under it.
    expect(
      find.textContaining('96,000 labels', findRichText: true),
      findsOneWidget,
    );
    expect(
      find.textContaining('96 per case', findRichText: true),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('the strip under the count keeps the card\'s bottom corners', (
    tester,
  ) async {
    await pump(
      tester,
      target(
        unit: ScanUnit.cases,
        subjectName: 'OC Deluxe 750ml',
        subjectMarket: 'local',
        submit: (_) async => null,
      ),
    );
    await typeWholeRange(tester);

    final strip = tester.widget<Container>(
      find
          .ancestor(of: find.byType(Wrap), matching: find.byType(Container))
          .first,
    );
    final box = strip.decoration! as BoxDecoration;

    // A square child paints over the card's rounded border, which is drawn
    // behind it, and the two bottom corners go missing.
    expect(
      box.borderRadius,
      isNotNull,
      reason: 'the strip would square off the card',
    );

    // And it has to differ from the page, or the band reads as empty space
    // below the card rather than part of it.
    expect(box.color, isNot(AppColors.canvas));
  });

  testWidgets('the big count scales down rather than overflowing', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(640, 2000);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: ScanFlowScreen(
          target: target(
            unit: ScanUnit.cases,
            subjectName: 'OC Deluxe 750ml',
            subjectMarket: 'local',
            submit: (_) async => null,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await typeWholeRange(tester);

    expect(find.text('1,000'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('issuance keeps the paired figures, not the big card', (
    tester,
  ) async {
    await pump(tester, target(submit: (_) async => null));
    await typeWholeRange(tester);

    // An issuance counts in labels and is not checked off a day sheet, so
    // nothing here grows to the size production's count does.
    expect(find.text('cases produced'), findsNothing);
    for (final text in find.byType(Text).evaluate()) {
      expect((text.widget as Text).style?.fontSize ?? 0, lessThan(30));
    }
  });
}
