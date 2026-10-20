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
import 'package:eal_scanner/widgets/ui/serial_text.dart';

/// Recording labels received from the excise office.
///
/// The old screen blocked with a dialog if company and market were not set
/// before the scan button; here the form is ordered so that cannot happen and
/// the action states what it is waiting for.
class EALStickerScreen extends StatefulWidget {
  const EALStickerScreen({super.key});

  @override
  State<EALStickerScreen> createState() => _EALStickerScreenState();
}

class _EALStickerScreenState extends State<EALStickerScreen> {
  final Issuancecontroller _controller = Get.find<Issuancecontroller>();

  DateTime _date = DateTime.now();
  Company? _company;
  PackSize? _pack;
  String _market = 'local';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _controller.currentEalIssuance.clear();
      if (_controller.companies.isEmpty) _controller.fetchCompanies();
      if (_controller.packs.isEmpty) _controller.fetchPackSizes();
    });
  }

  bool get _ready => _company != null && _pack != null;

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

  Future<void> _scanRange() async {
    final company = _company;
    final pack = _pack;
    if (company == null || pack == null) return;

    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ScanFlowScreen(
          target: ScanTarget(
            module: AppModule.issuance,
            title: 'Record issuance',
            contextLine:
                '${pack.name} · ${titleCase(_market)} · ${company.name}',
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
        title: const Text('New issuance', style: AppText.appBarTitle),
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
        final recorded = _controller.currentEalIssuance;

        return ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.gutter,
            AppSpace.lg,
            AppSpace.gutter,
            AppSpace.xxl,
          ),
          children: [
            const SectionHeading('What is being issued'),
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  PickerField(
                    label: 'Company',
                    value: _company?.name,
                    icon: Icons.apartment_rounded,
                    onTap: _pickCompany,
                  ),
                  PickerField(
                    label: 'Pack size',
                    value: _pack == null
                        ? null
                        : '${_pack!.name} · ${_pack!.bottlesPerCase} per case',
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
                        _MarketToggle(
                          value: _market,
                          accent: AppColors.indigo,
                          onChanged: (v) => setState(() => _market = v),
                        ),
                      ],
                    ),
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
                  _ready
                      ? 'Nothing yet. Scan a range to record it against the '
                          'pack above.'
                      : 'Choose a company and pack size first — a range has to '
                          'belong to one.',
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
                        labels: recorded[i].issuedQuantity,
                        bottlesPerCase: _pack?.bottlesPerCase ?? 0,
                        isLast: i == recorded.length - 1,
                      ),
                  ],
                ),
              ),

            const SizedBox(height: 10),
            _ScanButton(
              enabled: _ready,
              accent: AppColors.indigo,
              label: recorded.isEmpty ? 'Scan a range' : 'Scan another range',
              onTap: _scanRange,
            ),

            if (!_ready) ...[
              const SizedBox(height: AppSpace.md),
              NoticeBanner(
                level: NoticeLevel.info,
                title: 'Pick the company and pack first',
                message: 'The pack size sets how many bottles are in a case, '
                    'which is what turns a serial range into a quantity.',
              ),
            ],
          ],
        );
      }),
      bottomNavigationBar: Obx(() {
        final recorded = _controller.currentEalIssuance;
        final labels = recorded.fold<int>(
          0,
          (sum, r) => sum + r.issuedQuantity,
        );

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
                      Text(
                        formatQty(labels),
                        style: AppText.figure(size: 19),
                      ),
                      const SizedBox(width: 5),
                      const Padding(
                        padding: EdgeInsets.only(bottom: 2),
                        child: Text('labels', style: AppText.micro),
                      ),
                    ],
                  ),
                  const SizedBox(height: 11),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.indigo,
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

/// `local` / `export`, labelled as the backend names them.
class _MarketToggle extends StatelessWidget {
  const _MarketToggle({
    required this.value,
    required this.onChanged,
    required this.accent,
  });

  final String value;
  final ValueChanged<String> onChanged;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final option in const ['local', 'export']) ...[
          if (option != 'local') const SizedBox(width: 8),
          Expanded(
            child: _MarketOption(
              label: titleCase(option),
              selected: value == option,
              accent: accent,
              onTap: () => onChanged(option),
            ),
          ),
        ],
      ],
    );
  }
}

class _MarketOption extends StatelessWidget {
  const _MarketOption({
    required this.label,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      inMutuallyExclusiveGroup: true,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(11),
        child: Container(
          height: 46,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? accent.withValues(alpha: 0.1) : AppColors.surface,
            borderRadius: BorderRadius.circular(11),
            border: Border.all(
              color: selected ? accent : AppColors.lineField,
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_unchecked_rounded,
                size: 17,
                color: selected ? accent : AppColors.ink400,
              ),
              const SizedBox(width: 7),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: selected ? accent : AppColors.ink700,
                ),
              ),
            ],
          ),
        ),
      ),
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
            strokeAlign: BorderSide.strokeAlignInside,
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
    required this.bottlesPerCase,
    required this.isLast,
  });

  final String prefix;
  final int from;
  final int to;
  final int labels;
  final int bottlesPerCase;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final cases = bottlesPerCase > 0 ? labels ~/ bottlesPerCase : null;

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
                  cases == null
                      ? formatLabels(labels)
                      : '${formatLabels(labels)} · ${formatCases(cases)}',
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
