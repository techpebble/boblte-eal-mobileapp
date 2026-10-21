import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:eal_scanner/controllers/issuanceController.dart';
import 'package:eal_scanner/models/company.dart';
import 'package:eal_scanner/models/packSize.dart';
import 'package:eal_scanner/screens/scan/scan_flow_screen.dart';
import 'package:eal_scanner/screens/scan/scan_target.dart';
import 'package:eal_scanner/theme/app_tokens.dart';
import 'package:eal_scanner/utils/formatting.dart';
import 'package:eal_scanner/widgets/ui/chips.dart';
import 'package:eal_scanner/widgets/ui/feedback.dart';
import 'package:eal_scanner/widgets/ui/picker_sheet.dart';

/// Asks what one set of stickers is, within an issuance.
///
/// Returns true once a range has been recorded, so the issuance screen knows
/// to refresh. A sheet rather than a screen: it is two fields on the way to
/// the scanner, and the list of what has already been added stays visible
/// behind it.
Future<bool?> showStickerDetailsSheet({
  required BuildContext context,
  required Company company,
  required DateTime date,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => StickerDetailsSheet(company: company, date: date),
  );
}

/// A purchase arrives as several sets of stickers, each with its own pack
/// size, market, prefix and range. The date and company belong to the whole
/// issuance and are settled before this sheet opens; these two fields are
/// what makes one set different from the next.
class StickerDetailsSheet extends StatefulWidget {
  const StickerDetailsSheet({
    super.key,
    required this.company,
    required this.date,
  });

  final Company company;
  final DateTime date;

  @override
  State<StickerDetailsSheet> createState() => _StickerDetailsSheetState();
}

class _StickerDetailsSheetState extends State<StickerDetailsSheet> {
  final Issuancecontroller _controller = Get.find<Issuancecontroller>();

  PackSize? _pack;
  String _market = 'local';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_controller.packs.isEmpty) _controller.fetchPackSizes();
    });
  }

  Future<void> _pickPack() async {
    final chosen = await showPickerSheet<PackSize>(
      context: context,
      title: 'Choose pack size',
      searchHint: 'Pack size',
      accent: AppColors.indigo,
      selected: _pack,
      emptyMessage: 'No pack sizes have been set up yet.',
      options: _controller.packs
          .map(
            (p) => PickerOption<PackSize>(
              value: p,
              label: p.name,
              chips: ['${p.bottlesPerCase} per case'],
            ),
          )
          .toList(),
    );
    if (chosen != null && mounted) setState(() => _pack = chosen);
  }

  /// Straight on to the prefix and the two ends. The sheet stays open under
  /// the scanner, so backing out of the scan keeps these choices.
  Future<void> _continue() async {
    final pack = _pack;
    if (pack == null) return;

    final recorded = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ScanFlowScreen(
          target: ScanTarget(
            module: AppModule.issuance,
            title: 'Record issuance',
            contextLine: '${pack.name} · ${titleCase(_market)} · '
                '${widget.company.name}',
            bottlesPerCase: pack.bottlesPerCase,
            unit: ScanUnit.labels,
            // Some issuance labels carry the whole range in one code.
            allowRangeQr: true,
            submit: (draft) => _controller.addEALIssuance(
              company: widget.company,
              dateIssued: widget.date,
              market: _market,
              pack: pack,
              prefix: draft.prefix,
              serialFrom: draft.serialFrom,
              serialTo: draft.serialTo,
              issuedQuantity: draft.labels,
            ),
          ),
        ),
      ),
    );

    if (!mounted || recorded != true) return;
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final pack = _pack;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.86,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpace.gutter,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Sticker details', style: AppText.title),
                        const SizedBox(height: 2),
                        Text(
                          '${widget.company.name} · '
                          '${formatDayMonth(widget.date)}',
                          style: AppText.small,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, size: 19),
                    tooltip: 'Close',
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.canvas,
                      foregroundColor: AppColors.ink700,
                    ),
                  ),
                ],
              ),
            ),

            Flexible(
              child: Obx(() {
                // Read so the sheet rebuilds once the pack list arrives.
                final packs = _controller.packs.length;

                return ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(
                    AppSpace.gutter,
                    AppSpace.md,
                    AppSpace.gutter,
                    0,
                  ),
                  children: [
                    AppCard(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          PickerField(
                            label: 'Pack size',
                            value: pack == null
                                ? null
                                : '${pack.name} · '
                                    '${pack.bottlesPerCase} per case',
                            icon: Icons.inventory_2_outlined,
                            onTap: _pickPack,
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Market', style: AppText.micro),
                                const SizedBox(height: 8),
                                MarketToggle(
                                  value: _market,
                                  accent: AppColors.indigo,
                                  onChanged: (v) =>
                                      setState(() => _market = v),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: AppSpace.md),
                    NoticeBanner(
                      level: NoticeLevel.info,
                      message: pack == null
                          ? 'The pack size is what turns a serial range into '
                              'a quantity, so it has to be set before '
                              'scanning.'
                          : '${pack.bottlesPerCase} bottles to a case is what '
                              'turns a serial range into a quantity. Next you '
                              'enter the prefix and scan the two ends.',
                    ),

                    if (packs == 0) ...[
                      const SizedBox(height: AppSpace.md),
                      Text(
                        'Loading pack sizes…',
                        textAlign: TextAlign.center,
                        style: AppText.small,
                      ),
                    ],
                  ],
                );
              }),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.gutter,
                AppSpace.lg,
                AppSpace.gutter,
                12,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ElevatedButton.icon(
                    onPressed: pack == null ? null : _continue,
                    icon: const Icon(Icons.qr_code_scanner_rounded, size: 21),
                    label: const Text('Continue to scan'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.indigo,
                      minimumSize: const Size.fromHeight(56),
                      textStyle: const TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (pack == null) ...[
                    const SizedBox(height: 9),
                    Text(
                      'Choose a pack size first',
                      textAlign: TextAlign.center,
                      style: AppText.small,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
