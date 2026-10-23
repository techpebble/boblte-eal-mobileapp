import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:eal_scanner/controllers/dispatchController.dart';
import 'package:eal_scanner/models/dispatch.dart';
import 'package:eal_scanner/models/dispatch_grouping.dart';
import 'package:eal_scanner/screens/dispatches/DispatchDetailScreen.dart';
import 'package:eal_scanner/screens/dispatches/dispatch_filter_sheet.dart';
import 'package:eal_scanner/theme/app_tokens.dart';
import 'package:eal_scanner/utils/formatting.dart';
import 'package:eal_scanner/widgets/ui/chips.dart';
import 'package:eal_scanner/widgets/ui/date_range_sheet.dart';
import 'package:eal_scanner/widgets/ui/feedback.dart';

/// Dispatch notes, grouped the way issuance and production are.
///
/// Two differences come from the record rather than the design. Search keeps
/// a row of its own: a note is looked up by the depot it is going to, the
/// vehicle at the gate or the driver asking, and none of those is something
/// to pick from a sheet. And a note's card does not open — its lines live on
/// its own screen, and listing them here only buries the next depot.
class DispatchListScreen extends StatefulWidget {
  const DispatchListScreen({super.key});

  @override
  State<DispatchListScreen> createState() => _DispatchListScreenState();
}

class _DispatchListScreenState extends State<DispatchListScreen> {
  final DispatchController _controller = Get.find<DispatchController>();
  bool _requested = false;

  /// Held here so that clearing the search clears the box as well. With the
  /// field keeping its own text, "Clear the search" refilled the list and
  /// left the words sitting above it, the two disagreeing.
  final TextEditingController _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// The thing a dispatch clerk does most: see what still needs labels.
  /// It was one tap on the old screen's "Short" chip, and four once the
  /// stages moved into the filter sheet.
  void _toggleShortOnly() {
    _controller.statusFilter.value = _controller.statusFilter.value == 'short'
        ? ''
        : 'short';
  }

  void _clearSearch() {
    _search.clear();
    _controller.searchQuery.value = '';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_requested && _controller.dispatches.isEmpty) {
        _requested = true;
        _controller.fetchDispatches();
      }
    });
  }

  Future<void> _pickDates() async {
    final span = await showDateRangeSheet(
      context: context,
      from: _controller.fromDate.value,
      to: _controller.toDate.value,
      lastAllowed: DateTime.now(),
      accent: AppColors.amber,
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
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Obx(
                    () => _TitleRow(
                      noteCount: _controller.dispatches.length,
                      loadingCount:
                          _controller.isLoading.value &&
                          _controller.dispatches.isEmpty,
                      spanLabel: _spanLabel,
                      filterCount: _controller.activeFilterCount,
                      short: _controller.totalShort,
                      showingShortOnly:
                          _controller.statusFilter.value == 'short',
                      onShort: _toggleShortOnly,
                      onDates: _pickDates,
                      onFilter: () => showDispatchFilterSheet(context),
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpace.gutter,
                      0,
                      AppSpace.gutter,
                      11,
                    ),
                    child: Obx(
                      () => _SearchField(
                        controller: _search,
                        // Read so the clear button appears and goes with
                        // the text.
                        hasText: _controller.searchQuery.value
                            .trim()
                            .isNotEmpty,
                        onChanged: (v) => _controller.searchQuery.value = v,
                        onClear: _clearSearch,
                      ),
                    ),
                  ),

                  Obx(() {
                    final showing =
                        _controller.isLoading.value &&
                        _controller.dispatches.isNotEmpty;
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
    );
  }

  Widget _buildBody() {
    final error = _controller.errorMessage.value;

    if (_controller.isLoading.value && _controller.dispatches.isEmpty) {
      return const SkeletonList();
    }

    if (error.isNotEmpty && _controller.dispatches.isEmpty) {
      // A lost network is not a server error. It gets the same state the
      // home screen gives it, in the same words, rather than the red banner
      // a refusal or a rejected range gets.
      if (_controller.isOffline.value) {
        return OfflineState(
          what: 'dispatch notes',
          isRetrying: _controller.isLoading.value,
          onRetry: _controller.fetchDispatches,
        );
      }

      // Top-aligned, or the banner takes every pixel it is offered and
      // fills the screen with one colour.
      return SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpace.gutter),
        child: NoticeBanner(
          level: NoticeLevel.error,
          title: 'Could not load dispatches',
          message: error,
          trailing: TextButton(
            onPressed: _controller.fetchDispatches,
            child: const Text('Retry'),
          ),
        ),
      );
    }

    final groups = _controller.groupedDispatches;

    if (groups.isEmpty) {
      final searching = _controller.searchQuery.value.trim().isNotEmpty;

      // Three reasons a list can be empty, and they are not the same thing
      // to do about.
      if (searching || _controller.hasFilters) {
        return EmptyState(
          icon: Icons.filter_alt_off_outlined,
          title: searching
              ? 'Nothing matches that search'
              : 'Nothing matches the filters',
          message: searching
              ? 'There are notes in these dates, but none with that depot, '
                    'vehicle or driver.'
              : 'There are notes in these dates, but none of them match '
                    'what the filter is set to.',
          accent: AppColors.amber,
          tint: AppColors.amberTint,
          primaryLabel: searching ? 'Clear the search' : 'Clear the filters',
          onPrimary: () {
            _clearSearch();
            _controller.clearFilters();
          },
          secondaryLabel: searching ? null : 'Change the filters',
          onSecondary: searching
              ? null
              : () => showDispatchFilterSheet(context),
        );
      }

      return EmptyState(
        icon: Icons.local_shipping_outlined,
        title: _controller.isSingleDay
            ? 'No dispatches on '
                  '${formatDayMonthYear(_controller.fromDate.value)}'
            : 'No dispatches in these dates',
        message:
            'Dispatch notes are raised in the back office. Widen the dates '
            'if you are looking for an earlier one.',
        accent: AppColors.amber,
        tint: AppColors.amberTint,
        primaryLabel: 'Show the last 7 days',
        onPrimary: () => _controller.setLastDays(7),
      );
    }

    return RefreshIndicator(
      color: AppColors.amber,
      onRefresh: () async => _controller.fetchDispatches(),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(
          AppSpace.gutter,
          AppSpace.lg,
          AppSpace.gutter,
          AppSpace.xxl,
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
                short: _controller.totalShort,
              );
            }
            i -= 1;
          }

          return _GroupSection(group: groups[i]);
        },
      ),
    );
  }
}

