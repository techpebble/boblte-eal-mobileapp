import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:eal_scanner/controllers/issuanceController.dart';
import 'package:eal_scanner/models/issuance.dart';
import 'package:eal_scanner/models/issuance_grouping.dart';
import 'package:eal_scanner/screens/issuance/issuance_filter_sheet.dart';
import 'package:eal_scanner/screens/issuance/issuanceDetailScreen.dart';
import 'package:eal_scanner/screens/issuance/sticker_details_sheet.dart';
import 'package:eal_scanner/theme/app_tokens.dart';
import 'package:eal_scanner/utils/formatting.dart';
import 'package:eal_scanner/widgets/ui/chips.dart';
import 'package:eal_scanner/widgets/ui/date_range_sheet.dart';
import 'package:eal_scanner/widgets/ui/feedback.dart';
import 'package:eal_scanner/widgets/ui/serial_text.dart';

/// Labels received from the excise office.
///
/// Grouped by company and market, then pack size, because that is how an
/// excise return asks for them — so the totals are on screen rather than
/// added up by hand. Free-text search is gone: the three things it is
/// grouped by are the three things worth filtering on, picked from what is
/// there. The date control takes a span or a single day.
class IssuanceListScreen extends StatefulWidget {
  const IssuanceListScreen({super.key});

  @override
  State<IssuanceListScreen> createState() => _IssuanceListScreenState();
}

class _IssuanceListScreenState extends State<IssuanceListScreen> {
  final Issuancecontroller _controller = Get.find<Issuancecontroller>();
  bool _requested = false;

  /// Which pack sizes are open. Collapsed is the default, and anything that
  /// fetches a different set of records closes them again — an open pack
  /// left over from the last date would be one the operator never opened.
  final Set<String> _open = {};

  String _key(IssuanceGroup g, PackGroup p) =>
      '${g.companyName}|${g.market}|${p.packName}';

  void _toggle(String key) => setState(() {
    if (!_open.remove(key)) _open.add(key);
  });

