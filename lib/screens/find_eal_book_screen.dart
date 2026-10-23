import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:eal_scanner/controllers/findEalController.dart';
import 'package:eal_scanner/models/eal_trace.dart';
import 'package:eal_scanner/theme/app_tokens.dart';
import 'package:eal_scanner/utils/formatting.dart';
import 'package:eal_scanner/widgets/ui/chips.dart';
import 'package:eal_scanner/widgets/ui/feedback.dart';
import 'package:eal_scanner/widgets/ui/serial_text.dart';

/// One label, read within one book.
///
/// Everything on this screen comes from the book named at the top: the
/// server is asked again with that pack, so the issuance, the runs and the
/// dispatch links all belong together. Nothing here has to be weighed
/// against a record from another book.
class FindEalBookScreen extends StatefulWidget {
  const FindEalBookScreen({
    super.key,
    required this.book,
    required this.serial,
    required this.prefix,
    required this.otherBooks,
  });

  final TraceIssuance book;
  final int serial;
  final String prefix;

  /// How many books carry the number in all, so the bar can say whether
  /// there is another one to go back to.
  final int otherBooks;

  @override
  State<FindEalBookScreen> createState() => _FindEalBookScreenState();
}

class _FindEalBookScreenState extends State<FindEalBookScreen> {
  final FindEalController _controller = Get.find<FindEalController>();
  EalTrace? _trace;
  bool _loading = true;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = '';
    });

    final outcome = await _controller.trace(widget.book);

    if (!mounted) return;
    setState(() {
      _trace = outcome.trace;
      _loading = false;
      _error = outcome.error;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SerialRangeText(
              prefix: widget.prefix,
              from: widget.serial,
              to: widget.serial,
              size: 15,
              showPrefix: false,
            ),
            Text(
              widget.prefix.isEmpty
                  ? widget.book.packLabel
                  : '${widget.prefix} · ${widget.book.packLabel}',
              style: AppText.micro,
            ),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error.isNotEmpty
          ? Padding(
              padding: const EdgeInsets.all(AppSpace.gutter),
              child: NoticeBanner(
                level: NoticeLevel.error,
                title: 'That did not work',
                message: _error,
                trailing: TextButton(
                  onPressed: _load,
                  child: const Text('Retry'),
                ),
              ),
            )
          : _trace == null
          ? const EmptyState(
              icon: Icons.search_off_rounded,
              title: 'Nothing against this label in this book',
              primaryColor: AppColors.blue,
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.gutter,
                AppSpace.lg,
                AppSpace.gutter,
                AppSpace.xxl,
              ),
              children: [
                // Which book is being read, and the way back to the other
                // one. Named rather than assumed, because the number alone
                // did not name it.
                if (widget.otherBooks > 1)
                  _BookBar(
                    book: widget.book,
                    total: widget.otherBooks,
                    onChange: () => Navigator.pop(context),
                  ),
                if (widget.otherBooks > 1) const SizedBox(height: AppSpace.lg),

                _Trace(trace: _trace!, book: widget.book),
              ],
            ),
    );
  }
}

/// The book this reading comes from, with the way back to the others.
class _BookBar extends StatelessWidget {
  const _BookBar({
    required this.book,
    required this.total,
    required this.onChange,
  });

