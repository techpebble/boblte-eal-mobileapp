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
          // Title and the one filter button. Reading the observables inside
          // the Obx closure is what keeps GetX watching them.
          Obx(() {
            final count = _controller.ealIssuance.length;
            return _Header(
              countLabel: _controller.isLoading.value && count == 0
                  ? null
                  : '$count ${count == 1 ? 'record' : 'records'}',
              filterCount: _controller.activeFilterCount,
              onFilter: () => showIssuanceFilterSheet(context),
              showProgress: _controller.isLoading.value && count > 0,
            );
          }),

          Obx(
            () => _DateRow(
              isToday: _controller.isPreset(1),
              isYesterday: _controller.isYesterday,
              isWeek: _controller.isPreset(7),
              spanLabel: _spanLabel,
              spanActive: !_controller.isPreset(1) &&
                  !_controller.isYesterday &&
                  !_controller.isPreset(7),
              onToday: () => _controller.setLastDays(1),
              onYesterday: _controller.setYesterday,
              onWeek: () => _controller.setLastDays(7),
              onPickDates: _pickDates,
            ),
          ),

          Obx(() {
            // Holds its place while loading, so the figures do not shove the
            // list down when they land.
            final loading =
                _controller.isLoading.value && _controller.ealIssuance.isEmpty;
            if (!loading && _controller.filteredIssuance.isEmpty) {
              return const SizedBox.shrink();
            }

            return Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.gutter,
                AppSpace.md,
                AppSpace.gutter,
                0,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: _SummaryFigure(
                      value: loading ? null : formatQty(_controller.totalIssued),
                      label: 'labels issued',
                    ),
                  ),
                  _SummaryFigure(
                    value: loading ? null : formatQty(_controller.totalUnused),
                    label: 'unused',
                    color: AppColors.caution,
                    alignEnd: true,
                  ),
                ],
              ),
            );
          }),

          Expanded(child: Obx(_buildBody)),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addStickers,
        backgroundColor: AppColors.indigo,
        foregroundColor: Colors.white,
        elevation: 2,
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
          message: 'There are records in these dates, but none of them match '
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
        message: 'No filters are on, so this is every record for the dates. '
            'Widen them, or record the issuance you have in hand.',
        accent: AppColors.indigo,
        tint: AppColors.indigoTint,
        primaryLabel: 'Show the last 7 days',
        onPrimary: () => _controller.setLastDays(7),
        secondaryLabel: 'Record a new issuance',
        onSecondary: _addStickers,
      );
    }

    return RefreshIndicator(
      color: AppColors.indigo,
      onRefresh: () async => _controller.fetchEALIssuance(),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(
          AppSpace.gutter,
          AppSpace.md,
          AppSpace.gutter,
          96,
        ),
        itemCount: groups.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) => _GroupCard(group: groups[i]),
      ),
    );
  }
}

/// Title, record count, and the one button that stands for all three
/// filters. Lit with a count when any are on, so a filtered list never
/// passes for the whole list.
class _Header extends StatelessWidget {
  const _Header({
    required this.countLabel,
    required this.filterCount,
    required this.onFilter,
    required this.showProgress,
  });

  final String? countLabel;
  final int filterCount;
  final VoidCallback onFilter;
  final bool showProgress;

  @override
  Widget build(BuildContext context) {
    final on = filterCount > 0;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.line, width: 1)),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
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
                          borderRadius:
                              BorderRadius.circular(AppRadius.control),
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
            if (showProgress) const ThinLoadingBar(),
          ],
        ),
      ),
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
        padding: const EdgeInsets.fromLTRB(AppSpace.gutter, 10, AppSpace.gutter, 0),
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
      crossAxisAlignment:
          alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
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

/// One company and market, with its pack sizes banded inside.
class _GroupCard extends StatelessWidget {
  const _GroupCard({required this.group});

  final IssuanceGroup group;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.brTile,
        border: Border.all(color: AppColors.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 11, 14, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        group.companyName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.ink900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 9),
                    MarketChip(group.market),
                  ],
                ),
                const SizedBox(height: 3),
                _IssuedLeft(issued: group.issued, unused: group.unused),
              ],
            ),
          ),
          for (final pack in group.packs) ...[
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: AppColors.canvas,
                border: Border(
                  top: BorderSide(color: AppColors.lineSoft, width: 1),
                  bottom: BorderSide(color: AppColors.lineSoft, width: 1),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Expanded(
                    child: Text(
                      pack.packName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _IssuedLeft(
                    issued: pack.issued,
                    unused: pack.unused,
                    size: 11,
                  ),
                ],
              ),
            ),
            for (final row in pack.rows) _RangeRow(issuance: row),
          ],
        ],
      ),
    );
  }
}