/// What this is, and the two controls, as on the other two lists.
class _TitleRow extends StatelessWidget {
  const _TitleRow({
    required this.noteCount,
    required this.loadingCount,
    required this.spanLabel,
    required this.filterCount,
    required this.short,
    required this.showingShortOnly,
    required this.onShort,
    required this.onDates,
    required this.onFilter,
  });

  final int noteCount;
  final bool loadingCount;

  /// Cases with no labels against them, across everything on screen.
  final int short;
  final bool showingShortOnly;
  final VoidCallback onShort;
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
        10,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Dispatch',
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
                  // A Wrap, so a long count or a wide font pushes the
                  // button onto its own line instead of cutting it off.
                  Wrap(
                    spacing: 7,
                    runSpacing: 3,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        '$noteCount ${noteCount == 1 ? 'note' : 'notes'}',
                        style: AppText.micro,
                      ),
                      // The figure is the shortcut, and it lives here
                      // rather than in the strip below: the strip is only
                      // drawn with more than one company, and most plants
                      // have one.
                      if (short > 0 || showingShortOnly)
                        _ShortButton(
                          short: short,
                          selected: showingShortOnly,
                          onTap: onShort,
                        ),
                    ],
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
                  color: AppColors.amberDeep,
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
            color: filled ? AppColors.amber : AppColors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: filled ? AppColors.amber : AppColors.lineField,
              width: 1.5,
            ),
          ),
          child: Center(child: child),
        ),
      ),
    );
  }
}

/// The one list that keeps a search box, and the reason is on the screen:
/// a vehicle number is not something to pick from a list of what exists.
class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.hasText,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final bool hasText;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      style: const TextStyle(fontSize: 14, color: AppColors.ink900),
      decoration: InputDecoration(
        hintText: 'Depot, vehicle or driver',
        hintStyle: const TextStyle(fontSize: 14, color: AppColors.ink400),
        prefixIcon: const Icon(
          Icons.search_rounded,
          size: 19,
          color: AppColors.ink500,
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 40),
        // Clearing a search was only offered on the empty state, so there
        // was no way back from one that matched something.
        suffixIcon: hasText
            ? IconButton(
                onPressed: onClear,
                icon: const Icon(Icons.close_rounded, size: 17),
                tooltip: 'Clear the search',
                visualDensity: VisualDensity.compact,
                color: AppColors.ink500,
              )
            : null,
        suffixIconConstraints: const BoxConstraints(minWidth: 40),
        filled: true,
        fillColor: AppColors.field,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 11),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(11),
          borderSide: const BorderSide(color: AppColors.lineField, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(11),
          borderSide: const BorderSide(color: AppColors.lineField, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(11),
          borderSide: const BorderSide(color: AppColors.amber, width: 1.5),
        ),
      ),
    );
  }
}

/// Everything on screen, added up, above the companies it adds up.
class _TotalStrip extends StatelessWidget {
  const _TotalStrip({required this.cases, required this.short});

