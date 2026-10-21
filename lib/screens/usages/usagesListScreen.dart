import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:eal_scanner/controllers/usageController.dart';
import 'package:eal_scanner/models/usage.dart';
import 'package:eal_scanner/models/usage_grouping.dart';
import 'package:eal_scanner/screens/usages/EALStickerScreen.dart';
import 'package:eal_scanner/screens/usages/production_filter_sheet.dart';
import 'package:eal_scanner/screens/usages/usageDetailScreen.dart';
import 'package:eal_scanner/theme/app_tokens.dart';
import 'package:eal_scanner/utils/formatting.dart';
import 'package:eal_scanner/widgets/ui/chips.dart';
import 'package:eal_scanner/widgets/ui/date_range_sheet.dart';
import 'package:eal_scanner/widgets/ui/feedback.dart';
import 'package:eal_scanner/widgets/ui/serial_text.dart';

/// Labels applied to a bottling run.
///
/// Reads the same way as the issuance list — grouped by company and market,
/// one filter button, a date span — with two differences that come from the
/// record rather than the design: production counts in cases, so cases lead,
/// and the second level is the item being made rather than a pack size.
class UsagesListScreen extends StatefulWidget {
  const UsagesListScreen({super.key});

  @override
  State<UsagesListScreen> createState() => _UsagesListScreenState();
}

class _UsagesListScreenState extends State<UsagesListScreen> {
  final UsageController _controller = Get.find<UsageController>();
  bool _requested = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_requested && _controller.ealUsages.isEmpty) {
        _requested = true;
        _controller.fetchEALUsage();
      }
    });
  }

  void _newEntry() => Get.to(() => EALStickerScreen());

  Future<void> _pickDates() async {
    final span = await showDateRangeSheet(
      context: context,
      from: _controller.fromDate.value,
      to: _controller.toDate.value,
      lastAllowed: DateTime.now(),
      accent: AppColors.teal,
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
            final count = _controller.ealUsages.length;
            return _Header(
              countLabel: _controller.isLoading.value && count == 0
                  ? null
                  : '$count ${count == 1 ? 'entry' : 'entries'}',
              filterCount: _controller.activeFilterCount,
              onFilter: () => showProductionFilterSheet(context),
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
                _controller.isLoading.value && _controller.ealUsages.isEmpty;
            if (!loading && _controller.filteredUsages.isEmpty) {
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
                      value: loading ? null : formatQty(_controller.totalCases),
                      label: 'cases entered',
                    ),
                  ),
                  _SummaryFigure(
                    value: loading ? null : formatQty(_controller.totalLabels),
                    label: 'labels consumed',
                    color: AppColors.tealDeep,
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
        onPressed: _newEntry,
        backgroundColor: AppColors.teal,
        foregroundColor: Colors.white,
        elevation: 2,
        tooltip: 'New production entry',
        child: const Icon(Icons.add_rounded, size: 26),
      ),
    );
  }

  Widget _buildBody() {
    final error = _controller.errorMessage.value;

    if (_controller.isLoading.value && _controller.ealUsages.isEmpty) {
      return const _GroupedSkeleton();
    }

    if (error.isNotEmpty && _controller.ealUsages.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(AppSpace.gutter),
        child: NoticeBanner(
          level: NoticeLevel.error,
          title: 'Could not load production',
          message: error,
          trailing: TextButton(
            onPressed: _controller.fetchEALUsage,
            child: const Text('Retry'),
          ),
        ),
      );
    }

    final groups = _controller.groupedUsages;

    if (groups.isEmpty) {
      // Filters hide behind one button, so an empty list has to say which of
      // the two reasons it is empty for.
      if (_controller.hasFilters) {
        return EmptyState(
          icon: Icons.filter_alt_off_rounded,
          title: 'Nothing matches the filters',
          message: 'There are entries in these dates, but none of them match '
              'what the filter is set to.',
          accent: AppColors.teal,
          tint: AppColors.tealTint,
          primaryLabel: 'Clear the filters',
          onPrimary: _controller.clearFilters,
          secondaryLabel: 'Change the filters',
          onSecondary: () => showProductionFilterSheet(context),
        );
      }

      return EmptyState(
        icon: Icons.event_busy_rounded,
        title: _controller.isSingleDay
            ? 'Nothing entered on '
                '${formatDayMonthYear(_controller.fromDate.value)}'
            : 'Nothing entered in these dates',
        message: 'No filters are on, so this is every entry for the dates. '
            'Widen them, or record the run you have in hand.',
        accent: AppColors.teal,
        tint: AppColors.tealTint,
        primaryLabel: 'Show the last 7 days',
        onPrimary: () => _controller.setLastDays(7),
        secondaryLabel: 'Record a production entry',
        onSecondary: _newEntry,
      );
    }

    return RefreshIndicator(
      color: AppColors.teal,
      onRefresh: () async => _controller.fetchEALUsage(),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(
          AppSpace.gutter,
          AppSpace.md,
          AppSpace.gutter,
          96,
        ),
        itemCount: groups.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        // The date is worth a row's width only when the span covers more
        // than one day; the server keeps no time of day, so a clock there
        // would read 00:00 on every entry.
        itemBuilder: (_, i) => _GroupCard(
          group: groups[i],
          showDates: !_controller.isSingleDay,
        ),
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
                            'Production',
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
                          color: on ? AppColors.teal : AppColors.surface,
                          borderRadius:
                              BorderRadius.circular(AppRadius.control),
                          border: Border.all(
                            color: on ? AppColors.teal : AppColors.lineField,
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
            accent: AppColors.teal,
            onTap: onToday,
          ),
          const SizedBox(width: 7),
          FilterPill(
            label: 'Yesterday',
            selected: isYesterday,
            accent: AppColors.teal,
            onTap: onYesterday,
          ),
          const SizedBox(width: 7),
          FilterPill(
            label: '7 days',
            selected: isWeek,
            accent: AppColors.teal,
            onTap: onWeek,
          ),
          const SizedBox(width: 7),
          FilterPill(
            label: spanLabel,
            selected: spanActive,
            accent: AppColors.teal,
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

/// One company and market, with its items banded inside.
class _GroupCard extends StatelessWidget {
  const _GroupCard({required this.group, required this.showDates});

  final UsageGroup group;
  final bool showDates;

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
                _CasesLabels(cases: group.cases, labels: group.labels),
              ],
            ),
          ),
          for (final item in group.items) ...[
            // Two lines, not one: an item name and its figures do not fit
            // across a phone the way a pack size does.
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: AppColors.canvas,
                border: Border(
                  top: BorderSide(color: AppColors.lineSoft, width: 1),
                  bottom: BorderSide(color: AppColors.lineSoft, width: 1),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: item.itemName,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.ink900,
                          ),
                        ),
                        if (item.bottlesPerCase != null)
                          TextSpan(
                            text: ' · ${item.bottlesPerCase} per case',
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: AppColors.ink500,
                            ),
                          ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  _CasesLabels(
                    cases: item.cases,
                    labels: item.labels,
                    size: 11,
                  ),
                ],
              ),
            ),
            for (final row in item.rows)
              _EntryRow(usage: row, showDate: showDates),
          ],
        ],
      ),
    );
  }
}

