import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:eal_scanner/controllers/usageController.dart';
import 'package:eal_scanner/models/usage.dart';
import 'package:eal_scanner/models/usage_grouping.dart';
import 'package:eal_scanner/screens/usages/EALStickerScreen.dart';
import 'package:eal_scanner/screens/usages/production_filter_sheet.dart';
import 'package:eal_scanner/screens/usages/usageDetailScreen.dart';
import 'package:eal_scanner/services/authService.dart';
import 'package:eal_scanner/theme/app_tokens.dart';
import 'package:eal_scanner/utils/formatting.dart';
import 'package:eal_scanner/widgets/ui/chips.dart';
import 'package:eal_scanner/widgets/ui/date_range_sheet.dart';
import 'package:eal_scanner/widgets/ui/feedback.dart';
import 'package:eal_scanner/widgets/ui/serial_text.dart';

/// Labels applied to a bottling run.
///
/// Reads the same way as the issuance list — grouped by company and market,
/// the dates and the filter each behind one button, the entries folded away
/// until asked for — with two differences that come from the record rather
/// than the design: the second level is the item being made rather than a
/// pack size, and cases carry the screen. An item card says what was
/// produced and how much of it is still waiting to go out; the labels are
/// the excise paperwork behind the cases, so they sit in the small line
/// under the item name.
class UsagesListScreen extends StatefulWidget {
  const UsagesListScreen({super.key});

  @override
  State<UsagesListScreen> createState() => _UsagesListScreenState();
}

class _UsagesListScreenState extends State<UsagesListScreen> {
  final UsageController _controller = Get.find<UsageController>();
  bool _requested = false;

  /// Which items are open. Collapsed is the default, and anything that
  /// fetches a different set of records closes them again — an item left
  /// open from the last date would be one the operator never opened.
  final Set<String> _open = {};

  String _key(UsageGroup g, ItemGroup i) =>
      '${g.companyName}|${g.market}|${i.itemName}';

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
      if (!_requested && _controller.ealUsages.isEmpty) {
        _requested = true;
        _controller.fetchEALUsage();
      }
    });
  }

  bool get _canRecord => AuthService.can('usage:create');

  /// Records an entry, then catches the list up on the way back. The flow
  /// writes to the server, so what is behind it is a moment out of date the
  /// instant it succeeds.
  Future<void> _newEntry() async {
    await Get.to(() => EALStickerScreen());
    await _controller.refreshIfStale();
  }

  Future<void> _pickDates() async {
    final span = await showDateRangeSheet(
      context: context,
      from: _controller.fromDate.value,
      to: _controller.toDate.value,
      lastAllowed: DateTime.now(),
      accent: AppColors.teal,
    );
    // Through _reload, so an item left open from the last span folds away
    // with it — the sheet is now the only way the dates change.
    if (span != null) {
      _reload(() => _controller.setSpan(span.from, span.to));
    }
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
              // Stretch, or a child that sizes to its content centres
              // itself under a left-aligned title.
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Obx(
                    () => _TitleRow(
                      entryCount: _controller.ealUsages.length,
                      loadingCount:
                          _controller.isLoading.value &&
                          _controller.ealUsages.isEmpty,
                      spanLabel: _spanLabel,
                      filterCount: _controller.activeFilterCount,
                      onDates: _pickDates,
                      onFilter: () async {
                        await showProductionFilterSheet(context);
                        if (mounted) setState(_open.clear);
                      },
                    ),
                  ),

                  Obx(() {
                    final showing =
                        _controller.isLoading.value &&
                        _controller.ealUsages.isNotEmpty;
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
      // Storekeeper and Dispatch may read this list but not record on it,
      // so they are not offered the button.
      floatingActionButton: _canRecord
          ? FloatingActionButton(
              onPressed: _newEntry,
              backgroundColor: AppColors.teal,
              foregroundColor: Colors.white,
              elevation: 2,
              shape: const CircleBorder(),
              tooltip: 'New production entry',
              child: const Icon(Icons.add_rounded, size: 26),
            )
          : null,
    );
  }

  Widget _buildBody() {
    final error = _controller.errorMessage.value;

    if (_controller.isLoading.value && _controller.ealUsages.isEmpty) {
      return const _GroupedSkeleton();
    }

    if (error.isNotEmpty && _controller.ealUsages.isEmpty) {
      // A lost network is not a server error. It gets the same state the
      // home screen gives it, in the same words, rather than the red banner
      // a refusal or a rejected range gets.
      if (_controller.isOffline.value) {
        return OfflineState(
          what: 'production entries',
          isRetrying: _controller.isLoading.value,
          onRetry: _controller.fetchEALUsage,
        );
      }

      // Top-aligned, or the banner takes every pixel it is offered and
      // fills the screen with one colour.
      return SingleChildScrollView(
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
          message:
              'There are entries in these dates, but none of them match '
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
        message:
            'No filters are on, so this is every entry for the dates. '
            'Widen them, or record the run you have in hand.',
        accent: AppColors.teal,
        tint: AppColors.tealTint,
        primaryLabel: 'Show the last 7 days',
        onPrimary: () => _reload(() => _controller.setLastDays(7)),
        secondaryLabel: _canRecord ? 'Record a production entry' : null,
        onSecondary: _canRecord ? _newEntry : null,
      );
    }

    return RefreshIndicator(
      color: AppColors.teal,
      onRefresh: () async => _controller.fetchEALUsage(),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(
          AppSpace.gutter,
          AppSpace.lg,
          AppSpace.gutter,
          96,
        ),
        // The total is worth a line only when more than one company is
        // listed. With one, the heading right below carries those very
        // numbers.
        itemCount: groups.length + (groups.length > 1 ? 1 : 0),
        itemBuilder: (_, index) {
          var i = index;
          if (groups.length > 1) {
            if (i == 0) {
              return _TotalStrip(
                cases: _controller.totalCases,
                waiting: _controller.totalWaiting,
              );
            }
            i -= 1;
          }

          return _GroupSection(
            group: groups[i],
            // The date is worth a row's width only when the span covers
            // more than one day; the server keeps no time of day, so a
            // clock there would read 00:00 on every entry.
            showDates: !_controller.isSingleDay,
            isOpen: (item) => _open.contains(_key(groups[i], item)),
            onToggle: (item) => _toggle(_key(groups[i], item)),
          );
        },
      ),
    );
  }
}

