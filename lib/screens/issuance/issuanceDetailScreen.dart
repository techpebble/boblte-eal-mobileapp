import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:eal_scanner/controllers/issuanceController.dart';
import 'package:eal_scanner/models/issuance.dart';
import 'package:eal_scanner/theme/app_tokens.dart';
import 'package:eal_scanner/utils/formatting.dart';
import 'package:eal_scanner/widgets/ui/chips.dart';
import 'package:eal_scanner/widgets/ui/feedback.dart';
import 'package:eal_scanner/widgets/ui/serial_text.dart';

/// One issuance: the range it covers, how much of it is spent, and the runs
/// that spent it.
class EALIssuanceDetailScreen extends StatefulWidget {
  const EALIssuanceDetailScreen({super.key, required this.issuance});

  final IssuanceModel issuance;

  @override
  State<EALIssuanceDetailScreen> createState() =>
      _EALIssuanceDetailScreenState();
}

class _EALIssuanceDetailScreenState extends State<EALIssuanceDetailScreen> {
  bool _busy = false;
  String _error = '';

  IssuanceModel get issuance => widget.issuance;

  int get _from => int.tryParse(issuance.serialFrom) ?? 0;
  int get _to => int.tryParse(issuance.serialTo) ?? 0;
  int get _used => issuance.issuedQuantity - issuance.balanceQuantity;

  /// Removable only while nothing has been drawn from it. The server checks
  /// this too and is the real guard; this just keeps the option honest.
  bool get _untouched => _used <= 0 && issuance.usedSerialRanges.isEmpty;

  @override
  Widget build(BuildContext context) {
    final ranges = issuance.usedSerialRanges;
    final complete = issuance.balanceQuantity <= 0;

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
              issuance.packName,
              style: AppText.appBarTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              'Issued ${formatDayMonthYear(issuance.dateIssued)}',
              style: const TextStyle(fontSize: 11.5, color: AppColors.ink500),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            enabled: !_busy,
            tooltip: 'More options',
            onSelected: (_) => _confirmRemove(),
            itemBuilder: (_) => [
              PopupMenuItem<String>(
                value: 'remove',
                // Listed either way: an option that vanishes leaves people
                // hunting for it. Disabled, it says why instead.
                enabled: _untouched,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Remove issuance',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        color: _untouched ? AppColors.red : AppColors.ink500,
                      ),
                    ),
                    if (!_untouched)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          '${formatQty(_used)} labels already used',
                          style: AppText.micro,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpace.gutter,
          AppSpace.lg,
          AppSpace.gutter,
          AppSpace.xxl,
        ),
        children: [
          if (_error.isNotEmpty) ...[
            NoticeBanner(
              level: NoticeLevel.error,
              title: 'Could not remove this issuance',
              message: _error,
              trailing: IconButton(
                onPressed: () => setState(() => _error = ''),
                icon: const Icon(Icons.close_rounded, size: 18),
                tooltip: 'Dismiss',
              ),
            ),
            const SizedBox(height: AppSpace.md),
          ],
          AppCard(
            radius: AppRadius.card,
            padding: const EdgeInsets.all(AppSpace.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text('ISSUED RANGE', style: AppText.section),
                    ),
                    MarketChip(issuance.market),
                  ],
                ),
                const SizedBox(height: 13),
                SerialRangeBlock(
                  prefix: issuance.prefix,
                  from: _from,
                  to: _to,
                ),

                const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpace.lg),
                  child: Divider(),
                ),

                Row(
                  children: [
                    Expanded(
                      child: FigureTile(
                        value: formatQty(issuance.issuedQuantity),
                        label: 'issued',
                      ),
                    ),
                    Expanded(
                      child: FigureTile(
                        value: formatQty(issuance.balanceQuantity),
                        label: complete ? 'fully used' : 'unused',
                        color: complete
                            ? AppColors.greenDeep
                            : AppColors.caution,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: AppSpace.lg),
                LinkedProgressBar(
                  linked: _used,
                  required_: issuance.issuedQuantity,
                  height: 8,
                  accent: complete ? AppColors.green : AppColors.indigo,
                  label: Text(
                    '${formatQty(_used)} used in '
                    '${ranges.length} ${ranges.length == 1 ? 'run' : 'runs'}',
                    style: AppText.small,
                  ),
                  trailing: Text(
                    issuance.issuedQuantity == 0
                        ? '—'
                        : '${((_used / issuance.issuedQuantity) * 100).round()}%',
                    style: AppText.mono(
                      size: 12.5,
                      weight: FontWeight.w600,
                      color: AppColors.ink500,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpace.xl),
          SectionHeading(
            'Used in production',
            trailing: Text(
              '${ranges.length}',
              style: AppText.mono(
                size: 12,
                weight: FontWeight.w600,
                color: AppColors.ink500,
              ),
            ),
          ),

          if (ranges.isEmpty)
            AppCard(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  const Icon(
                    Icons.inbox_outlined,
                    size: 20,
                    color: AppColors.ink500,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'None of these labels have been applied yet. All '
                      '${formatQty(issuance.issuedQuantity)} are still '
                      'available.',
                      style: AppText.small,
                    ),
                  ),
                ],
              ),
            )
          else
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (var i = 0; i < ranges.length; i++)
                    _UsedRangeRow(
                      prefix: issuance.prefix,
                      from: ranges[i].serialFrom,
                      to: ranges[i].serialTo,
                      total: ranges[i].total,
                      isLast: i == ranges.length - 1,
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// Confirms, then removes. The dialog repeats the range and the quantity,
  /// because an issuance is identified by its serials and nothing else.
  Future<void> _confirmRemove() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove this issuance?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Nothing has been applied from it, so removing it takes '
              '${formatLabels(issuance.issuedQuantity)} back off the books. '
              'This cannot be undone.',
              style: AppText.bodyMuted,
            ),
            const SizedBox(height: AppSpace.lg),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                color: AppColors.canvas,
                borderRadius: AppRadius.brControl,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(issuance.packName, style: AppText.label),
                  const SizedBox(height: 6),
                  SerialRangeText(
                    prefix: issuance.prefix,
                    from: _from,
                    to: _to,
                    size: 13.5,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep it'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.red,
              minimumSize: const Size(0, 44),
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      _busy = true;
      _error = '';
    });

    final error =
        await Get.find<Issuancecontroller>().deleteEALIssuance(issuance.id);

    if (!mounted) return;

    if (error != null) {
      setState(() {
        _busy = false;
        _error = error;
      });
      return;
    }

    // The controller has already dropped it from the list behind us.
    Navigator.of(context).pop();
  }
}

class _UsedRangeRow extends StatelessWidget {
  const _UsedRangeRow({
    required this.prefix,
    required this.from,
    required this.to,
    required this.total,
    required this.isLast,
  });

  final String prefix;
  final int from;
  final int to;
  final int total;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(
                bottom: BorderSide(color: AppColors.lineSoft, width: 1),
              ),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: const BoxDecoration(
              color: AppColors.tealTint,
              borderRadius: BorderRadius.all(Radius.circular(8)),
            ),
            child: const Icon(
              Icons.factory_outlined,
              size: 16,
              color: AppColors.teal,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SerialRangeText(
              prefix: prefix,
              from: from,
              to: to,
              size: 13.5,
              showPrefix: false,
            ),
          ),
          const SizedBox(width: 8),
          Pill(
            label: formatQty(total),
            background: AppColors.indigoTint,
            foreground: AppColors.indigoDeep,
            fontSize: 12,
          ),
        ],
      ),
    );
  }
}