/// "1,166 cases · 13,992 labels", the pair every level of the list repeats.
/// Cases lead, because that is what a production run is counted in.
class _CasesLabels extends StatelessWidget {
  const _CasesLabels({
    required this.cases,
    required this.labels,
    this.size = 11.5,
  });

  final int cases;
  final int labels;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        style: TextStyle(fontSize: size, color: AppColors.ink500),
        children: [
          TextSpan(
            text: formatQty(cases),
            style: AppText.mono(
              size: size,
              weight: FontWeight.w600,
              color: AppColors.ink700,
            ),
          ),
          const TextSpan(text: ' cases · '),
          TextSpan(
            text: formatQty(labels),
            style: AppText.mono(
              size: size,
              weight: FontWeight.w600,
              color: AppColors.ink700,
            ),
          ),
          const TextSpan(text: ' labels'),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

/// One production entry: the range it consumed, what it came to, and when.
///
/// No bar here, unlike issuance: an entry is a withdrawal and has no balance
/// of its own to drain. The date takes that place while the span covers more
/// than one day — the server keeps no time of day, so a clock would read
/// 00:00 on every row.
class _EntryRow extends StatelessWidget {
  const _EntryRow({required this.usage, required this.showDate});

  final UsageModel usage;
  final bool showDate;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Get.to(() => EALUsageDetailScreen(usage: usage)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SerialRangeText(
              prefix: usage.prefix,
              from: int.tryParse(usage.serialFrom) ?? 0,
              to: int.tryParse(usage.serialTo) ?? 0,
              size: 13.5,
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.ink500,
                      ),
                      children: [
                        TextSpan(
                          text: formatQty(usage.usedQuantityInCases),
                          style: AppText.mono(
                            size: 13,
                            weight: FontWeight.w600,
                          ),
                        ),
                        const TextSpan(text: ' cases · '),
                        TextSpan(
                          text: formatQty(usage.usedQuantity),
                          style: AppText.mono(size: 11.5),
                        ),
                        const TextSpan(text: ' labels'),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (showDate) ...[
                  const SizedBox(width: 8),
                  Text(
                    formatDayMonth(usage.dateUsed),
                    style: AppText.mono(size: 11, color: AppColors.ink500),
                  ),
                ],
              ],
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
