import 'package:eal_scanner/screens/scan/scan_flow_screen.dart';
import 'package:eal_scanner/screens/scan/scan_target.dart';
import 'package:eal_scanner/theme/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import 'support/api_test_support.dart';

/// Typing a serial instead of scanning it.
///
/// A scan reads the number off the label; typing it is where a transposed
/// digit becomes a real serial belonging to somebody else's run. So the
/// offer is made only to a role holding scan:manual, and the server is
/// told which way the range was obtained.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late GetStorage storage;

  setUpAll(() async {
    await initializeTestStorage();
    storage = GetStorage();
  });

  // The storage container is shared across the suite, so the signed-in
  // role has to be put back or it leaks into the next file.
  tearDown(() async {
    Get.reset();
    await storage.remove('auth_user');
  });

  Future<void> signedInAs(String role, List<String> permissions) =>
      storage.write('auth_user', {
        'fullName': 'Thomas Louis',
        'role': {
          '_id': '64a000000000000000000009',
          'name': role,
          'isSystem': false,
          'permissions': permissions,
        },
      });

  ScanTarget target() => ScanTarget(
    module: AppModule.issuance,
    title: 'Record issuance',
    contextLine: '90ml · Local · Blue Ocean Beverages Pvt. Ltd.',
    bottlesPerCase: 96,
    unit: ScanUnit.labels,
    initialPrefix: 'EXT',
    submit: (_) async => null,
  );

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.8125;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(home: ScanFlowScreen(target: target())),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('without the permission, scanning is the only way in', (
    tester,
  ) async {
    await signedInAs('Field Operator', ['issuance:create']);
    await pump(tester);

    expect(find.text('Open scanner'), findsOneWidget);
    expect(find.text('Label damaged? Type it by hand'), findsNothing);

    // Said rather than hidden: someone holding a torn label needs to know
    // what happens next.
    expect(
      find.textContaining('typed in by someone who may do that'),
      findsOneWidget,
    );
  });

  testWidgets('with it, the way out of a torn label is offered', (
    tester,
  ) async {
    await signedInAs('Field Operator', ['issuance:create', 'scan:manual']);
    await pump(tester);

    expect(find.text('Label damaged? Type it by hand'), findsOneWidget);
    expect(
      find.textContaining('typed in by someone who may do that'),
      findsNothing,
    );
  });

  test('a draft knows whether it was typed or scanned', () {
    const scanned = ScanDraft(prefix: 'EXT', serialFrom: '1', serialTo: '96');
    expect(scanned.typedByHand, isFalse);

    // Either end typed makes the record a typed one: the wrong digit can
    // be in either.
    expect(const ScanDraft(fromTypedByHand: true).typedByHand, isTrue);
    expect(const ScanDraft(toTypedByHand: true).typedByHand, isTrue);
  });
}