  final int cases;
  final int short;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(2, 0, 2, 12),
      margin: const EdgeInsets.only(bottom: 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.line, width: 1)),
      ),
      // A Wrap, not a Row: a figure that loses its tail reads as a smaller
      // number, so the figures take a second line rather than being cut.
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
                const TextSpan(text: ' cases  ·  '),
                TextSpan(
                  text: formatQty(short),
                  style: AppText.mono(
                    size: 13,
                    weight: FontWeight.w600,
                    color: AppColors.cautionDeep,
                  ),
                ),
                const TextSpan(text: ' short'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A company and market reads as a heading on the canvas, not as another
/// card. Its notes are the cards.
class _GroupSection extends StatelessWidget {
  const _GroupSection({required this.group});

  final DispatchGroup group;

  @override
  Widget build(BuildContext context) {
    final count = group.notes.length;

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
          child: Text.rich(
            TextSpan(
              style: const TextStyle(fontSize: 11.5, color: AppColors.ink500),
              children: [
                TextSpan(
                  text: formatQty(group.cases),
                  style: AppText.mono(
                    size: 11.5,
                    weight: FontWeight.w600,
                    color: AppColors.ink700,
                  ),
                ),
                TextSpan(
                  text: ' cases on $count ${count == 1 ? 'note' : 'notes'}',
                ),
                if (group.short > 0) ...[
                  const TextSpan(text: ' · '),
                  TextSpan(
                    text: formatQty(group.short),
                    style: AppText.mono(
                      size: 11.5,
                      weight: FontWeight.w600,
                      color: AppColors.ink700,
                    ),
                  ),
                  const TextSpan(text: ' short'),
                ],
              ],
            ),
            // Two lines, not one with an ellipsis: a figure that loses its
            // tail reads as a smaller number.
            maxLines: 2,
          ),
        ),
        for (final note in group.notes) _NoteCard(note: note),
        const SizedBox(height: 8),
      ],
    );
  }
}

/// One dispatch note. It opens its own screen rather than unfolding here:
/// its lines belong with the linking work, not on a list of depots.
class _NoteCard extends StatelessWidget {
  const _NoteCard({required this.note});

  final DispatchModel note;

  @override
  Widget build(BuildContext context) {
    final cases = note.totalQuantity;
    final outstanding = (cases - note.issuedQty).clamp(0, cases);
    final done = outstanding <= 0 && cases > 0;
    final notStarted = note.issuedQty <= 0;
    final lines = note.items.length;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.brTile,
        border: Border.all(color: AppColors.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () async {
          await Get.to(() => DispatchDetailScreen(dispatchId: note.id));
          await Get.find<DispatchController>().refreshIfStale();
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 13, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      note.depotName,
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
                  DispatchStatusPill(note.status),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: AppColors.ink400,
                  ),
                ],
              ),

              // What is at the gate: the two things a note is recognised by
              // once the depot is known.
              const SizedBox(height: 2),
              Text(
                note.vehicleNumber.trim().isEmpty
                    ? 'Vehicle not set · $lines ${lines == 1 ? 'line' : 'lines'}'
                    : '${note.vehicleNumber} · $lines '
                          '${lines == 1 ? 'line' : 'lines'}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.micro,
              ),

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
                      // Without this a Row claims the whole width, so each
                      // half would take a line of its own with room to spare.
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

                    // Three states, and a zero is none of them: nothing
                    // linked yet is not the same as nothing left to link.
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
                            'All linked',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.greenDeep,
                            ),
                          ),
                        ],
                      )
                    else if (notStarted)
                      Text(
                        'Not started',
                        style: AppText.micro.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      )
                    else
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            formatQty(outstanding),
                            style: AppText.mono(
                              size: 13,
                              weight: FontWeight.w600,
                              color: AppColors.cautionDeep,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text('short', style: AppText.micro),
                        ],
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 8),
              LinkedProgressBar(
                linked: note.issuedQty,
                required_: cases == 0 ? 1 : cases,
                height: 6,
                accent: done ? AppColors.green : AppColors.caution,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The outstanding figure, as a control. Tapping it narrows the list to the
/// notes still short; tapping it again puts the rest back.
class _ShortButton extends StatelessWidget {
  const _ShortButton({
    required this.short,
    required this.selected,
    required this.onTap,
  });

  final int short;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: selected
          ? 'Showing only the notes still short. Tap to show all.'
          : '${formatQty(short)} cases short. Tap to show only those notes.',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.fromLTRB(9, 3, 9, 3),
          decoration: BoxDecoration(
            color: selected ? AppColors.caution : AppColors.cautionTint,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                formatQty(short),
                style: AppText.mono(
                  size: 12.5,
                  weight: FontWeight.w600,
                  color: selected ? Colors.white : AppColors.cautionDeep,
                ),
              ),
              const SizedBox(width: 4),
              // Flexible, so a long figure or a wide font shortens the word
              // rather than running the button off the edge.
              Flexible(
                child: Text(
                  'short',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: selected ? Colors.white : AppColors.cautionDeep,
                  ),
                ),
              ),
              if (selected) ...[
                const SizedBox(width: 4),
                const Icon(Icons.close_rounded, size: 13, color: Colors.white),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
