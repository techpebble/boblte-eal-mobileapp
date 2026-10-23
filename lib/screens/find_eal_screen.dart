import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import 'package:eal_scanner/controllers/findEalController.dart';
import 'package:eal_scanner/models/eal_trace.dart';
import 'package:eal_scanner/screens/scan/scan_target.dart';
import 'package:eal_scanner/screens/scan/scanner_camera.dart';
import 'package:eal_scanner/theme/app_tokens.dart';
import 'package:eal_scanner/utils/formatting.dart';
import 'package:eal_scanner/widgets/ui/chips.dart';
import 'package:eal_scanner/widgets/ui/feedback.dart';
import 'package:eal_scanner/widgets/ui/serial_text.dart';

/// One label, and everywhere it has been.
///
/// Every other screen in the app starts from a module — a date, an item, a
/// note. A label in the hand has none of those: it has a number, and the
/// question asked of it is where it came from and where it went. That is
/// this screen, and it is why it sits on the home page rather than inside
/// one of the three lists.
class FindEalScreen extends StatefulWidget {
  const FindEalScreen({super.key});

  @override
  State<FindEalScreen> createState() => _FindEalScreenState();
}

class _FindEalScreenState extends State<FindEalScreen> {
  final FindEalController _controller = Get.put(FindEalController());
  final TextEditingController _field = TextEditingController();
  final FocusNode _focus = FocusNode();

  @override
  void dispose() {
    _field.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _submit() {
    _focus.unfocus();
    _controller.search();
  }

  /// Scanning fills the same field, so the answer comes from one place
  /// however the number was obtained.
  Future<void> _scan() async {
    final outcome = await Navigator.push<ScannerOutcome>(
      context,
      MaterialPageRoute(
        builder: (_) => const ScannerCamera(
          stepLabel: 'Scan the label',
          instruction:
              'Any label of the run. Hold the code inside the frame and '
              'it reads on its own.',
          accent: AppColors.blue,
        ),
      ),
    );

    if (!mounted || outcome is! ScannerCaptured) return;

    final raw = outcome.capture.barcodes.first.rawValue ?? '';
    final single = EalQrCodec.readSingle(raw);
    final range = EalQrCodec.readRange(raw);

    final serial = single != null
        ? EalQrCodec.pad(single)
        : (range?.from ?? raw.trim());

    if (serial.isEmpty) return;

    _field.text = serial;
    _controller.query.value = serial;
    _submit();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Find EAL', style: AppText.appBarTitle),
            Text('One label, and everywhere it has been', style: AppText.micro),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.gutter,
              AppSpace.lg,
              AppSpace.gutter,
              AppSpace.md,
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _field,
                    focusNode: _focus,
                    autofocus: true,
                    textInputAction: TextInputAction.search,
                    textCapitalization: TextCapitalization.characters,
                    style: AppText.mono(size: 16, weight: FontWeight.w600),
                    inputFormatters: [
                      TextInputFormatter.withFunction(
                        (_, next) =>
                            next.copyWith(text: next.text.toUpperCase()),
                      ),
                    ],
                    onChanged: (value) => _controller.query.value = value,
                    onSubmitted: (_) => _submit(),
                    decoration: InputDecoration(
                      hintText: 'AAA0000002401',
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        size: 20,
                        color: AppColors.ink500,
                      ),
                      suffixIcon: Obx(
                        () => _controller.query.value.isEmpty
                            ? const SizedBox.shrink()
                            : IconButton(
                                tooltip: 'Clear',
                                onPressed: () {
                                  _field.clear();
                                  _controller.clear();
                                  _focus.requestFocus();
                                },
                                icon: const Icon(
                                  Icons.close_rounded,
                                  size: 19,
                                  color: AppColors.ink500,
                                ),
                              ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 52,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _scan,
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(52, 52),
                    ),
                    child: const Icon(Icons.qr_code_scanner_rounded, size: 22),
                  ),
                ),
              ],
            ),
          ),

          Obx(() {
            if (_controller.isLoading.value) {
              return const ThinLoadingBar();
            }
            return const SizedBox(height: 2);
          }),

          Expanded(child: Obx(_result)),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.line, width: 1)),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.gutter,
              12,
              AppSpace.gutter,
              12,
            ),
            child: Obx(
              () => ElevatedButton(
                onPressed: _controller.canSearch && !_controller.isLoading.value
                    ? _submit
                    : null,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
                child: const Text('Find this label'),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _result() {
    if (_controller.isOffline.value) {
      return OfflineState(what: 'this label', onRetry: _controller.search);
    }

    if (_controller.errorMessage.value.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.all(AppSpace.gutter),
        child: NoticeBanner(
          level: NoticeLevel.error,
          title: 'That did not work',
          message: _controller.errorMessage.value,
          trailing: TextButton(
            onPressed: _controller.search,
            child: const Text('Retry'),
          ),
        ),
      );
    }

    if (_controller.notFound.value) {
      return const EmptyState(
        icon: Icons.search_off_rounded,
        title: 'Nothing issued with this number',
        message:
            'Check the digits, or the label may belong to another company '
            'this account cannot see.',
        primaryColor: AppColors.blue,
      );
    }

    final trace = _controller.result.value;

    if (trace == null) {
      return const EmptyState(
        icon: Icons.qr_code_2_rounded,
        title: 'Type the number, or scan the label',
        message:
            'The number printed under the code, with or without its three '
            'letters. Any label of the run will do.',
        primaryColor: AppColors.blue,
      );
    }

    return _Trace(trace: trace);
  }
}

/// The answer: the three stages a label passes through, in order.
class _Trace extends StatelessWidget {
  const _Trace({required this.trace});

  final EalTrace trace;

  @override
  Widget build(BuildContext context) {
    final issuance = trace.issuances.isEmpty ? null : trace.issuances.first;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.gutter,
        AppSpace.md,
        AppSpace.gutter,
        AppSpace.xxl,
      ),
      children: [
        // What the label is, before where it has been.
        if (issuance != null) ...[
          Row(
            children: [
              Expanded(
                child: SerialRangeText(
                  prefix: trace.prefix,
                  from: trace.serial,
                  to: trace.serial,
                  size: 15,
                ),
              ),
              if (issuance.market.isNotEmpty) MarketChip(issuance.market),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${issuance.companyName} · ${issuance.packName}'
            '${issuance.bottlesPerCase > 0 ? ' · ${issuance.bottlesPerCase} per case' : ''}',
            style: AppText.small,
          ),
          const SizedBox(height: AppSpace.lg),
        ],

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
                date: issuance?.date,
                lines: [
                  if (issuance != null)
                    '${formatLabels(issuance.issuedQuantity)} issued · '
                        '${formatLabels(issuance.balanceQuantity)} unused',
                ],
                range: issuance == null
                    ? null
                    : (from: issuance.serialFrom, to: issuance.serialTo),
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
                    lines: [
                      if (trace.dispatches[i].depotName.isNotEmpty)
                        trace.dispatches[i].depotName,
                      '${formatCases(trace.dispatches[i].cases)} linked'
                          '${trace.dispatches[i].status.isNotEmpty ? ' · note is ${titleCase(trace.dispatches[i].status)}' : ''}',
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
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: title,
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.ink900,
                        ),
                      ),
                      if (date != null)
                        TextSpan(
                          text: ' · ${formatDayMonthYear(date!)}',
                          style: AppText.small,
                        ),
                    ],
                  ),
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
                for (final line in lines)
                  if (line.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(line, style: AppText.micro),
                  ],
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
