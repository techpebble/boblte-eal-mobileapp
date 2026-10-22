import 'package:eal_scanner/theme/app_tokens.dart';
import 'package:eal_scanner/widgets/ui/feedback.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

/// Get.snackbar's own default is grey at a fifth of full opacity, which on
/// this app's pale canvas is no panel at all.
void main() {
  testWidgets('a message sits on a surface you can read it against', (
    tester,
  ) async {
    await tester.pumpWidget(
      GetMaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return TextButton(
                onPressed: () => showAppSnackbar(
                  'Could not load items',
                  'Demo Role is not allowed to see items. Ask an administrator.',
                ),
                child: const Text('go'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('go'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    final bar = tester.widget<GetSnackBar>(find.byType(GetSnackBar));

    expect(bar.backgroundColor, AppColors.surface);
    expect(bar.backgroundColor, isNot(Colors.transparent));
    expect(
      bar.backgroundColor.alpha,
      255,
      reason: 'a see-through panel is what made this unreadable',
    );
    expect(bar.borderColor, AppColors.red);
    expect(bar.boxShadows, isNotEmpty);

    // And both lines are actually on screen.
    expect(find.text('Could not load items'), findsOneWidget);
    expect(find.textContaining('Demo Role is not allowed'), findsOneWidget);

    // Its animation is still running, and the overlay complains if the tree
    // is torn down under it.
    Get.closeAllSnackbars();
    await tester.pumpAndSettle();
  });
}