/// What this is, and the two controls. The day shortcuts moved into the
/// date sheet, so the dates are chosen in one place instead of two — and
/// the row they used to take is back in the list.
class _TitleRow extends StatelessWidget {
  const _TitleRow({
    required this.entryCount,
    required this.loadingCount,
    required this.spanLabel,
    required this.filterCount,
    required this.onDates,
    required this.onFilter,
  });

  final int entryCount;
  final bool loadingCount;

  /// The span in force, carried on the button so the header still says what
  /// is on screen without a row of its own.
  final String spanLabel;

  final int filterCount;
  final VoidCallback onDates;
  final VoidCallback onFilter;

  @override
  Widget build(BuildContext context) {
    final on = filterCount > 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.gutter,
        10,
        AppSpace.gutter,
        12,
      ),
      child: Row(
        children: [
          Expanded(
            // The count belongs to the title, so it costs no height of
            // its own — the buttons beside it are taller than one line.
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Production',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                    color: AppColors.ink900,
                  ),
                ),
                const SizedBox(height: 1),
                if (loadingCount)
                  const SkeletonBox(width: 62, height: 11)
                else
                  Text(
                    '$entryCount ${entryCount == 1 ? 'entry' : 'entries'}',
                    style: AppText.micro,
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _HeaderButton(
            onTap: onDates,
            semanticLabel: 'Dates — $spanLabel',
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.calendar_today_rounded,
                  size: 15,
                  color: AppColors.tealDeep,
                ),
                const SizedBox(width: 6),
                Text(
                  spanLabel,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _HeaderButton(
            onTap: onFilter,
            filled: on,
            semanticLabel: on
                ? 'Filter — $filterCount '
                      '${filterCount == 1 ? 'filter' : 'filters'} on'
                : 'Filter',
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.filter_list_rounded,
                  size: 17,
                  color: on ? Colors.white : AppColors.ink700,
                ),
                if (on) ...[
                  const SizedBox(width: 6),
                  Text(
                    '$filterCount',
                    style: AppText.mono(
                      size: 12.5,
                      weight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A 38px control, square when it carries only an icon.
class _HeaderButton extends StatelessWidget {
  const _HeaderButton({
    required this.child,
    required this.onTap,
    required this.semanticLabel,
    this.filled = false,
  });

  final Widget child;
  final VoidCallback onTap;
  final String semanticLabel;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          height: 38,
          constraints: const BoxConstraints(minWidth: 38),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: filled ? AppColors.teal : AppColors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: filled ? AppColors.teal : AppColors.lineField,
              width: 1.5,
            ),
          ),
          child: Center(child: child),
        ),
      ),
    );
  }
}

/// Everything on screen, added up, above the companies it adds up. Drawn
/// only when more than one company is listed.
class _TotalStrip extends StatelessWidget {
  const _TotalStrip({required this.cases, required this.waiting});

