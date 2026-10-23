import 'package:eal_scanner/screens/scan/scanner_camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/api_test_support.dart';

/// The camera's frame is the one thing an operator aims with, so where it
/// sits matters more than how it looks.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeTestStorage();
  });

  Future<void> pump(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(
        home: ScannerCamera(
          stepLabel: 'Scan the first label',
          instruction: 'The lowest serial of the run.',
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('the frame is square and sits inside the screen', (tester) async {
    await pump(tester, const Size(1080, 2340));

    // The scan line is drawn in the middle of the frame. It used to run
    // across the middle of the screen, because the frame was a Positioned
    // handed back from a LayoutBuilder with no Stack to place it.
    final line = tester.getRect(find.byKey(const ValueKey('scanner-line')));
    final screen = tester.getRect(find.byType(ScannerCamera));

    expect(line.center.dy, lessThan(screen.center.dy));
    expect(line.left, greaterThan(screen.left + 20));
    expect(line.right, lessThan(screen.right - 20));
  });

  testWidgets('a short screen keeps the frame clear of the controls', (
    tester,
  ) async {
    await pump(tester, const Size(720, 1280));

    final line = tester.getRect(find.byKey(const ValueKey('scanner-line')));
    final torch = tester.getRect(find.text('Torch off'));

    // The box is held to two fifths of the height, so what is under it
    // is never crowded against it.
    expect(line.bottom, lessThan(torch.top));
    expect(tester.takeException(), isNull);
  });
}
