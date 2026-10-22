import 'package:flutter/material.dart';

import 'package:eal_scanner/theme/app_tokens.dart';
import 'package:eal_scanner/widgets/ui/chips.dart';
import 'package:eal_scanner/utils/formatting.dart';

/// A span of dates, or one date.
typedef DateSpan = ({DateTime from, DateTime to});

/// Picks a span of dates, or a single day.
///
/// The stock range picker is a full-screen dialog in another visual language,
/// and the stock single picker cannot give a span at all. One month at a time,
/// in the app's own look: tap a day to start, tap another to end, or apply
/// after one tap and that day is the span.
Future<DateSpan?> showDateRangeSheet({
  required BuildContext context,
  required DateTime from,
  required DateTime to,
  DateTime? lastAllowed,
  Color accent = AppColors.blue,
}) {
  return showModalBottomSheet<DateSpan>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _DateRangeSheet(
      from: from,
      to: to,
      lastAllowed: lastAllowed,
      accent: accent,
    ),
  );
}

class _DateRangeSheet extends StatefulWidget {
  const _DateRangeSheet({
    required this.from,
    required this.to,
    required this.accent,
    this.lastAllowed,
  });

  final DateTime from;
  final DateTime to;
  final DateTime? lastAllowed;
  final Color accent;

  @override
  State<_DateRangeSheet> createState() => _DateRangeSheetState();
}

class _DateRangeSheetState extends State<_DateRangeSheet> {
  late DateTime _month;
  late DateTime _start;

  /// Null while only the first day has been tapped. Applying then records
  /// that single day.
  DateTime? _end;

  @override
  void initState() {
    super.initState();
    _start = _day(widget.from);
    _end = _day(widget.to);
    _month = DateTime(_start.year, _start.month);
  }

  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

  DateTime get _resolvedEnd => _end ?? _start;

  /// The named spans, which used to sit on the list itself. With the row
  /// gone from the header, this sheet is the only place dates are chosen,
  /// so the shortcuts come with it.
  List<({String label, DateTime from, DateTime to})> get _presets {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    return [
      (label: 'Today', from: today, to: today),
      (label: 'Yesterday', from: yesterday, to: yesterday),
      (
        label: '7 days',
        from: today.subtract(const Duration(days: 6)),
        to: today,
      ),
      (label: 'This month', from: DateTime(today.year, today.month), to: today),
    ];
  }

  /// A preset fills the calendar in rather than applying on the spot, so
  /// every way of choosing a span commits at the same button.
  void _usePreset(DateTime from, DateTime to) {
    setState(() {
      _start = from;
      _end = to;
      _month = DateTime(to.year, to.month);
    });
  }

  bool get _canGoForward {
    final limit = widget.lastAllowed;
    if (limit == null) return true;
    final next = DateTime(_month.year, _month.month + 1);
    return !next.isAfter(DateTime(limit.year, limit.month));
  }

