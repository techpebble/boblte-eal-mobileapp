import 'package:flutter/material.dart';

import 'package:eal_scanner/screens/scan/scan_target.dart';
import 'package:eal_scanner/theme/app_tokens.dart';
import 'package:eal_scanner/utils/formatting.dart';
import 'package:eal_scanner/widgets/ui/feedback.dart';
import 'package:eal_scanner/widgets/ui/serial_text.dart';

/// Confirmation, in place of a snackbar that was gone before anyone read it.
///
/// Says what was recorded, where the line now stands, and offers the two
/// things anyone does next — another range, or back out.
class ScanSuccessScreen extends StatelessWidget {
  const ScanSuccessScreen({
    super.key,
    required this.target,
    required this.draft,
    required this.labels,
    required this.cases,
    this.lineAfter,
  });

  final ScanTarget target;
  final ScanDraft draft;
  final int labels;
  final int cases;

  /// Cases linked to the line once this range landed.
  final int? lineAfter;

  bool get _leadsWithCases => target.unit == ScanUnit.cases;

  bool get _lineComplete =>
      target.hasTargetQuantity &&
      lineAfter != null &&
      lineAfter! >= target.requiredCases!;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Backing out of a confirmation means "finished", not "undo".
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, ScanOutcome.done);
      },
      child: Scaffold(
        backgroundColor: AppColors.canvas,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          // The bar carries nothing but the close button, so it takes the
          // page's colour rather than reading as an empty white header
          // above a grey screen.
          backgroundColor: AppColors.canvas,
          toolbarHeight: 52,
          actions: [
            IconButton(
              onPressed: () => Navigator.pop(context, ScanOutcome.done),
              icon: const Icon(Icons.close_rounded),
              tooltip: 'Close',
            ),
            const SizedBox(width: 6),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpace.gutter,
                  0,
                  AppSpace.gutter,
                  AppSpace.lg,
                ),
                children: [
                  Column(
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: const BoxDecoration(
                          color: AppColors.greenTint,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check_rounded,
                          size: 40,
                          color: AppColors.green,
                        ),
                      ),
                      const SizedBox(height: 19),
                      Text(
                        _leadsWithCases
                            ? '${formatCases(cases)} recorded'
                            : '${formatLabels(labels)} recorded',
                        textAlign: TextAlign.center,
                        style: AppText.headline,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        target.contextLine,
                        textAlign: TextAlign.center,
                        style: AppText.bodyMuted,
                      ),
                    ],
                  ),

                  const SizedBox(height: AppSpace.xxl),

                  // The receipt.
                  AppCard(
                    radius: AppRadius.card,
                    padding: const EdgeInsets.all(AppSpace.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SerialRangeText(
                          prefix: draft.prefix,
                          from: draft.from,
                          to: draft.to,
                          size: 14.5,
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 13),
                          child: Divider(),
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                _leadsWithCases
                                    ? formatLabels(labels)
                                    : formatCases(cases),
                                style: AppText.small,
                              ),
                            ),
                            const Icon(
                              Icons.cloud_done_outlined,
                              size: 15,
                              color: AppColors.green,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Saved ${formatClock(DateTime.now())}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.greenDeep,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  if (target.hasTargetQuantity && lineAfter != null) ...[
                    const SizedBox(height: AppSpace.md),
                    AppCard(
                      radius: AppRadius.card,
                      padding: const EdgeInsets.all(AppSpace.lg),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Expanded(
                                child: Text('This line', style: AppText.label),
                              ),
                              Text(
                                '${formatQty(lineAfter!)} / '
                                '${formatQty(target.requiredCases!)}',
                                style: AppText.mono(
                                  size: 13,
                                  weight: FontWeight.w600,
                                  color: _lineComplete
                                      ? AppColors.greenDeep
                                      : AppColors.caution,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 9),
                          LinkedProgressBar(
                            linked: lineAfter!,
                            required_: target.requiredCases!,
                            height: 8,
                          ),
                          const SizedBox(height: 13),
                          if (_lineComplete)
                            const NoticeBanner(
                              level: NoticeLevel.success,
                              title: 'Fully labelled',
                              message:
                                  'Every case on this line now has a label '
                                  'against it.',
                            )
                          else
                            NoticeBanner(
                              title: 'Still short',
                              message:
                                  '${formatCases(target.requiredCases! - lineAfter!)} '
                                  'on this line have no labels yet.',
                            ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpace.gutter,
                  10,
                  AppSpace.gutter,
                  16,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () =>
                          Navigator.pop(context, ScanOutcome.another),
                      icon: const Icon(Icons.qr_code_scanner_rounded, size: 19),
                      label: const Text('Record another range'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                      ),
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context, ScanOutcome.done),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: target.module.accent,
                      ),
                      child: const Text('Done'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
