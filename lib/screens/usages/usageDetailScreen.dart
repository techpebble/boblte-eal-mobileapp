import 'package:flutter/material.dart';

import 'package:eal_scanner/models/usage.dart';
import 'package:eal_scanner/theme/app_tokens.dart';
import 'package:eal_scanner/utils/formatting.dart';
import 'package:eal_scanner/widgets/ui/chips.dart';
import 'package:eal_scanner/widgets/ui/feedback.dart';
import 'package:eal_scanner/widgets/ui/serial_text.dart';

/// One production entry. The headline figure is cases, because that is the
/// unit the floor counts in; labels sit beside it.
///
/// The old screen's app bar read "EAL Issuance Detail" here.
class EALUsageDetailScreen extends StatelessWidget {
  const EALUsageDetailScreen({super.key, required this.usage});

  final UsageModel usage;

  int get _from => int.tryParse(usage.serialFrom) ?? 0;
  int get _to => int.tryParse(usage.serialTo) ?? 0;

  /// What this entry produced that has not gone out on a dispatch yet.
  ///
  /// On a usage record the balance starts equal to what was produced and is
  /// drawn down as cases are linked to a dispatch — it says nothing about
  /// the issuance the labels came from, which keeps its own balance.
  int get _waitingCases => usage.balanceQuantityInCases;
  int get _waitingLabels => usage.balanceQuantity;
  int get _dispatchedCases => usage.usedQuantityInCases - _waitingCases;

  bool get _allDispatched => _waitingCases <= 0;
  bool get _noneDispatched => _dispatchedCases <= 0;

  /// Worth a section of its own only when it says something the card above
  /// does not: more than one range, or a single one that differs from the
  /// entry's own.
  bool get _showRanges {
    final ranges = usage.usedSerialRanges;
    if (ranges.length > 1) return true;
    if (ranges.isEmpty) return false;
    return ranges.single.serialFrom != _from || ranges.single.serialTo != _to;
  }

  @override
  Widget build(BuildContext context) {
    final ranges = usage.usedSerialRanges;

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        shape: const Border(
          bottom: BorderSide(color: AppColors.line, width: 1),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              usage.itemName,
              style: AppText.appBarTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              'Entered ${formatDayMonthYear(usage.dateUsed)}',
              style: const TextStyle(fontSize: 11.5, color: AppColors.ink500),
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpace.gutter,
          AppSpace.lg,
          AppSpace.gutter,
          AppSpace.xxl,
        ),
        children: [
          AppCard(
            radius: AppRadius.card,
            padding: const EdgeInsets.all(AppSpace.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('PRODUCED', style: AppText.section),
                        const SizedBox(height: 3),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              formatQty(usage.usedQuantityInCases),
                              style: AppText.figure(
                                size: 33,
                                color: AppColors.tealDeep,
                              ),
                            ),
                            const SizedBox(width: 7),
                            const Text(
                              'cases',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.ink500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const Spacer(),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 5),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            formatQty(usage.usedQuantity),
                            style: AppText.mono(
                              size: 16,
                              weight: FontWeight.w600,
                              color: AppColors.ink700,
                            ),
                          ),
                          const Text('labels', style: AppText.micro),
                        ],
                      ),
                    ),
                  ],
                ),

                const Padding(
                  padding: EdgeInsets.only(top: AppSpace.lg, bottom: 3),
                  child: Divider(),
                ),

                _MetaRow(
                  label: 'Labels used',
                  child: SerialRangeText(
                    prefix: usage.prefix,
                    from: _from,
                    to: _to,
                    size: 13.5,
                    showPrefix: false,
                  ),
                ),
                _MetaRow(
                  label: 'Pack',
                  child: Text(usage.packName, style: AppText.label),
                ),
                _MetaRow(
                  label: 'Market',
                  child: MarketChip(usage.market, dense: true),
                ),
                _MetaRow(
                  label: 'Company',
                  isLast: true,
                  child: Text(
                    usage.companyName,
                    style: AppText.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          if (_showRanges) ...[
          const SizedBox(height: AppSpace.xl),
          SectionHeading(
            'Ranges in this entry',
            trailing: Text(
              '${ranges.length}',
              style: AppText.mono(
                size: 12,
                weight: FontWeight.w600,
                color: AppColors.ink500,
              ),
            ),
          ),

          AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (var i = 0; i < ranges.length; i++)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 13,
                      ),
                      decoration: BoxDecoration(
                        border: i == ranges.length - 1
                            ? null
                            : const Border(
                                bottom: BorderSide(
                                  color: AppColors.lineSoft,
                                  width: 1,
                                ),
                              ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 30,
                            height: 30,
                            decoration: const BoxDecoration(
                              color: AppColors.tealTint,
                              borderRadius: BorderRadius.all(
                                Radius.circular(8),
                              ),
                            ),
                            child: const Icon(
                              Icons.qr_code_2_rounded,
                              size: 16,
                              color: AppColors.teal,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: SerialRangeText(
                              prefix: usage.prefix,
                              from: ranges[i].serialFrom,
                              to: ranges[i].serialTo,
                              size: 13.5,
                              showPrefix: false,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Pill(
                            label: formatLabels(ranges[i].total),
                            background: AppColors.tealTint,
                            foreground: AppColors.tealDeep,
                            fontSize: 12,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],

          const SizedBox(height: AppSpace.lg),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Waiting for dispatch',
                        style: AppText.small,
                      ),
                    ),
                    Text(
                      formatCases(_waitingCases),
                      style: AppText.mono(
                        size: 14,
                        weight: FontWeight.w600,
                        color: _allDispatched
                            ? AppColors.ink500
                            : AppColors.ink900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                if (_allDispatched)
                  Row(
                    children: [
                      const Icon(
                        Icons.check_rounded,
                        size: 14,
                        color: AppColors.green,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'All ${formatCases(usage.usedQuantityInCases)} have '
                          'gone out on a dispatch.',
                          style: AppText.micro,
                        ),
                      ),
                    ],
                  )
                else if (_noneDispatched)
                  Text(
                    '${formatLabels(_waitingLabels)}, none of it dispatched '
                    'yet.',
                    style: AppText.micro,
                  )
                else
                  Text(
                    '${formatLabels(_waitingLabels)}. '
                    '${formatCases(_dispatchedCases)} already dispatched.',
                    style: AppText.micro,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({
    required this.label,
    required this.child,
    this.isLast = false,
  });

  final String label;
  final Widget child;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(
                bottom: BorderSide(color: AppColors.lineSoft, width: 1),
              ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 96,
            child: Text(label, style: AppText.small),
          ),
          Expanded(child: Align(alignment: Alignment.centerLeft, child: child)),
        ],
      ),
    );
  }
}