  /// Runs a change that refetches, and folds everything away with it.
  void _reload(VoidCallback change) {
    setState(_open.clear);
    change();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_requested && _controller.ealIssuance.isEmpty) {
        _requested = true;
        _controller.fetchEALIssuance();
      }
    });
  }

  Future<void> _addStickers() => showStickerDetailsSheetForNext(context);

  Future<void> _pickDates() async {
    final span = await showDateRangeSheet(
      context: context,
      from: _controller.fromDate.value,
      to: _controller.toDate.value,
      lastAllowed: DateTime.now(),
      accent: AppColors.indigo,
    );
    if (span != null) _controller.setSpan(span.from, span.to);
  }

  String get _spanLabel {
    final from = _controller.fromDate.value;
    final to = _controller.toDate.value;
    if (from == to) return formatDayMonth(from);
    return '${formatDayMonth(from)} – ${formatDayMonth(to)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: Column(
        children: [
          // Everything you set is white and together at the top; everything
          // you read sits on the canvas below it.
          Container(
            decoration: const BoxDecoration(
              color: AppColors.surface,
              boxShadow: [
                BoxShadow(
                  color: Color(0x140B1220),
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
              border: Border(
                bottom: BorderSide(color: AppColors.line, width: 1),
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  Obx(() {
                    final count = _controller.ealIssuance.length;
                    return _TitleRow(
                      countLabel: _controller.isLoading.value && count == 0
                          ? null
                          : '$count ${count == 1 ? 'record' : 'records'}',
                      filterCount: _controller.activeFilterCount,
                      onFilter: () async {
                        await showIssuanceFilterSheet(context);
                        if (mounted) setState(_open.clear);
                      },
                    );
                  }),

                  Obx(
                    () => _DateRow(
                      isToday: _controller.isPreset(1),
                      isYesterday: _controller.isYesterday,
                      isWeek: _controller.isPreset(7),
                      spanLabel: _spanLabel,
                      spanActive:
                          !_controller.isPreset(1) &&
                          !_controller.isYesterday &&
                          !_controller.isPreset(7),
                      onToday: () => _reload(() => _controller.setLastDays(1)),
                      onYesterday: () => _reload(_controller.setYesterday),
                      onWeek: () => _reload(() => _controller.setLastDays(7)),
                      onPickDates: _pickDates,
                    ),
                  ),

                  // What the dates and filters come to, kept with the
                  // controls that decide it.
                  Obx(() {
                    final loading =
                        _controller.isLoading.value &&
                        _controller.ealIssuance.isEmpty;

                    return Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpace.gutter,
                        12,
                        AppSpace.gutter,
                        0,
                      ),
                      child: Container(
                        padding: const EdgeInsets.only(top: 12, bottom: 13),
                        decoration: const BoxDecoration(
                          border: Border(
                            top: BorderSide(
                              color: AppColors.lineSoft,
                              width: 1,
                            ),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              child: _SummaryFigure(
                                value: loading
                                    ? null
                                    : formatQty(_controller.totalIssued),
                                label: 'labels issued',
                              ),
                            ),
                            _SummaryFigure(
                              value: loading
                                  ? null
                                  : formatQty(_controller.totalUnused),
                              label: 'unused',
                              color: AppColors.caution,
                              alignEnd: true,
                            ),
                          ],
                        ),
                      ),
                    );
                  }),

                  Obx(() {
                    final showing =
                        _controller.isLoading.value &&
                        _controller.ealIssuance.isNotEmpty;
                    return showing
                        ? const ThinLoadingBar()
                        : const SizedBox.shrink();
                  }),
                ],
              ),
            ),
          ),

          Expanded(child: Obx(_buildBody)),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addStickers,
        backgroundColor: AppColors.indigo,
        foregroundColor: Colors.white,
        elevation: 2,
        shape: const CircleBorder(),
        tooltip: 'New issuance',
        child: const Icon(Icons.add_rounded, size: 26),
      ),
    );
  }

  Widget _buildBody() {
    final error = _controller.errorMessage.value;

    if (_controller.isLoading.value && _controller.ealIssuance.isEmpty) {
      return const _GroupedSkeleton();
    }

    if (error.isNotEmpty && _controller.ealIssuance.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(AppSpace.gutter),
        child: NoticeBanner(
          level: NoticeLevel.error,
          title: 'Could not load issuance',
          message: error,
          trailing: TextButton(
            onPressed: _controller.fetchEALIssuance,
            child: const Text('Retry'),
          ),
        ),
      );
    }

    final groups = _controller.groupedIssuance;

    if (groups.isEmpty) {
      // Filters hide behind one button, so an empty list has to say which of
      // the two reasons it is empty for.
      if (_controller.hasFilters) {
        return EmptyState(
          icon: Icons.filter_alt_off_rounded,
          title: 'Nothing matches the filters',
          message:
              'There are records in these dates, but none of them match '
              'what the filter is set to.',
          accent: AppColors.indigo,
          tint: AppColors.indigoTint,
          primaryLabel: 'Clear the filters',
          onPrimary: _controller.clearFilters,
          secondaryLabel: 'Change the filters',
          onSecondary: () => showIssuanceFilterSheet(context),
        );
      }

      return EmptyState(
        icon: Icons.event_busy_rounded,
        title: _controller.isSingleDay
            ? 'No labels issued on '
                  '${formatDayMonthYear(_controller.fromDate.value)}'
            : 'No labels issued in these dates',
        message:
            'No filters are on, so this is every record for the dates. '
            'Widen them, or record the issuance you have in hand.',
        accent: AppColors.indigo,
        tint: AppColors.indigoTint,
        primaryLabel: 'Show the last 7 days',
        onPrimary: () => _reload(() => _controller.setLastDays(7)),
        secondaryLabel: 'Record a new issuance',
        onSecondary: _addStickers,
      );
    }

    return RefreshIndicator(
      color: AppColors.indigo,
      onRefresh: () async => _controller.fetchEALIssuance(),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(
          AppSpace.gutter,
          AppSpace.lg,
          AppSpace.gutter,
          96,
        ),
        itemCount: groups.length,
        itemBuilder: (_, i) => _GroupSection(
          group: groups[i],
          isOpen: (pack) => _open.contains(_key(groups[i], pack)),
          onToggle: (pack) => _toggle(_key(groups[i], pack)),
        ),
      ),
    );
  }
}

/// Title, record count, and the one button that stands for all three
/// filters. Lit with a count when any are on, so a filtered list never
/// passes for the whole list.
class _TitleRow extends StatelessWidget {
  const _TitleRow({
    required this.countLabel,
    required this.filterCount,
    required this.onFilter,
  });

  final String? countLabel;
  final int filterCount;
  final VoidCallback onFilter;

