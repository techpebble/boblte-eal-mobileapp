import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:eal_scanner/controllers/dispatchController.dart';
import 'package:eal_scanner/widgets/ui/chips.dart';
import 'package:eal_scanner/theme/app_tokens.dart';
import 'package:eal_scanner/utils/formatting.dart';
import 'package:eal_scanner/widgets/ui/picker_sheet.dart';

/// Narrows the dispatch list.
///
/// Company and market are what it is grouped by; the depot is where the
/// note is going, which is dispatch's equivalent of a pack size or an item;
/// and the stage is the one thing the other two lists have no counterpart
/// for. Search stays in the header, because a vehicle number is not
/// something to pick from a list. Choices are held here until applied, so
/// setting several does not shuffle the list under the sheet each time.
Future<void> showDispatchFilterSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const DispatchFilterSheet(),
  );
}

class DispatchFilterSheet extends StatefulWidget {
  const DispatchFilterSheet({super.key});

  @override
  State<DispatchFilterSheet> createState() => _DispatchFilterSheetState();
}

class _DispatchFilterSheetState extends State<DispatchFilterSheet> {
  final DispatchController _controller = Get.find<DispatchController>();

  late String _company = _controller.filterCompany.value;
  late String _market = _controller.filterMarket.value;
  late String _depot = _controller.filterDepot.value;
  late String _stage = _controller.statusFilter.value;

  bool get _any =>
      _company.isEmpty && _market.isEmpty && _depot.isEmpty && _stage.isEmpty;

  /// How many notes the list would show if these choices were applied. The
  /// search in the header still applies on top, so this counts with it.
  int get _matchCount {
    final query = _controller.searchQuery.value.trim().toLowerCase();

    return _controller.dispatches.where((d) {
      if (_company.isNotEmpty && d.companyName != _company) return false;
      if (_market.isNotEmpty && d.market.toLowerCase() != _market) return false;
      if (_depot.isNotEmpty && d.depotName != _depot) return false;
      if (_stage == 'short' && !_controller.isShortOfLabels(d)) return false;
      if (_stage.isNotEmpty &&
          _stage != 'short' &&
          d.status.toLowerCase() != _stage) {
        return false;
      }
      if (query.isEmpty) return true;

      return d.depotName.toLowerCase().contains(query) ||
          d.companyName.toLowerCase().contains(query) ||
          d.vehicleNumber.toLowerCase().contains(query) ||
          d.driverName.toLowerCase().contains(query);
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
      accent: AppColors.amber,
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
    _controller.filterDepot.value = _depot;
    _controller.statusFilter.value = _stage;
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
                        _depot = '';
                        _stage = '';
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
                  const Text('DEPOT', style: AppText.section),
                  const SizedBox(height: 7),
                  _FilterField(
                    icon: Icons.warehouse_outlined,
                    value: _depot,
                    anyLabel: 'Any depot',
                    onTap: () => _pick(
                      title: 'Depot',
                      options: _controller.depotOptions,
                      selected: _depot,
                      onChosen: (v) => _depot = v,
                    ),
                    onClear: () => setState(() => _depot = ''),
                  ),

                  const SizedBox(height: AppSpace.md),
                  const Text('STAGE', style: AppText.section),
                  const SizedBox(height: 7),
                  // Five stages, an any, and the one that is not a stage at
                  // all: too many for a row, so they wrap. Each carries its
                  // place in the chain, as the pill on a card does.
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _StageChoice(
                        label: 'Any',
                        selected: _stage.isEmpty,
                        onTap: () => setState(() => _stage = ''),
                      ),
                      _StageChoice(
                        label: 'Short of labels',
                        selected: _stage == 'short',
                        dot: AppColors.caution,
                        onTap: () => setState(() => _stage = 'short'),
                      ),
                      for (final stage in kDispatchStages)
                        _StageChoice(
                          label: titleCase(stage),
                          selected: _stage == stage,
                          dot: dispatchStageColors(stage).dot,
                          onTap: () => setState(() => _stage = stage),
                        ),
                    ],
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
                  backgroundColor: AppColors.amber,
                  minimumSize: const Size.fromHeight(56),
                  textStyle: const TextStyle(
                    fontSize: 16.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                child: Text(
                  count == 0
                      ? 'Nothing matches these'
                      : 'Show $count ${count == 1 ? 'note' : 'notes'}',
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
          color: set ? AppColors.amber : AppColors.lineField,
          width: 1.5,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.control),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 9, 10, 9),
          child: Row(
            children: [
              Icon(
                icon,
                size: 19,
                color: set ? AppColors.amber : AppColors.ink500,
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
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.amberTint,
                    foregroundColor: AppColors.amberDeep,
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
            color: selected ? AppColors.amberTint : AppColors.surface,
            borderRadius: BorderRadius.circular(11),
            border: Border.all(
              color: selected ? AppColors.amber : AppColors.lineField,
              width: 1.5,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              color: selected ? AppColors.amberDeep : AppColors.ink700,
            ),
          ),
        ),
      ),
    );
  }
}

/// One stage choice, with the dot its pill carries on a card so the two
/// read as the same thing.
class _StageChoice extends StatelessWidget {
  const _StageChoice({
    required this.label,
    required this.selected,
    required this.onTap,
    this.dot,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? dot;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 13),
        decoration: BoxDecoration(
          color: selected ? AppColors.amberTint : AppColors.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? AppColors.amber : AppColors.lineField,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (dot != null) ...[
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
              ),
              const SizedBox(width: 7),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color: selected ? AppColors.amberDeep : AppColors.ink700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
