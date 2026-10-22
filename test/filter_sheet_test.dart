import 'package:eal_scanner/controllers/dispatchController.dart';
import 'package:eal_scanner/controllers/issuanceController.dart';
import 'package:eal_scanner/controllers/usageController.dart';
import 'package:eal_scanner/screens/dispatches/dispatch_filter_sheet.dart';
import 'package:eal_scanner/screens/issuance/issuance_filter_sheet.dart';
import 'package:eal_scanner/screens/usages/production_filter_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'support/api_test_support.dart';

/// The three filter sheets are the same control twice over, so they are
/// pinned together: a picker field that is shorter than the choices beside
/// it, or that grows once something is picked, reads as a mistake on every
/// one of them at once.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeTestStorage();
  });

  tearDown(() => Get.reset());

  Future<void> pump(WidgetTester tester, Widget sheet) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.8125;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      GetMaterialApp(
        home: Scaffold(
          // Keyed, or a second pump reuses the first sheet's State and
          // never re-reads the controller.
          body: SingleChildScrollView(
            child: KeyedSubtree(key: UniqueKey(), child: sheet),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// The box the label sits in, which is the control the design sizes.
  double fieldHeight(WidgetTester tester, String label) {
    return tester
        .getRect(
          find
              .ancestor(of: find.text(label), matching: find.byType(Container))
              .first,
        )
        .height;
  }

  for (final (name, register, sheet, anyLabel, setter, setLabel) in [
    (
      'issuance',
      () => Get.put(Issuancecontroller()),
      () => const IssuanceFilterSheet(),
      'Any company',
      () => Get.find<Issuancecontroller>().filterCompany.value = 'Zenith',
      'Zenith',
    ),
    (
      'production',
      () => Get.put(UsageController()),
      () => const ProductionFilterSheet(),
      'Any company',
      () => Get.find<UsageController>().filterCompany.value = 'Zenith',
      'Zenith',
    ),
    (
      'dispatch',
      () => Get.put(DispatchController()),
      () => const DispatchFilterSheet(),
      'Any depot',
      () => Get.find<DispatchController>().filterDepot.value = 'Central Depot',
      'Central Depot',
    ),
  ]) {
    testWidgets('$name: the picker field is the height the design gives it', (
      tester,
    ) async {
      register();
      await pump(tester, sheet());

      // The design puts the picker at 56 and the market choices at 46.
      // Padding round a Row made it about 38 — shorter than the choices.
      expect(fieldHeight(tester, anyLabel), closeTo(56, 1.5));
      expect(fieldHeight(tester, 'Any'), closeTo(46, 1.5));
    });

    testWidgets('$name: it does not grow once something is picked', (
      tester,
    ) async {
      register();
      await pump(tester, sheet());
      final empty = fieldHeight(tester, anyLabel);

      // Set it before the sheet is built: the sheet reads the controller
      // once, into its own held choices.
      setter();
      await pump(tester, sheet());

      // The clear button is a full-sized IconButton, which took the field
      // to about 66 — the control jumped as soon as it was used.
      expect(find.byTooltip('Clear'), findsOneWidget);
      expect(fieldHeight(tester, setLabel), closeTo(empty, 1.5));
    });
  }
}
