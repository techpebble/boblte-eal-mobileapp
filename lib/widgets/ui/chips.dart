import 'package:flutter/material.dart';

import 'package:eal_scanner/theme/app_tokens.dart';
import 'package:eal_scanner/utils/formatting.dart';

/// The dispatch lifecycle, in order. Every pill carries its position in the
/// chain ("Final · 2/5") so the sequence reads without learning the palette —
/// the old build signalled stage with background colour alone.
const List<String> kDispatchStages = [
  'draft',
  'final',
  'loaded',
  'dispatched',
  'delivered',
];

int dispatchStageIndex(String status) {
  final i = kDispatchStages.indexOf(status.toLowerCase().trim());
  return i < 0 ? 0 : i;
}

({Color bg, Color fg, Color dot}) dispatchStageColors(String status) {
  switch (status.toLowerCase().trim()) {
    case 'final':
      return (bg: AppColors.blueTint, fg: AppColors.blueDeep, dot: AppColors.blue);
    case 'loaded':
      return (
        bg: AppColors.indigoTint,
        fg: AppColors.indigoDeep,
        dot: AppColors.indigo,
      );
    case 'dispatched':
      return (
        bg: AppColors.amberTint,
        fg: AppColors.amberDeep,
        dot: AppColors.amber,
      );
    case 'delivered':
      return (
        bg: AppColors.greenTint,
        fg: AppColors.greenDeep,
        dot: AppColors.green,
      );
    case 'draft':
    default:
      return (bg: AppColors.sunken, fg: AppColors.ink700, dot: AppColors.ink500);
  }
}

/// A flat pill. The building block for status, market and count chips.
class Pill extends StatelessWidget {
  const Pill({
    super.key,
    required this.label,
    required this.background,
    required this.foreground,
    this.leading,
    this.fontSize = 12,
    this.dense = false,
  });

  final String label;
  final Color background;
  final Color foreground;
  final Widget? leading;
  final double fontSize;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 9 : 11,
        vertical: dense ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: AppRadius.brPill,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 6)],
          Text(
            label,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
              color: foreground,
            ),
          ),
        ],
      ),
    );
  }
}

/// Dispatch status with its stage number, e.g. `Loaded · 3/5`.
class DispatchStatusPill extends StatelessWidget {
  const DispatchStatusPill(this.status, {super.key, this.showStage = true});

  final String status;
  final bool showStage;

  @override
  Widget build(BuildContext context) {
    final colors = dispatchStageColors(status);
    final index = dispatchStageIndex(status);
    final delivered = status.toLowerCase().trim() == 'delivered';
    final name = status.isEmpty
        ? 'Draft'
        : status[0].toUpperCase() + status.substring(1).toLowerCase();

    return Pill(
      label: showStage
          ? '$name · ${index + 1}/${kDispatchStages.length}'
          : name,
      background: colors.bg,
      foreground: colors.fg,
      fontSize: 11.5,
      leading: delivered
          ? Icon(Icons.check_rounded, size: 12, color: colors.dot)
          : Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: colors.dot,
                borderRadius: AppRadius.brPill,
              ),
            ),
    );
  }
}

/// `local` / `export` straight from the backend enum.
class MarketChip extends StatelessWidget {
  const MarketChip(this.market, {super.key, this.dense = false});

  final String market;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final isExport = market.toLowerCase().trim() == 'export';
    return Pill(
      label: isExport ? 'Export' : 'Local',
      background: isExport ? AppColors.amberTint : AppColors.indigoTint,
      foreground: isExport ? AppColors.amberDeep : AppColors.indigoDeep,
      fontSize: dense ? 11.5 : 12,
      dense: dense,
    );
  }
}

/// A neutral metadata chip (item code, pack size).
class MetaChip extends StatelessWidget {
  const MetaChip(
    this.label, {
    super.key,
    this.background = AppColors.sunken,
    this.foreground = AppColors.ink700,
  });

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Pill(
      label: label,
      background: background,
      foreground: foreground,
      fontSize: 11.5,
      dense: true,
    );
  }
}

/// One selectable filter chip.
class FilterPill extends StatelessWidget {
  const FilterPill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.accent = AppColors.blue,
    this.leading,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color accent;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.brPill,
        child: Container(
          constraints: const BoxConstraints(minHeight: 36),
          padding: const EdgeInsets.symmetric(horizontal: 13),
          decoration: BoxDecoration(
            color: selected ? accent : AppColors.surface,
            borderRadius: AppRadius.brPill,
            border: Border.all(
              color: selected ? accent : AppColors.lineField,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (leading != null) ...[leading!, const SizedBox(width: 6)],
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : AppColors.ink700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The horizontally scrolling filter row that sits under every list header.
/// Date filtering used to hide behind a single calendar icon in the app bar.
class FilterPillRow extends StatelessWidget {
  const FilterPillRow({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.gutter),
        itemCount: children.length,
        separatorBuilder: (_, _) => const SizedBox(width: 7),
        itemBuilder: (_, i) => Align(child: children[i]),
      ),
    );
  }
}

/// Section heading used above grouped content.
class SectionHeading extends StatelessWidget {
  const SectionHeading(this.title, {super.key, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9, left: 2),
      child: Row(
        children: [
          Expanded(child: Text(title.toUpperCase(), style: AppText.section)),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// `local` / `export`, labelled as the backend names them.
///
/// Shared by the issuance screens: the market belongs to one set of
/// stickers, so it is chosen wherever that set is described.
class MarketToggle extends StatelessWidget {
  const MarketToggle({
    super.key,
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