  @override
  Widget build(BuildContext context) {
    final on = filterCount > 0;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.gutter,
            11,
            AppSpace.gutter,
            12,
          ),
          child: Row(
            children: [
              // The title and count share one Expanded, so all the free
              // space lands here and the button stays hard against the
              // right edge. Giving them a flex each alongside a Spacer
              // split the space three ways instead: the title was cut
              // short and its unused slot pushed the button inwards.
              Expanded(
                child: Row(
                  children: [
                    const Flexible(
                      child: Text(
                        'EAL issuance',
                        style: AppText.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 9),
                    if (countLabel != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          countLabel!,
                          style: AppText.mono(
                            size: 13,
                            color: AppColors.ink500,
                          ),
                          maxLines: 1,
                        ),
                      )
                    else
                      const Padding(
                        padding: EdgeInsets.only(top: 5),
                        child: SkeletonBox(width: 58, height: 11),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Semantics(
                button: true,
                label: on
                    ? 'Filter — $filterCount '
                          '${filterCount == 1 ? 'filter' : 'filters'} on'
                    : 'Filter',
                child: InkWell(
                  onTap: onFilter,
                  borderRadius: BorderRadius.circular(AppRadius.control),
                  child: Container(
                    height: 40,
                    padding: EdgeInsets.fromLTRB(13, 0, on ? 11 : 13, 0),
                    decoration: BoxDecoration(
                      color: on ? AppColors.indigo : AppColors.surface,
                      borderRadius: BorderRadius.circular(AppRadius.control),
                      border: Border.all(
                        color: on ? AppColors.indigo : AppColors.lineField,
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.filter_list_rounded,
                          size: 19,
                          color: on ? Colors.white : AppColors.ink700,
                        ),
                        if (on) ...[
                          const SizedBox(width: 6),
                          Text(
                            '$filterCount',
                            style: AppText.mono(
                              size: 13.5,
                              weight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The named days first, because they are what gets tapped; the span last,
/// for any other stretch — or any single day.
class _DateRow extends StatelessWidget {
  const _DateRow({
    required this.isToday,
    required this.isYesterday,
    required this.isWeek,
    required this.spanLabel,
    required this.spanActive,
    required this.onToday,
    required this.onYesterday,
    required this.onWeek,
    required this.onPickDates,
  });

  final bool isToday;
  final bool isYesterday;
  final bool isWeek;
  final String spanLabel;
  final bool spanActive;
  final VoidCallback onToday;
  final VoidCallback onYesterday;
  final VoidCallback onWeek;
  final VoidCallback onPickDates;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(
          AppSpace.gutter,
          10,
          AppSpace.gutter,
          0,
        ),
        children: [
          FilterPill(
            label: 'Today',
            selected: isToday,
            accent: AppColors.indigo,
            onTap: onToday,
          ),
          const SizedBox(width: 7),
          FilterPill(
            label: 'Yesterday',
            selected: isYesterday,
            accent: AppColors.indigo,
            onTap: onYesterday,
          ),
          const SizedBox(width: 7),
          FilterPill(
            label: '7 days',
            selected: isWeek,
            accent: AppColors.indigo,
            onTap: onWeek,
          ),
          const SizedBox(width: 7),
          FilterPill(
            label: spanLabel,
            selected: spanActive,
            accent: AppColors.indigo,
            leading: Icon(
              Icons.calendar_today_rounded,
              size: 15,
              color: spanActive ? Colors.white : AppColors.ink700,
            ),
            onTap: onPickDates,
          ),
        ],
      ),
    );
  }
}

class _SummaryFigure extends StatelessWidget {
  const _SummaryFigure({
    required this.value,
    required this.label,
    this.color,
    this.alignEnd = false,
  });

  /// Null while the figure is still loading.
  final String? value;
  final String label;
  final Color? color;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        if (value == null)
          const Padding(
            padding: EdgeInsets.only(bottom: 4),
            child: SkeletonBox(width: 82, height: 17),
          )
        else
          Text(
            value!,
            style: color == null
                ? AppText.figure(size: 17)
                : AppText.figure(size: 17, color: color!),
          ),
        Text(label, style: AppText.micro),
      ],
    );
  }
}

/// A company and market reads as a heading on the canvas, not as another
/// card. Its pack sizes are the cards, so the gaps between them carry the
/// separation that two near-identical tints could not.
class _GroupSection extends StatelessWidget {
  const _GroupSection({
    required this.group,
    required this.isOpen,
    required this.onToggle,
  });

  final IssuanceGroup group;
  final bool Function(PackGroup) isOpen;
  final void Function(PackGroup) onToggle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 0, 2, 2),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  group.companyName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.02,
                    color: AppColors.ink900,
                  ),
                ),
              ),
              const SizedBox(width: 9),
              MarketChip(group.market, dense: true),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 0, 2, 10),
          child: _IssuedLeft(issued: group.issued, unused: group.unused),
        ),
        for (final pack in group.packs)
          _PackCard(
            pack: pack,
            prefix: group.companyName,
            open: isOpen(pack),
            onToggle: () => onToggle(pack),
          ),
        const SizedBox(height: 8),
      ],
    );
  }
}

/// One pack size, with its ranges folded away until asked for. The figures
/// and the bar stay on the card, so the drawdown reads without opening it.
class _PackCard extends StatelessWidget {
  const _PackCard({
    required this.pack,
    required this.prefix,
    required this.open,
    required this.onToggle,
  });

  final PackGroup pack;

  /// Only for the semantics label, so the control says which pack it opens.
  final String prefix;

