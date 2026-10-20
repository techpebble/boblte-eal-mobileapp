import 'package:eal_scanner/controllers/issuanceController.dart';
import 'package:eal_scanner/models/issuance.dart';
import 'package:eal_scanner/screens/issuance/issuanceDetailScreen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'support/api_test_support.dart';

/// An issuance can be removed only while none of it has been applied.
///
/// The server is the real guard — it refuses while any production entry
/// points at the issuance — but the option itself has to be honest about
/// whether it will work, rather than failing after the fact.
IssuanceModel issuanceWith({
  required int issued,
  required int balance,
  List<SerialRangeModel> usedRanges = const [],
}) {
  return IssuanceModel(
    id: '64a000000000000000000009',
    companyName: 'Unit 2 Bottling',
    packName: 'Pack 750 ml',
    market: 'local',
    prefix: 'ML1',
    serialFrom: '0000012001',
    serialTo: '0000060000',
    issuedQuantity: issued,
    balanceQuantity: balance,
    dateIssued: DateTime(2026, 10, 20),
    usedSerialRanges: usedRanges,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeTestStorage();
  });

  setUp(() => Get.put(Issuancecontroller()));
  tearDown(() => Get.reset());

  Future<void> openMenu(WidgetTester tester, IssuanceModel issuance) async {
    await tester.pumpWidget(
      GetMaterialApp(home: EALIssuanceDetailScreen(issuance: issuance)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
  }

  bool removeIsEnabled(WidgetTester tester) {
    final item = tester.widget<PopupMenuItem<String>>(
      find.byType(PopupMenuItem<String>).first,
    );
    return item.enabled;
  }

  testWidgets('an untouched issuance offers removal', (tester) async {
    await openMenu(tester, issuanceWith(issued: 48000, balance: 48000));

    expect(find.text('Remove issuance'), findsOneWidget);
    expect(removeIsEnabled(tester), isTrue);
  });

  testWidgets('a partly used issuance does not', (tester) async {
    await openMenu(tester, issuanceWith(issued: 48000, balance: 12000));

    // Still listed, so nobody hunts for a missing option — but it says why.
    expect(find.text('Remove issuance'), findsOneWidget);
    expect(removeIsEnabled(tester), isFalse);
    expect(find.textContaining('already used'), findsOneWidget);
  });

  testWidgets('a fully used issuance does not', (tester) async {
    await openMenu(tester, issuanceWith(issued: 48000, balance: 0));

    expect(removeIsEnabled(tester), isFalse);
  });

  testWidgets(
    'used ranges block removal even when the balance looks untouched',
    (tester) async {
      // The two figures disagreeing means something is already off; the
      // safe reading is that labels have gone out.
      await openMenu(
        tester,
        issuanceWith(
          issued: 48000,
          balance: 48000,
          usedRanges: [
            SerialRangeModel(serialFrom: 12001, serialTo: 12012, total: 12),
          ],
        ),
      );

      expect(removeIsEnabled(tester), isFalse);
    },
  );
}