/// "96,000 issued · 38,400 left", the pair every level of the list repeats.
class _IssuedLeft extends StatelessWidget {
  const _IssuedLeft({
    required this.issued,
    required this.unused,
    this.size = 11.5,
  });

  final int issued;
  final int unused;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        style: TextStyle(fontSize: size, color: AppColors.ink500),
        children: [
          TextSpan(
            text: formatQty(issued),
            style: AppText.mono(
              size: size,
              weight: FontWeight.w600,
              color: AppColors.ink700,
            ),
          ),
          const TextSpan(text: ' issued · '),
          TextSpan(
            text: formatQty(unused),
            style: AppText.mono(
              size: size,
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

/// One issuance record: its range, and how much of it is gone.
class _RangeRow extends StatelessWidget {
  const _RangeRow({required this.issuance});

  final IssuanceModel issuance;

  @override
  Widget build(BuildContext context) {
    final issued = issuance.issuedQuantity;
    final left = issuance.balanceQuantity;
    final used = issued - left;
    final fully = left <= 0 && issued > 0;

    return InkWell(
      onTap: () => Get.to(() => EALIssuanceDetailScreen(issuance: issuance)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SerialRangeText(
              prefix: issuance.prefix,
              from: int.tryParse(issuance.serialFrom) ?? 0,
              to: int.tryParse(issuance.serialTo) ?? 0,
              size: 13.5,
            ),
            const SizedBox(height: 9),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.ink700,
                      ),
                      children: [
                        TextSpan(
                          text: formatQty(used),
                          style: AppText.mono(
                            size: 11.5,
                            weight: FontWeight.w600,
                          ),
                        ),
                        const TextSpan(text: ' of '),
                        TextSpan(
                          text: formatQty(issued),
                          style: AppText.mono(size: 11.5),
                        ),
                        const TextSpan(text: ' used'),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                if (fully)
                  const Row(
                    children: [
                      Icon(Icons.check_rounded, size: 13, color: AppColors.green),
                      SizedBox(width: 4),
                      Text(
                        'Fully used',
                        style: TextStyle(
                          fontSize: 11.5,
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
                      size: 11.5,
                      weight: FontWeight.w600,
                      color: AppColors.ink500,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            LinkedProgressBar(
              linked: used,
              required_: issued == 0 ? 1 : issued,
              height: 6,
              accent: fully ? AppColors.green : AppColors.caution,
            ),
          ],
        ),
      ),
    );
  }
}

/// Shaped like the cards that replace them: a company band, a pack band,
/// then a range.
class _GroupedSkeleton extends StatelessWidget {
  const _GroupedSkeleton();

  @override
  Widget build(BuildContext context) {
    Widget card({required int packs, double opacity = 1}) {
      return Opacity(
        opacity: opacity,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadius.brTile,
            border: Border.all(color: AppColors.line),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(14, 11, 14, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: SkeletonBox(height: 13)),
                        SizedBox(width: 9),
                        SkeletonBox(width: 56, height: 20, radius: 999),
                      ],
                    ),
                    SizedBox(height: 8),
                    SkeletonBox(width: 152, height: 10),
                  ],
                ),
              ),
              for (var i = 0; i < packs; i++) ...[
                Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: AppColors.canvas,
                    border: Border(
                      top: BorderSide(color: AppColors.lineSoft, width: 1),
                      bottom: BorderSide(color: AppColors.lineSoft, width: 1),
                    ),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  child: const Row(
                    children: [
                      SkeletonBox(width: 104, height: 11),
                      Spacer(),
                      SkeletonBox(width: 118, height: 10),
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(14, 11, 14, 13),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SkeletonBox(width: 198, height: 13),
                      SizedBox(height: 10),
                      Row(
                        children: [
                          SkeletonBox(width: 108, height: 10),
                          Spacer(),
                          SkeletonBox(width: 58, height: 10),
                        ],
                      ),
                      SizedBox(height: 7),
                      SkeletonBox(height: 6, radius: 999),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.gutter,
        AppSpace.md,
        AppSpace.gutter,
        96,
      ),
      children: [
        card(packs: 2),
        const SizedBox(height: 10),
        card(packs: 1, opacity: 0.5),
      ],
    );
  }
}
