import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:eal_scanner/controllers/issuanceController.dart';
import 'package:eal_scanner/models/company.dart';
import 'package:eal_scanner/screens/issuance/sticker_details_screen.dart';
import 'package:eal_scanner/theme/app_tokens.dart';
import 'package:eal_scanner/utils/formatting.dart';
import 'package:eal_scanner/widgets/ui/chips.dart';
import 'package:eal_scanner/widgets/ui/feedback.dart';
import 'package:eal_scanner/widgets/ui/picker_sheet.dart';
import 'package:eal_scanner/widgets/ui/serial_text.dart';

/// Recording labels received from the excise office.
///
/// One issuance is one purchase: a date and a company, holding any number of
/// sticker sets, each with its own pack size, market, prefix and range. Only
/// what the whole purchase shares is settled here; the rest is named per set
/// on [StickerDetailsScreen]. Each set is saved as its own record, which is
/// how the server stores them.
class EALStickerScreen extends StatefulWidget {
  const EALStickerScreen({super.key});

  @override
  State<EALStickerScreen> createState() => _EALStickerScreenState();
}

class _EALStickerScreenState extends State<EALStickerScreen> {
  final Issuancecontroller _controller = Get.find<Issuancecontroller>();

  DateTime _date = DateTime.now();
  Company? _company;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _controller.currentEalIssuance.clear();
      if (_controller.companies.isEmpty) _controller.fetchCompanies();
      if (_controller.packs.isEmpty) _controller.fetchPackSizes();
    });
  }

  /// A sticker set has to belong to a company, so that comes first.
  bool get _ready => _company != null;

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

  Future<void> _addDetails() async {
    final company = _company;
    if (company == null) return;

    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => StickerDetailsScreen(company: company, date: _date),
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
      ),
      body: Obx(() {
        final added = _controller.currentEalIssuance;

        return ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.gutter,
            AppSpace.lg,
            AppSpace.gutter,
            AppSpace.xxl,
          ),
          children: [
            // What the whole issuance shares. Pack size and market belong to
            // each set of stickers, not to all of them at once.
            const SectionHeading('This issuance'),
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  PickerField(
                    label: 'Date issued',
                    value: formatDayMonthYear(_date),
                    icon: Icons.calendar_today_rounded,
                    onTap: _pickDate,
                  ),
                  PickerField(
                    label: 'Company',
                    value: _company?.name,
                    icon: Icons.apartment_rounded,
                    onTap: _pickCompany,
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpace.xl),
            SectionHeading(
              'Stickers added',
              trailing: Text(
                '${added.length}',
                style: AppText.mono(
                  size: 12,
                  weight: FontWeight.w600,
                  color: AppColors.ink500,
                ),
              ),
            ),

            if (added.isEmpty)
              AppCard(
                padding: const EdgeInsets.all(18),
                child: Text(
                  _ready
                      ? 'Nothing yet. Add the details of a set of stickers to '
                          'scan its range.'
                      : 'Choose a company first — a set of stickers has to '
                          'belong to one.',
                  style: AppText.small,
                ),
              )
            else
              AppCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (var i = 0; i < added.length; i++)
                      _AddedRow(
                        packName: added[i].packName,
                        market: added[i].market,
                        prefix: added[i].prefix,
                        from: int.tryParse(added[i].serialFrom) ?? 0,
                        to: int.tryParse(added[i].serialTo) ?? 0,
                        labels: added[i].issuedQuantity,
                        isLast: i == added.length - 1,
                      ),
                  ],
                ),
              ),

            const SizedBox(height: 10),
            _AddDetailsButton(
              enabled: _ready,
              accent: AppColors.indigo,
              onTap: _addDetails,
            ),

            if (!_ready) ...[
              const SizedBox(height: AppSpace.md),
              NoticeBanner(
                level: NoticeLevel.info,
                title: 'Pick the company first',
                message: 'Every set of stickers in this issuance is recorded '
                    'against it.',
              ),
            ],
          ],
        );
      }),
      bottomNavigationBar: Obx(() {
        final added = _controller.currentEalIssuance;
        final labels = added.fold<int>(0, (sum, r) => sum + r.issuedQuantity);

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
                        child: Text('Added so far', style: AppText.small),
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
                    child: Text(added.isEmpty ? 'Close' : 'Done'),
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

class _AddDetailsButton extends StatelessWidget {
  const _AddDetailsButton({
    required this.enabled,
    required this.accent,
    required this.onTap,
  });

  final bool enabled;
  final Color accent;
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
              Icons.add_rounded,
              size: 20,
              color: enabled ? accent : AppColors.ink400,
            ),
            const SizedBox(width: 9),
            Text(
              'Add details',
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

/// One set of stickers that has been recorded. The pack and market lead,
/// because they are what differs from one set to the next.
class _AddedRow extends StatelessWidget {
  const _AddedRow({
    required this.packName,
    required this.market,
    required this.prefix,
    required this.from,
    required this.to,
    required this.labels,
    required this.isLast,
  });

  final String packName;
  final String market;
  final String prefix;
  final int from;
  final int to;
  final int labels;
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(
              Icons.check_circle_outline_rounded,
              size: 19,
              color: AppColors.green,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$packName · ${titleCase(market)}',
                  style: AppText.label,
                ),
                const SizedBox(height: 3),
                SerialRangeText(
                  prefix: prefix,
                  from: from,
                  to: to,
                  size: 13,
                ),
                const SizedBox(height: 3),
                Text(formatLabels(labels), style: AppText.micro),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
