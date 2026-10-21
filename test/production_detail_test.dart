import 'package:eal_scanner/models/usage.dart';
import 'package:eal_scanner/screens/usages/usageDetailScreen.dart';
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

  testWidgets('a fully dispatched entry says so, with no bar beside a zero', (
    tester,
  ) async {
    await pump(tester, entry(cases: 40, balanceCases: 0, balanceLabels: 0));

    // The balance on a usage counts what has NOT gone out on a dispatch; it
    // says nothing about the issuance the labels came from.
    expect(find.text('Waiting for dispatch'), findsOneWidget);
    expect(find.textContaining('issuance'), findsNothing);
    expect(find.text('0 cases'), findsOneWidget);
    expect(
      find.text('All 40 cases have gone out on a dispatch.'),
      findsOneWidget,
    );
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  testWidgets('an undispatched entry says none of it has gone', (
    tester,
  ) async {
    await pump(
      tester,
      entry(cases: 33, perCase: 12, balanceCases: 33, balanceLabels: 396),
    );

    expect(find.text('33 cases'), findsOneWidget);
    expect(find.text('396 labels, none of it dispatched yet.'), findsOneWidget);
  });

  testWidgets('a part-dispatched entry says how much has gone', (
    tester,
  ) async {
    await pump(
      tester,
      entry(cases: 40, perCase: 12, balanceCases: 15, balanceLabels: 180),
    );

    expect(find.text('15 cases'), findsOneWidget);
    expect(
      find.text('180 labels. 25 cases already dispatched.'),
      findsOneWidget,
    );
  });

  testWidgets('a single range matching the entry is not listed twice', (
    tester,
  ) async {
    await pump(
      tester,
      entry(
        ranges: [
          SerialRangeModel(total: 480, serialFrom: 110739001, serialTo: 110739480),
        ],
      ),
    );

    expect(find.text('Labels used'), findsOneWidget);
    expect(find.text('RANGES IN THIS ENTRY'), findsNothing);
  });

  testWidgets('several ranges are listed, with their unit', (tester) async {
    await pump(
      tester,
      entry(
        ranges: [
          SerialRangeModel(total: 240, serialFrom: 110739001, serialTo: 110739240),
          SerialRangeModel(total: 240, serialFrom: 110739241, serialTo: 110739480),
        ],
      ),
    );

    expect(find.text('RANGES IN THIS ENTRY'), findsOneWidget);
    expect(find.text('240 labels'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });
}