  final int cases;
  final int waiting;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(2, 0, 2, 12),
      margin: const EdgeInsets.only(bottom: 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.line, width: 1)),
      ),
      // A Wrap, not a Row: a month of production runs to seven digits, and
      // a figure that loses its tail reads as a smaller number. The figures
      // take a second line rather than being cut.
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.end,
        spacing: 10,
        runSpacing: 4,
        children: [
          const Text('ALL COMPANIES', style: AppText.section),
          Text.rich(
            TextSpan(
              style: const TextStyle(fontSize: 11.5, color: AppColors.ink500),
              children: [
                TextSpan(
                  text: formatQty(cases),
                  style: AppText.mono(size: 13, weight: FontWeight.w600),
                ),
                const TextSpan(text: ' produced  ·  '),
                TextSpan(
                  text: formatQty(waiting),
                  style: AppText.mono(
                    size: 13,
                    weight: FontWeight.w600,
                    color: AppColors.cautionDeep,
                  ),
                ),
                const TextSpan(text: ' waiting'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A company and market reads as a heading on the canvas, not as another
/// card. Its items are the cards, so the gaps between them carry the
/// separation that two near-identical tints could not.
class _GroupSection extends StatelessWidget {
  const _GroupSection({
    required this.group,
    required this.showDates,
    required this.isOpen,
    required this.onToggle,
  });

  final UsageGroup group;
  final bool showDates;
  final bool Function(ItemGroup) isOpen;
  final void Function(ItemGroup) onToggle;

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
          child: _ProducedWaiting(cases: group.cases, waiting: group.waiting),
        ),
        for (final item in group.items)
          _ItemCard(
            item: item,
            showDates: showDates,
            open: isOpen(item),
            onToggle: () => onToggle(item),
          ),
        const SizedBox(height: 8),
      ],
    );
  }
}

/// "269,500 cases produced · 157,200 waiting", under a company and market.
class _ProducedWaiting extends StatelessWidget {
  const _ProducedWaiting({required this.cases, required this.waiting});

  final int cases;
  final int waiting;

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(fontSize: 11.5, color: AppColors.ink500);

    if (waiting <= 0 && cases > 0) {
      return Text.rich(
        TextSpan(
          style: style,
          children: [
            TextSpan(
              text: formatQty(cases),
              style: AppText.mono(
                size: 11.5,
                weight: FontWeight.w600,
                color: AppColors.ink700,
              ),
            ),
            const TextSpan(text: ' cases produced · all dispatched'),
          ],
        ),
        maxLines: 2,
      );
    }

    return Text.rich(
      TextSpan(
        style: style,
        children: [
          TextSpan(
            text: formatQty(cases),
            style: AppText.mono(
              size: 11.5,
              weight: FontWeight.w600,
              color: AppColors.ink700,
            ),
          ),
          const TextSpan(text: ' cases produced · '),
          TextSpan(
            text: formatQty(waiting),
            style: AppText.mono(
              size: 11.5,
              weight: FontWeight.w600,
              color: AppColors.ink700,
            ),
          ),
          const TextSpan(text: ' waiting'),
        ],
      ),
      // Two lines, not one with an ellipsis: a figure that loses its tail
      // reads as a smaller number, which is worse than a second line.
      maxLines: 2,
    );
  }
}

/// One item, with its entries folded away until asked for. The figures and
/// the bar stay on the card, so how much has gone out reads without opening
/// it.
class _ItemCard extends StatelessWidget {
  const _ItemCard({
    required this.item,
    required this.showDates,
    required this.open,
    required this.onToggle,
  });

  final ItemGroup item;
  final bool showDates;
  final bool open;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final cases = item.cases;
    final waiting = item.waiting;
    final done = waiting <= 0 && cases > 0;
    final count = item.rows.length;

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
                '${item.itemName}, $count '
                '${count == 1 ? 'entry' : 'entries'}',
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
                            item.itemName,
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
                          '$count ${count == 1 ? 'entry' : 'entries'}',
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