  final TraceIssuance book;
  final int total;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.blueTint,
      borderRadius: AppRadius.brControl,
      child: InkWell(
        onTap: onChange,
        borderRadius: AppRadius.brControl,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(13, 11, 13, 11),
          child: Row(
            children: [
              const Icon(
                Icons.assignment_turned_in_outlined,
                size: 17,
                color: AppColors.blue,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppColors.ink700,
                    ),
                    children: [
                      const TextSpan(text: 'Reading the '),
                      TextSpan(
                        text: book.packName,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      TextSpan(text: ' book. $total carry this number.'),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Change',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.blue,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The answer: the three stages a label passes through, in order.
class _Trace extends StatelessWidget {
  const _Trace({required this.trace, required this.book});

  final EalTrace trace;

  /// The book chosen on the screen before. Its figures are drawn from the
  /// record the server returned for it, which may be richer than the one
  /// the chooser was built from.
  final TraceIssuance book;

  @override
  Widget build(BuildContext context) {
    final issuance = trace.issuances.isEmpty ? book : trace.issuances.first;

    return ListView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      children: [
        // What the label is. The pack is in the app bar, because the
        // reading belongs to that book.
        Row(
          children: [
            Expanded(child: Text(issuance.companyName, style: AppText.small)),
            if (issuance.market.isNotEmpty) MarketChip(issuance.market),
          ],
        ),
        const SizedBox(height: AppSpace.lg),

        const SectionHeading('This label'),
        const SizedBox(height: 9),

        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              _Stage(
                icon: Icons.assignment_turned_in_outlined,
                tint: AppColors.indigoTint,
                accent: AppColors.indigo,
                title: 'Issued',
                date: issuance.date,
                enteredBy: issuance.enteredBy,
                enteredAt: issuance.enteredAt,
                lines: [
                  // The figures belong to the book, not to the label, so
                  // the sentence names what it counts.
                  '${formatLabels(issuance.issuedQuantity)} in this book · '
                      '${formatQty(issuance.balanceQuantity)} of them still '
                      'unused',
                ],
                range: (from: issuance.serialFrom, to: issuance.serialTo),
                prefix: trace.prefix,
                isLast: false,
              ),

              if (trace.wasUsed)
                for (final run in trace.runs)
                  _Stage(
                    icon: Icons.factory_outlined,
                    tint: AppColors.tealTint,
                    accent: AppColors.teal,
                    title: 'Applied',
                    date: run.date,
                    enteredBy: run.enteredBy,
                    enteredAt: run.enteredAt,
                    lines: [
                      run.itemName,
                      '${formatCases(run.cases)} on this run'
                          '${run.waitingCases > 0 ? ' · ${formatQty(run.waitingCases)} still waiting' : ''}',
                    ],
                    range: (from: run.serialFrom, to: run.serialTo),
                    prefix: trace.prefix,
                    isLast: false,
                  )
              else
                const _StageNotYet(
                  icon: Icons.factory_outlined,
                  title: 'Not applied yet',
                  message: 'No production run has used this label.',
                  isLast: false,
                ),

              if (trace.wasDispatched)
                for (var i = 0; i < trace.dispatches.length; i++)
                  _Stage(
                    icon: Icons.local_shipping_outlined,
                    tint: AppColors.amberTint,
                    accent: AppColors.amber,
                    title: 'Dispatched',
                    date: trace.dispatches[i].date,
                    enteredBy: trace.dispatches[i].enteredBy,
                    enteredAt: trace.dispatches[i].enteredAt,
                    enteredVerb: 'linked',
                    // Where the note has got to. Linked is not the same as
                    // gone: a label on a note still at Final has not left
                    // the plant.
                    badge: trace.dispatches[i].status.isEmpty
                        ? null
                        : DispatchStatusPill(trace.dispatches[i].status),
                    lines: [
                      if (trace.dispatches[i].depotName.isNotEmpty)
                        trace.dispatches[i].depotName,
                      '${formatCases(trace.dispatches[i].cases)} linked',
                    ],
                    range: (
                      from: trace.dispatches[i].serialFrom,
                      to: trace.dispatches[i].serialTo,
                    ),
                    prefix: trace.prefix,
                    isLast: i == trace.dispatches.length - 1,
                  )
              else
                const _StageNotYet(
                  icon: Icons.local_shipping_outlined,
                  title: 'Not dispatched yet',
                  message: 'Still in finished stock.',
                  isLast: true,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A stage that happened, with the range it covers.
///
/// Two dates sit on one row and they are not the same thing. The record's
/// own date — the day the labels were issued, applied or sent — belongs to
/// the stage, so it is on the title line. The moment someone typed it into
/// the app is a footnote under a hairline, with their name. Where the two
/// differ, the footnote carries its date as well: a run typed up the next
/// morning is worth seeing.
class _Stage extends StatelessWidget {
  const _Stage({
    required this.icon,
    required this.tint,
    required this.accent,
    required this.title,
    required this.date,
    required this.lines,
    required this.range,
    required this.prefix,
    required this.isLast,
    required this.enteredBy,
    required this.enteredAt,
    this.enteredVerb = 'entered',
    this.badge,
  });

  final IconData icon;
  final Color tint;
  final Color accent;
  final String title;
  final DateTime? date;
  final List<String> lines;
  final ({int from, int to})? range;
  final String prefix;
  final bool isLast;
  final String enteredBy;
  final DateTime? enteredAt;

  /// "entered" for a record someone keyed in, "linked" for labels put
  /// against a dispatch line.
  final String enteredVerb;

  /// Sits above the detail lines, for a stage that has a state of its own.
  final Widget? badge;

  String get _entry {
    if (enteredAt == null) return enteredBy;

    final sameDay =
        date != null &&
        date!.year == enteredAt!.year &&
        date!.month == enteredAt!.month &&
        date!.day == enteredAt!.day;

    final when = sameDay
        ? formatClock(enteredAt!)
        : '${formatDayMonth(enteredAt!)}, ${formatClock(enteredAt!)}';

    return enteredBy.isEmpty
        ? '$enteredVerb $when'
        : '$enteredBy · $enteredVerb $when';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 12),
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
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: tint,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.ink900,
                        ),
                      ),
                    ),
                    if (date != null) ...[
                      const SizedBox(width: 10),
                      Text(
                        formatDayMonthYear(date!),
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          color: AppColors.ink500,
                        ),
                      ),
                    ],
                  ],
                ),
                if (range != null) ...[
                  const SizedBox(height: 3),
                  SerialRangeText(
                    prefix: prefix,
                    from: range!.from,
                    to: range!.to,
                    size: 11.5,
                    showPrefix: false,
                    color: AppColors.ink700,
                  ),
                ],
                if (badge != null) ...[const SizedBox(height: 6), badge!],
                for (final line in lines)
                  if (line.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(line, style: AppText.micro),
                  ],

                // The footnote: smaller, paler, and set apart, because it
                // is about the record rather than about the labels.
                Container(
                  margin: const EdgeInsets.only(top: 7),
                  padding: const EdgeInsets.only(top: 7),
                  decoration: const BoxDecoration(
                    border: Border(
                      top: BorderSide(color: AppColors.lineSoft, width: 1),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.person_outline_rounded,
                        size: 12,
                        color: AppColors.ink400,
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          _entry,
                          style: const TextStyle(
                            fontSize: 10.5,
                            color: AppColors.ink400,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A stage that has not happened. It keeps its row rather than leaving a
/// gap: "not dispatched yet" is the answer as often as a depot name is.
class _StageNotYet extends StatelessWidget {
  const _StageNotYet({
    required this.icon,
    required this.title,
    required this.message,
    required this.isLast,
  });

  final IconData icon;
  final String title;
  final String message;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
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
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppColors.field,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: AppColors.ink400),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(message, style: AppText.micro),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
