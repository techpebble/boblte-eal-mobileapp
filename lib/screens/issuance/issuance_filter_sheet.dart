import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:eal_scanner/controllers/issuanceController.dart';
import 'package:eal_scanner/theme/app_tokens.dart';
import 'package:eal_scanner/utils/formatting.dart';
import 'package:eal_scanner/widgets/ui/picker_sheet.dart';

/// Narrows the list by the three things it is grouped by.
///
/// Free-text search is gone: these are the only fields worth filtering on,
/// and picking from what exists beats guessing at a spelling. Choices are
/// held here until applied, so setting three of them does not shuffle the
/// list under the sheet three times.
Future<void> showIssuanceFilterSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const IssuanceFilterSheet(),
  );
}

class IssuanceFilterSheet extends StatefulWidget {
  const IssuanceFilterSheet({super.key});

  @override
  State<IssuanceFilterSheet> createState() => _IssuanceFilterSheetState();
}

class _IssuanceFilterSheetState extends State<IssuanceFilterSheet> {
  final Issuancecontroller _controller = Get.find<Issuancecontroller>();

  late String _company = _controller.filterCompany.value;
  late String _market = _controller.filterMarket.value;
  late String _pack = _controller.filterPack.value;

  bool get _any => _company.isEmpty && _market.isEmpty && _pack.isEmpty;

  /// How many records the list would show if these choices were applied.
  int get _matchCount {
    return _controller.ealIssuance.where((i) {
      if (_company.isNotEmpty && i.companyName != _company) return false;
      if (_market.isNotEmpty && i.market.toLowerCase() != _market) return false;
      if (_pack.isNotEmpty && i.packName != _pack) return false;
      return true;
    }).length;
  }

  Future<void> _pick({
    required String title,
    required List<String> options,
    required String selected,
    required ValueChanged<String> onChosen,
  }) async {
    final chosen = await showPickerSheet<String>(
      context: context,
      title: title,
      searchHint: title,
      accent: AppColors.indigo,
      selected: selected.isEmpty ? null : selected,
      emptyMessage: 'Nothing to choose from in these dates.',
      options: options
          .map((o) => PickerOption<String>(value: o, label: o))
          .toList(),
    );
    if (chosen != null && mounted) setState(() => onChosen(chosen));
  }

  void _apply() {
    _controller.filterCompany.value = _company;
    _controller.filterMarket.value = _market;
    _controller.filterPack.value = _pack;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final count = _matchCount;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.86,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.gutter),
              child: Row(
                children: [
                  const Expanded(child: Text('Filter', style: AppText.title)),
                  // Only worth offering while something is set.
                  if (!_any)
                    TextButton(
                      onPressed: () => setState(() {
                        _company = '';
                        _market = '';
                        _pack = '';
                      }),
                      child: const Text('Clear all'),
                    ),
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
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(
                  AppSpace.gutter,
                  AppSpace.md,
                  AppSpace.gutter,
                  0,
                ),
                children: [
                  const Text('COMPANY', style: AppText.section),
                  const SizedBox(height: 7),
                  _FilterField(
                    icon: Icons.apartment_rounded,
                    value: _company,
                    anyLabel: 'Any company',
                    onTap: () => _pick(
                      title: 'Company',
                      options: _controller.companyOptions,
                      selected: _company,
                      onChosen: (v) => _company = v,
                    ),
                    onClear: () => setState(() => _company = ''),
                  ),

                  const SizedBox(height: AppSpace.md),
                  const Text('MARKET', style: AppText.section),
                  const SizedBox(height: 7),
                  // Two values and an any: a row of choices beats a sheet on
                  // top of a sheet.
                  Row(
                    children: [
                      for (final option in const ['', 'local', 'export']) ...[
                        if (option != '') const SizedBox(width: 8),
                        Expanded(
                          child: _MarketChoice(
                            label: option.isEmpty ? 'Any' : titleCase(option),
                            selected: _market == option,
                            onTap: () => setState(() => _market = option),
                          ),
                        ),
                      ],
                    ],
                  ),

                  const SizedBox(height: AppSpace.md),
                  const Text('PACK SIZE', style: AppText.section),
                  const SizedBox(height: 7),
                  _FilterField(
                    icon: Icons.inventory_2_outlined,
                    value: _pack,
                    anyLabel: 'Any pack size',
                    onTap: () => _pick(
                      title: 'Pack size',
                      options: _controller.packOptions,
                      selected: _pack,
                      onChosen: (v) => _pack = v,
                    ),
                    onClear: () => setState(() => _pack = ''),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.gutter,
                AppSpace.lg,
                AppSpace.gutter,
                12,
              ),
              // Says what it will leave on screen, so three choices can be
              // set before anything moves.
              child: ElevatedButton(
                onPressed: _apply,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.indigo,
                  minimumSize: const Size.fromHeight(56),
                  textStyle: const TextStyle(
                    fontSize: 16.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                child: Text(
                  count == 0
                      ? 'Nothing matches these'
                      : 'Show $count ${count == 1 ? 'record' : 'records'}',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterField extends StatelessWidget {
  const _FilterField({
    required this.icon,
    required this.value,
    required this.anyLabel,
    required this.onTap,
    required this.onClear,
  });

  final IconData icon;
  final String value;
  final String anyLabel;
  final VoidCallback onTap;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final set = value.isNotEmpty;

    return Material(
      color: set ? AppColors.surface : AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.control),
        side: BorderSide(
          color: set ? AppColors.indigo : AppColors.lineField,
          width: 1.5,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.control),
        // 56, as the design has it. With only padding round a Row this was
        // about 38 while nothing was picked — shorter than the market
        // choices beside it — and jumped to about 66 once something was,
        // because the clear button is a full-sized IconButton. A control
        // that changes height when you use it is the thing you notice.
        child: Container(
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.fromLTRB(14, 7, 10, 7),
          child: Row(
            children: [
              Icon(
                icon,
                size: 19,
                color: set ? AppColors.indigo : AppColors.ink500,
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  set ? value : anyLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: set ? FontWeight.w600 : FontWeight.w400,
                    color: set ? AppColors.ink900 : AppColors.ink500,
                  ),
                ),
              ),
              if (set)
                IconButton(
                  onPressed: onClear,
                  icon: const Icon(Icons.close_rounded, size: 16),
                  tooltip: 'Clear',
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(
                    width: 34,
                    height: 34,
                  ),
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.indigoTint,
                    foregroundColor: AppColors.indigoDeep,
                  ),
                )
              else
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: AppColors.ink400,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MarketChoice extends StatelessWidget {
  const _MarketChoice({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
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
            color: selected ? AppColors.indigoTint : AppColors.surface,
            borderRadius: BorderRadius.circular(11),
            border: Border.all(
              color: selected ? AppColors.indigo : AppColors.lineField,
              width: 1.5,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              color: selected ? AppColors.indigoDeep : AppColors.ink700,
            ),
          ),
        ),
      ),
    );
  }
}