                    // The labels are the paperwork behind the cases, so they
                    // ride with the pack size rather than beside the figure.
                    const SizedBox(height: 2),
                    Text.rich(
                      TextSpan(
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: AppColors.ink500,
                        ),
                        children: [
                          if (item.bottlesPerCase != null)
                            TextSpan(
                              text: '${item.bottlesPerCase} per case · ',
                            ),
                          TextSpan(
                            text: formatQty(item.labels),
                            style: AppText.mono(size: 11.5),
                          ),
                          const TextSpan(text: ' labels'),
                        ],
                      ),
                      maxLines: 2,
                    ),

                    // The figure you came for, then what is still to go out.
                    const SizedBox(height: 11),
                    SizedBox(
                      width: double.infinity,
                      child: Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 10,
                        runSpacing: 2,
                        children: [
                          Row(
                            // Without this a Row claims the whole width, so
                            // each half would take a line of its own even
                            // with room to spare.
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                formatQty(cases),
                                style: AppText.mono(
                                  size: 16,
                                  weight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 5),
                              Text('cases', style: AppText.micro),
                            ],
                          ),
                          // Nothing waiting reads as a state, not a zero.
                          if (done)
                            const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.check_rounded,
                                  size: 14,
                                  color: AppColors.green,
                                ),
                                SizedBox(width: 5),
                                Text(
                                  'All dispatched',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.greenDeep,
                                  ),
                                ),
                              ],
                            )
                          else
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Text(
                                  formatQty(waiting),
                                  style: AppText.mono(
                                    size: 13,
                                    weight: FontWeight.w600,
                                    color: AppColors.cautionDeep,
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Text('waiting', style: AppText.micro),
                              ],
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    LinkedProgressBar(
                      linked: item.dispatched,
                      required_: cases == 0 ? 1 : cases,
                      height: 6,
                      accent: done ? AppColors.green : AppColors.caution,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Opened entries live inside the item's own card, so they can only
          // belong to it.
          if (open)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 4),
              child: Column(
                children: [
                  for (final row in item.rows)
                    _EntryRow(usage: row, showDate: showDates),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// One production entry: the range it consumed, what it came to in cases,
/// and how much of that is still waiting to go out.
class _EntryRow extends StatelessWidget {
  const _EntryRow({required this.usage, required this.showDate});

  final UsageModel usage;
  final bool showDate;

  @override
  Widget build(BuildContext context) {
    final waiting = usage.balanceQuantityInCases;
    final done = waiting <= 0 && usage.usedQuantityInCases > 0;

    return InkWell(
      onTap: () => Get.to(() => EALUsageDetailScreen(usage: usage)),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.lineSoft, width: 1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SerialRangeText(
              prefix: usage.prefix,
              from: int.tryParse(usage.serialFrom) ?? 0,
              to: int.tryParse(usage.serialTo) ?? 0,
              size: 13,
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 10,
                runSpacing: 2,
                children: [
                  Text.rich(
                    TextSpan(
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.ink500,
                      ),
                      children: [
                        TextSpan(
                          text: formatQty(usage.usedQuantityInCases),
                          style: AppText.mono(
                            size: 12.5,
                            weight: FontWeight.w600,
                          ),
                        ),
                        const TextSpan(text: ' cases · '),
                        if (done)
                          const TextSpan(
                            text: 'all dispatched',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppColors.greenDeep,
                            ),
                          )
                        else ...[
                          TextSpan(
                            text: formatQty(waiting),
                            style: AppText.mono(
                              size: 11.5,
                              weight: FontWeight.w600,
                              color: AppColors.cautionDeep,
                            ),
                          ),
                          const TextSpan(text: ' waiting'),
                        ],
                      ],
                    ),
                    maxLines: 2,
                  ),
                  if (showDate)
                    Text(
                      formatDayMonth(usage.dateUsed),
                      style: AppText.mono(size: 11, color: AppColors.ink500),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shaped like what replaces it: a company heading, then item cards with
/// their entries folded away.
class _GroupedSkeleton extends StatelessWidget {
  const _GroupedSkeleton();

  @override
  Widget build(BuildContext context) {
    Widget itemCard({double opacity = 1}) {
      return Opacity(
        opacity: opacity,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadius.brTile,
            border: Border.all(color: AppColors.line),
          ),
          child: const Padding(
            padding: EdgeInsets.fromLTRB(14, 13, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: SkeletonBox(height: 14)),
                    SizedBox(width: 10),
                    SkeletonBox(width: 54, height: 10),
                  ],
                ),
                SizedBox(height: 8),
                SkeletonBox(width: 142, height: 10),
                SizedBox(height: 13),
                Row(
                  children: [
                    SkeletonBox(width: 96, height: 15),
                    Spacer(),
                    SkeletonBox(width: 64, height: 11),
                  ],
                ),
                SizedBox(height: 10),
                SkeletonBox(height: 6, radius: 999),
              ],
            ),
          ),
        ),
      );
    }

    Widget heading() {
      return const Padding(
        padding: EdgeInsets.fromLTRB(2, 0, 2, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: SkeletonBox(height: 12)),
                SizedBox(width: 9),
                SkeletonBox(width: 50, height: 18, radius: 999),
              ],
            ),
            SizedBox(height: 7),
            SkeletonBox(width: 168, height: 10),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.gutter,
        AppSpace.lg,
        AppSpace.gutter,
        96,
      ),
      children: [
        heading(),
        itemCard(),
        itemCard(opacity: 0.55),
        const SizedBox(height: 8),
        Opacity(opacity: 0.35, child: heading()),
      ],
    );
  }
}
