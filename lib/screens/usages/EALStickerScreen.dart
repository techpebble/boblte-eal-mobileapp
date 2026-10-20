import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:eal_scanner/controllers/usageController.dart';
import 'package:eal_scanner/models/items.dart';
import 'package:eal_scanner/screens/scan/scan_flow_screen.dart';
import 'package:eal_scanner/screens/scan/scan_target.dart';
import 'package:eal_scanner/theme/app_tokens.dart';
import 'package:eal_scanner/utils/formatting.dart';
import 'package:eal_scanner/widgets/ui/chips.dart';
import 'package:eal_scanner/widgets/ui/feedback.dart';
import 'package:eal_scanner/widgets/ui/picker_sheet.dart';
import 'package:eal_scanner/widgets/ui/serial_text.dart';

/// Recording labels applied to a bottling run.
///
/// The item list is refreshed before the picker opens, so an item
/// deactivated mid-shift cannot be chosen — behaviour the old screen had and
/// which the test suite pins.
class EALStickerScreen extends StatefulWidget {
  const EALStickerScreen({super.key});

  @override
  State<EALStickerScreen> createState() => _EALStickerScreenState();
}

class _EALStickerScreenState extends State<EALStickerScreen> {
  final UsageController _controller = Get.find<UsageController>();

  DateTime _date = DateTime.now();
  Item? _item;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _controller.currentProduction.clear();
      _controller.fetchItems();
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2023),
      lastDate: DateTime(2035),
    );
    if (picked != null && mounted) setState(() => _date = picked);
  }

  Future<void> _pickItem() async {
    // Refresh first: an item may have been deactivated while this screen
    // was open, and a production entry against it would be rejected.
    await _controller.fetchItems();
    if (!mounted) return;

    final recentIds = _controller.currentProduction
        .map((p) => p.itemName)
        .toSet();

    final chosen = await showPickerSheet<Item>(
      context: context,
      title: 'Choose item',
      subtitle: 'Only items active right now can be entered.',
      searchHint: 'Item name or code',
      accent: AppColors.teal,
      selected: _item,
      showActiveFilter: true,
      emptyMessage: 'No active items found.',
      recentValues: _controller.items
          .where((i) => recentIds.contains(i.name))
          .toList(),
      options: _controller.items
          .map(
            (i) => PickerOption<Item>(
              value: i,
              label: i.name,
              isActive: i.isActive,
              inactiveNote: 'Discontinued',
              chips: [
                i.itemCode,
                '${i.bottlesPerCase} per case',
                titleCase(i.market),
              ],
            ),
          )
          .toList(),
    );

    if (chosen != null && mounted) setState(() => _item = chosen);
  }

  Future<void> _scanRange() async {
    final item = _item;
    if (item == null) return;

    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ScanFlowScreen(
          target: ScanTarget(
            module: AppModule.production,
            title: 'Record production',
            contextLine: '${item.name} · ${titleCase(item.market)}',
            bottlesPerCase: item.bottlesPerCase,
            unit: ScanUnit.cases,
            submit: (draft) {
              final labels = draft.labels;
              final cases = draft.casesFor(item.bottlesPerCase);

              return _controller.addEALUsage(
                company: item.company,
                dateUsed: _date,
                market: item.market,
                item: item.id,
                pack: item.pack,
                prefix: draft.prefix,
                serialFrom: draft.serialFrom,
                serialTo: draft.serialTo,
                usedQuantity: labels,
                usedQuantityInCases: cases,
              );
            },
          ),
        ),
      ),
    );

    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        shape: const Border(
          bottom: BorderSide(color: AppColors.line, width: 1),
        ),
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close_rounded),
          tooltip: 'Close',
        ),
        title: const Text('New production entry', style: AppText.appBarTitle),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: OutlinedButton.icon(
              onPressed: _pickDate,
              icon: const Icon(Icons.calendar_today_rounded, size: 15),
              label: Text(formatDayMonth(_date)),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 38),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                textStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Obx(() {
        final recorded = _controller.currentProduction;
        final item = _item;

        return ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.gutter,
            AppSpace.lg,
            AppSpace.gutter,
            AppSpace.xxl,
          ),
          children: [
            const SectionHeading('Item produced'),
            if (item == null)
              AppCard(
                onTap: _pickItem,
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.tealTint,
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: const Icon(
                        Icons.liquor_outlined,
                        size: 21,
                        color: AppColors.teal,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Choose item',
                        style: AppText.cardTitle.copyWith(
                          color: AppColors.ink500,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      size: 20,
                      color: AppColors.ink400,
                    ),
                  ],
                ),
              )
            else
              AppCard(
                onTap: _pickItem,
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.tealTint,
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: const Icon(
                        Icons.liquor_outlined,
                        size: 21,
                        color: AppColors.teal,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.name,
                            style: AppText.cardTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              MetaChip(item.itemCode),
                              MetaChip(
                                '${item.bottlesPerCase} per case',
                                background: AppColors.tealTint,
                                foreground: AppColors.tealDeep,
                              ),
                              MarketChip(item.market, dense: true),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      size: 20,
                      color: AppColors.ink400,
                    ),
                  ],
                ),
              ),

            const SizedBox(height: AppSpace.xl),
            SectionHeading(
              'Recorded in this session',
              trailing: Text(
                '${recorded.length}',
                style: AppText.mono(
                  size: 12,
                  weight: FontWeight.w600,
                  color: AppColors.ink500,
                ),
              ),
            ),

            if (recorded.isEmpty)
              AppCard(
                padding: const EdgeInsets.all(18),
                child: Text(
                  item == null
                      ? 'Choose the item that was bottled, then scan the '
                          'labels used.'
                      : 'Nothing yet. Scan the first and last label of the '
                          'run.',
                  style: AppText.small,
                ),
              )
            else
              AppCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (var i = 0; i < recorded.length; i++)
                      _RecordedRow(
                        prefix: recorded[i].prefix,
                        from: int.tryParse(recorded[i].serialFrom) ?? 0,
                        to: int.tryParse(recorded[i].serialTo) ?? 0,
                        labels: recorded[i].usedQuantity,
                        cases: recorded[i].usedQuantityInCases,
                        isLast: i == recorded.length - 1,
                      ),
                  ],
                ),
              ),

            const SizedBox(height: 10),
            _ScanButton(
              enabled: item != null,
              accent: AppColors.teal,
              label: recorded.isEmpty ? 'Scan a range' : 'Scan another range',
              onTap: _scanRange,
            ),

            if (item != null) ...[
              const SizedBox(height: AppSpace.md),
              NoticeBanner(
                level: NoticeLevel.info,
                title: 'Ranges must come from an issuance',
                message: 'The labels you scan have to be on an issuance for '
                    'this pack size, or the server will refuse the entry.',
              ),
            ],
          ],
        );
      }),
      bottomNavigationBar: Obx(() {
        final recorded = _controller.currentProduction;
        final cases = recorded.fold<int>(
          0,
          (sum, r) => sum + r.usedQuantityInCases,
        );
        final labels = recorded.fold<int>(0, (sum, r) => sum + r.usedQuantity);

        return Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(top: BorderSide(color: AppColors.line, width: 1)),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.gutter,
                12,
                AppSpace.gutter,
                12,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text('Recorded so far', style: AppText.small),
                      ),
                      Text(formatQty(cases), style: AppText.figure(size: 19)),
                      const SizedBox(width: 5),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Text(
                          'cases · ${formatQty(labels)} labels',
                          style: AppText.micro,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 11),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.teal,
                    ),
                    child: Text(recorded.isEmpty ? 'Close' : 'Done'),
                  ),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _ScanButton extends StatelessWidget {
  const _ScanButton({
    required this.enabled,
    required this.accent,
    required this.label,
    required this.onTap,
  });

  final bool enabled;
  final Color accent;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: AppRadius.brControl,
      child: Container(
        height: 50,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.brControl,
          border: Border.all(
            color: enabled ? accent : AppColors.lineField,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.qr_code_scanner_rounded,
              size: 19,
              color: enabled ? accent : AppColors.ink400,
            ),
            const SizedBox(width: 9),
            Text(
              label,
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
                color: enabled ? accent : AppColors.ink500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecordedRow extends StatelessWidget {
  const _RecordedRow({
    required this.prefix,
    required this.from,
    required this.to,
    required this.labels,
    required this.cases,
    required this.isLast,
  });

  final String prefix;
  final int from;
  final int to;
  final int labels;
  final int cases;
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
          const Icon(
            Icons.check_circle_outline_rounded,
            size: 19,
            color: AppColors.green,
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SerialRangeText(
                  prefix: prefix,
                  from: from,
                  to: to,
                  size: 13.5,
                ),
                const SizedBox(height: 3),
                Text(
                  '${formatCases(cases)} · ${formatLabels(labels)}',
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
