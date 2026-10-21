import 'package:eal_scanner/models/usage.dart';
import 'package:eal_scanner/screens/usages/usageDetailScreen.dart';
import 'package:eal_scanner/widgets/ui/feedback.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// One production entry, read off the record.
///
/// The screen showed a clock the server does not keep, a progress bar with a
/// denominator that was not the issuance total, and a range section that
/// repeated the card above it. These pin all three.
void main() {
  UsageModel entry({
    int cases = 40,
    int perCase = 12,
    int balanceCases = 0,
    int balanceLabels = 0,
    List<SerialRangeModel> ranges = const [],
  }) {
    return UsageModel(
      id: 'u1',
      companyName: 'Blue Ocean Beverages Pvt. Ltd.',
      itemName: 'Highbury Classic 750ml',
      packName: '750ml x 12',
      dateUsed: DateTime(2026, 10, 15),
      usedQuantity: cases * perCase,
      usedQuantityInCases: cases,
      balanceQuantity: balanceLabels,
      balanceQuantityInCases: balanceCases,
      market: 'local',
      prefix: 'DLK',
      serialFrom: '110739001',
      serialTo: '110739480',
      usedSerialRanges: ranges,
    );
  }

  Future<void> pump(WidgetTester tester, UsageModel usage) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.8125;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(home: EALUsageDetailScreen(usage: usage)),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('the header gives the date, and no time the server does not '
      'keep', (tester) async {
    await pump(tester, entry());

    expect(find.text('Entered 15 Oct 2026'), findsOneWidget);
    expect(find.textContaining('00:00'), findsNothing);
  });

  /// The bar's two numbers, read off the widget rather than the pixels.
  ({num linked, num required_}) bar(WidgetTester tester) {
    final w = tester.widget<LinkedProgressBar>(find.byType(LinkedProgressBar));
    return (linked: w.linked, required_: w.required_);
  }

  testWidgets('the bar measures dispatched against produced', (tester) async {
    await pump(
      tester,
      entry(cases: 40, perCase: 12, balanceCases: 15, balanceLabels: 180),
    );

    // Both figures are on the record: produced, and produced minus waiting.
    expect(bar(tester).linked, 25);
    expect(bar(tester).required_, 40);

    expect(find.text('Waiting for dispatch'), findsOneWidget);
    expect(find.text('15 cases'), findsOneWidget);
    expect(
      find.text('25 of 40 cases dispatched · 180 labels waiting.'),
      findsOneWidget,
    );
  });

  testWidgets('a fully dispatched entry fills the bar and says so', (
    tester,
  ) async {
    await pump(tester, entry(cases: 40, balanceCases: 0, balanceLabels: 0));

    expect(bar(tester).linked, 40);
    expect(bar(tester).required_, 40);
    expect(find.text('0 cases'), findsOneWidget);
    expect(
      find.text('All 40 cases have gone out on a dispatch.'),
      findsOneWidget,
    );

    // The balance is about dispatch, not the issuance the labels came from.
    expect(find.textContaining('issuance'), findsNothing);
  });

  testWidgets('an undispatched entry leaves the bar empty', (tester) async {
    await pump(
      tester,
      entry(cases: 33, perCase: 12, balanceCases: 33, balanceLabels: 396),
    );

    expect(bar(tester).linked, 0);
    expect(bar(tester).required_, 33);
    expect(
      find.text('None of this run has gone out yet — 396 labels waiting.'),
      findsOneWidget,
    );
  });

  testWidgets('the dispatched ranges are listed, with their unit', (
    tester,
  ) async {
    await pump(
      tester,
      entry(
        cases: 40,
        balanceCases: 20,
        balanceLabels: 240,
        ranges: [
          SerialRangeModel(total: 120, serialFrom: 110739001, serialTo: 110739120),
          SerialRangeModel(total: 120, serialFrom: 110739121, serialTo: 110739240),
        ],
      ),
    );

    expect(find.text('RANGES DISPATCHED'), findsOneWidget);
    expect(find.text('120 labels'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('nothing dispatched says so where the ranges would be', (
    tester,
  ) async {
    await pump(tester, entry(cases: 33, balanceCases: 33, balanceLabels: 396));

    expect(find.text('RANGES DISPATCHED'), findsOneWidget);
    expect(
      find.text('Nothing from this run has gone out on a dispatch yet.'),
      findsOneWidget,
    );
  });
}