  void _tap(DateTime date) {
    setState(() {
      // A second tap closes the span; a third starts a new one.
      if (_end != null) {
        _start = date;
        _end = null;
        return;
      }
      if (date.isBefore(_start)) {
        _end = _start;
        _start = date;
      } else {
        _end = date;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final days = _resolvedEnd.difference(_start).inDays + 1;

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
                  const Expanded(child: Text('Dates', style: AppText.title)),
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
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.gutter,
                10,
                AppSpace.gutter,
                0,
              ),
              child: SizedBox(
                height: 34,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: EdgeInsets.zero,
                  children: [
                    for (final preset in _presets) ...[
                      if (preset != _presets.first) const SizedBox(width: 7),
                      FilterPill(
                        label: preset.label,
                        selected:
                            _start == preset.from &&
                            _resolvedEnd == preset.to &&
                            _end != null,
                        accent: widget.accent,
                        onTap: () => _usePreset(preset.from, preset.to),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpace.gutter,
                11,
                AppSpace.gutter,
                0,
              ),
              child: Text(
                'Or tap a day, then the last day. One day on its own is fine.',
                style: AppText.small,
              ),
            ),

            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpace.gutter,
                  AppSpace.md,
                  AppSpace.gutter,
                  0,
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        _MonthStep(
                          icon: Icons.chevron_left_rounded,
                          tooltip: 'Previous month',
                          onPressed: () => setState(
                            () => _month = DateTime(
                              _month.year,
                              _month.month - 1,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            formatMonthYear(_month),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        _MonthStep(
                          icon: Icons.chevron_right_rounded,
                          tooltip: 'Next month',
                          onPressed: _canGoForward
                              ? () => setState(
                                  () => _month = DateTime(
                                    _month.year,
                                    _month.month + 1,
                                  ),
                                )
                              : null,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    _MonthGrid(
                      month: _month,
                      start: _start,
                      end: _resolvedEnd,
                      closed: _end != null,
                      lastAllowed: widget.lastAllowed,
                      accent: widget.accent,
                      onTap: _tap,
                    ),
                  ],
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.gutter,
                AppSpace.lg,
                AppSpace.gutter,
                12,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        _start == _resolvedEnd
                            ? formatDayMonthYear(_start)
                            : '${formatDayMonth(_start)} – '
                                  '${formatDayMonthYear(_resolvedEnd)}',
                        style: AppText.mono(size: 15, weight: FontWeight.w600),
                      ),
                      const SizedBox(width: 7),
                      Text(
                        '· ${days == 1 ? '1 day' : '$days days'}',
                        style: AppText.small,
                      ),
                    ],
                  ),
                  const SizedBox(height: 11),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context, (
                      from: _start,
                      to: _resolvedEnd,
                    )),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.accent,
                      minimumSize: const Size.fromHeight(56),
                      textStyle: const TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    child: const Text('Show these dates'),
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

class _MonthStep extends StatelessWidget {
  const _MonthStep({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      icon: Icon(icon, size: 22),
      style: IconButton.styleFrom(
        backgroundColor: AppColors.canvas,
        foregroundColor: AppColors.ink700,
      ),
    );
  }
}

/// One month, Monday first.
class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.month,
    required this.start,
    required this.end,
    required this.closed,
    required this.accent,
    required this.onTap,
    this.lastAllowed,
  });

  final DateTime month;
  final DateTime start;
  final DateTime end;

  /// Whether both ends are set. While open, only the start is marked.
  final bool closed;

  final DateTime? lastAllowed;
  final Color accent;
  final ValueChanged<DateTime> onTap;

  @override
  Widget build(BuildContext context) {
    final first = DateTime(month.year, month.month);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    // DateTime.weekday is 1 for Monday, so this is the blank lead-in.
    final lead = first.weekday - 1;
    final today = DateTime.now();
    final todayDay = DateTime(today.year, today.month, today.day);

    final cells = <Widget>[];
    for (var i = 0; i < lead; i++) {
      cells.add(const Expanded(child: SizedBox(height: 42)));
    }

    final rows = <Widget>[];
    for (var day = 1; day <= daysInMonth; day++) {
      final date = DateTime(month.year, month.month, day);
      final beyond =
          lastAllowed != null &&
          date.isAfter(
            DateTime(lastAllowed!.year, lastAllowed!.month, lastAllowed!.day),
          );

      cells.add(
        Expanded(
          child: _DayCell(
            day: day,
            isStart: date == start,
            isEnd: closed && date == end,
            inside: closed && date.isAfter(start) && date.isBefore(end),
            isToday: date == todayDay,
            disabled: beyond,
            accent: accent,
            onTap: beyond ? null : () => onTap(date),
          ),
        ),
      );

      if (cells.length == 7) {
        rows.add(Row(children: List.of(cells)));
        cells.clear();
      }
    }

    if (cells.isNotEmpty) {
      while (cells.length < 7) {
        cells.add(const Expanded(child: SizedBox(height: 42)));
      }
      rows.add(Row(children: List.of(cells)));
    }

    return Column(
      children: [
        Row(
          children: [
            for (final label in const ['M', 'T', 'W', 'T', 'F', 'S', 'S'])
              Expanded(
                child: SizedBox(
                  height: 26,
                  child: Center(
                    child: Text(
                      label,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink400,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        ...rows,
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.isStart,
    required this.isEnd,
    required this.inside,
    required this.isToday,
    required this.disabled,
    required this.accent,
    required this.onTap,
  });

  final int day;
  final bool isStart;
  final bool isEnd;
  final bool inside;
  final bool isToday;
  final bool disabled;
  final Color accent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final edge = isStart || isEnd;

    return Semantics(
      selected: edge || inside,
      button: !disabled,
      child: SizedBox(
        height: 42,
        child: Padding(
          padding: const EdgeInsets.all(1),
          child: Material(
            color: edge
                ? accent
                : inside
                ? accent.withValues(alpha: 0.12)
                : Colors.transparent,
            shape: inside
                ? const RoundedRectangleBorder()
                : RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                    side: isToday && !edge
                        ? const BorderSide(
                            color: AppColors.lineField,
                            width: 1.5,
                          )
                        : BorderSide.none,
                  ),
            child: InkWell(
              onTap: onTap,
              customBorder: const CircleBorder(),
              child: Center(
                child: Text(
                  '$day',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: edge ? FontWeight.w600 : FontWeight.w500,
                    color: disabled
                        ? AppColors.ink400
                        : edge
                        ? Colors.white
                        : inside
                        ? AppColors.indigoDeep
                        : AppColors.ink700,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
