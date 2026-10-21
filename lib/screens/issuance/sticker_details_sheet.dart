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

/// Asks what one set of stickers is, on the way to scanning it.
///
/// One record is one set: a date, a company, a pack size and a market, then
/// a serial range — which is how the server stores it. This sheet asks for
/// those four and goes straight to the scanner, so there is no separate
/// entry screen in between. Returns true once a range has been recorded, so
/// the list knows to refresh; the list stays visible behind it.
Future<bool?> showStickerDetailsSheet({
  required BuildContext context,
  Company? company,
  DateTime? date,
  PackSize? pack,
  String? market,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => StickerDetailsSheet(
      company: company,
      date: date,
      pack: pack,
      market: market,
    ),
  );
}

/// Opens the sheet for the next set, carrying the last entry's company,
/// pack and market so a purchase of several sets is not typed out again.
Future<bool?> showStickerDetailsSheetForNext(BuildContext context) {
  final last = Get.find<Issuancecontroller>().lastEntry;
  return showStickerDetailsSheet(
    context: context,
    company: last?.company,
    pack: last?.pack,
    market: last?.market,
  );
}

class StickerDetailsSheet extends StatefulWidget {
  const StickerDetailsSheet({
    super.key,
    this.company,
    this.date,
    this.pack,
    this.market,
  });

  /// Carried over from the last entry, where there was one. The date
  /// defaults to today instead, since that is what it almost always is.
  final Company? company;
  final DateTime? date;
  final PackSize? pack;
  final String? market;

  @override
  State<StickerDetailsSheet> createState() => _StickerDetailsSheetState();
}

class _StickerDetailsSheetState extends State<StickerDetailsSheet> {
  final Issuancecontroller _controller = Get.find<Issuancecontroller>();

  late DateTime _date = widget.date ?? DateTime.now();
  late Company? _company = widget.company;
  late PackSize? _pack = widget.pack;
  late String _market = widget.market ?? 'local';

  /// True while nothing was carried in, so the note can say where the
  /// values came from without claiming a last entry that never happened.
  late final bool _carried = widget.company != null || widget.pack != null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_controller.packs.isEmpty) _controller.fetchPackSizes();
      if (_controller.companies.isEmpty) _controller.fetchCompanies();
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

  Future<void> _pickCompany() async {
    final chosen = await showPickerSheet<Company>(
      context: context,
      title: 'Choose company',
      searchHint: 'Company name',
      accent: AppColors.indigo,
      selected: _company,
      emptyMessage: 'No companies have been set up yet.',
      options: _controller.companies
          .map((c) => PickerOption<Company>(value: c, label: c.name))
          .toList(),
    );
    if (chosen != null && mounted) setState(() => _company = chosen);
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

  bool get _ready => _company != null && _pack != null;

  /// Straight on to the prefix and the two ends. The sheet stays open under
  /// the scanner, so backing out of the scan keeps these four values.
  Future<void> _continue() async {
    final company = _company;
    final pack = _pack;
    if (company == null || pack == null) return;

    final recorded = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ScanFlowScreen(
          target: ScanTarget(
            module: AppModule.issuance,
            title: 'Record issuance',
            contextLine: '${pack.name} · ${titleCase(_market)} · '
                '${company.name}',
            bottlesPerCase: pack.bottlesPerCase,
            unit: ScanUnit.labels,
            // Some issuance labels carry the whole range in one code.
            allowRangeQr: true,
            submit: (draft) => _controller.addEALIssuance(
              company: company,
              dateIssued: _date,
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

  /// Where the four values came from, said once, so none of them is a
  /// surprise after a range is recorded against them.
  String get _provenance {
    if (_carried) {
      return "Today's date, with the rest carried over from your last entry. "
          'Change anything that differs.';
    }
    if (_pack == null) {
      return 'The pack size is what turns a serial range into a quantity, so '
          'it has to be set before scanning.';
    }
    return "Today's date, unless you change it. "
        '${_pack!.bottlesPerCase} bottles to a case turns the range you scan '
        'into a quantity.';
  }

  @override
  Widget build(BuildContext context) {
    final pack = _pack;
    final today = DateTime.now();
    final isToday = _date.year == today.year &&
        _date.month == today.month &&
        _date.day == today.day;

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
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Sticker details', style: AppText.title),
                        SizedBox(height: 2),
                        Text(
                          'What these stickers are, before scanning them',
                          style: AppText.small,
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
                // Read so the sheet rebuilds when either list arrives.
                final loading =
                    _controller.packs.isEmpty || _controller.companies.isEmpty;

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
                            label: 'Date issued',
                            value: isToday
                                ? '${formatDayMonthYear(_date)} · today'
                                : formatDayMonthYear(_date),
                            icon: Icons.calendar_today_rounded,
                            onTap: _pickDate,
                          ),
                          PickerField(
                            label: 'Company',
                            value: _company?.name,
                            icon: Icons.apartment_rounded,
                            onTap: _pickCompany,
                          ),
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

                    const SizedBox(height: 9),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            _carried
                                ? Icons.refresh_rounded
                                : Icons.info_outline_rounded,
                            size: 14,
                            color: AppColors.ink500,
                          ),
                          const SizedBox(width: 7),
                          Expanded(
                            child: Text(_provenance, style: AppText.micro),
                          ),
                        ],
                      ),
                    ),

                    if (loading) ...[
                      const SizedBox(height: AppSpace.md),
                      const ThinLoadingBar(),
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
                    onPressed: _ready ? _continue : null,
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
                  if (!_ready) ...[
                    const SizedBox(height: 9),
                    Text(
                      _company == null
                          ? 'Choose a company first'
                          : 'Choose a pack size first',
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