  final bool open;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final issued = pack.issued;
    final left = pack.unused;
    final used = issued - left;
    final done = left <= 0 && issued > 0;
    final count = pack.rows.length;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.brTile,
        border: Border.all(color: AppColors.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Semantics(
            button: true,
            expanded: open,
            label:
                '${pack.packName}, $count '
                '${count == 1 ? 'range' : 'ranges'}',
            child: InkWell(
              onTap: onToggle,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 13, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            pack.packName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.ink900,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '$count ${count == 1 ? 'range' : 'ranges'}',
                          style: AppText.micro,
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          open
                              ? Icons.keyboard_arrow_up_rounded
                              : Icons.keyboard_arrow_down_rounded,
                          size: 20,
                          color: AppColors.ink500,
                        ),
                      ],
                    ),

                    // The figure you came for, before the small print.
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          formatQty(issued),
                          style: AppText.mono(
                            size: 16,
                            weight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text('issued', style: AppText.micro),
                        const Spacer(),
                        Text(
                          formatQty(left),
                          style: AppText.mono(
                            size: 13,
                            weight: FontWeight.w600,
                            color: done
                                ? AppColors.greenDeep
                                : AppColors.cautionDeep,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text('left', style: AppText.micro),
                      ],
                    ),
                    const SizedBox(height: 8),
                    LinkedProgressBar(
                      linked: used,
                      required_: issued == 0 ? 1 : issued,
                      height: 6,
                      accent: done ? AppColors.green : AppColors.caution,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Opened ranges live inside the pack's own card, so they can only
          // belong to it.
          if (open)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 4),
              child: Column(
                children: [
                  for (final row in pack.rows) _RangeRow(issuance: row),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// "384,900 issued · 135,300 left", under a company and market heading.
class _IssuedLeft extends StatelessWidget {
  const _IssuedLeft({required this.issued, required this.unused});

  final int issued;
  final int unused;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        style: const TextStyle(fontSize: 11.5, color: AppColors.ink500),
        children: [
          TextSpan(
            text: formatQty(issued),
            style: AppText.mono(
              size: 11.5,
              weight: FontWeight.w600,
              color: AppColors.ink700,
            ),
          ),
          const TextSpan(text: ' issued · '),
          TextSpan(
            text: formatQty(unused),
            style: AppText.mono(
              size: 11.5,
              weight: FontWeight.w600,
              color: AppColors.ink700,
            ),
          ),
          const TextSpan(text: ' left'),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

/// One issuance record inside an opened pack: its range, and whether any of
/// it is left.
class _RangeRow extends StatelessWidget {
  const _RangeRow({required this.issuance});

  final IssuanceModel issuance;

  @override
  Widget build(BuildContext context) {
    final issued = issuance.issuedQuantity;
    final left = issuance.balanceQuantity;
    final fully = left <= 0 && issued > 0;

    return InkWell(
      onTap: () => Get.to(() => EALIssuanceDetailScreen(issuance: issuance)),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.lineSoft, width: 1)),
        ),
        child: Row(
          children: [
            Expanded(
              child: SerialRangeText(
                prefix: issuance.prefix,
                from: int.tryParse(issuance.serialFrom) ?? 0,
                to: int.tryParse(issuance.serialTo) ?? 0,
                size: 12.5,
              ),
            ),
            const SizedBox(width: 10),
            if (fully)
              const Row(
                children: [
                  Icon(Icons.check_rounded, size: 13, color: AppColors.green),
                  SizedBox(width: 4),
                  Text(
                    'Fully used',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.greenDeep,
                    ),
                  ),
                ],
              )
            else
              Text(
                '${formatQty(left)} left',
                style: AppText.mono(
                  size: 11,
                  weight: FontWeight.w600,
                  color: AppColors.cautionDeep,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Shaped like the cards that replace them: a heading, then pack cards.
class _GroupedSkeleton extends StatelessWidget {
  const _GroupedSkeleton();

  @override
  Widget build(BuildContext context) {
    Widget card({double opacity = 1}) => Opacity(
      opacity: opacity,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.fromLTRB(14, 13, 14, 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.brTile,
          border: Border.all(color: AppColors.line),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: SkeletonBox(height: 14)),
                SizedBox(width: 10),
                SkeletonBox(width: 58, height: 10),
              ],
            ),
            SizedBox(height: 12),
            SkeletonBox(width: 120, height: 15),
            SizedBox(height: 10),
            SkeletonBox(height: 6, radius: 999),
          ],
        ),
      ),
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.gutter,
        AppSpace.lg,
        AppSpace.gutter,
        96,
      ),
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(2, 0, 2, 2),
          child: Row(
            children: [
              Expanded(child: SkeletonBox(height: 12)),
              SizedBox(width: 9),
              SkeletonBox(width: 52, height: 18, radius: 999),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(2, 0, 2, 10),
          child: SkeletonBox(width: 160, height: 10),
        ),
        card(),
        card(opacity: 0.5),
      ],
    );
  }
}
