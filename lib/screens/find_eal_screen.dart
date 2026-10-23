import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import 'package:eal_scanner/controllers/findEalController.dart';
import 'package:eal_scanner/models/eal_trace.dart';
import 'package:eal_scanner/screens/find_eal_book_screen.dart';
import 'package:eal_scanner/screens/scan/scan_target.dart';
import 'package:eal_scanner/screens/scan/scanner_camera.dart';
import 'package:eal_scanner/theme/app_tokens.dart';
import 'package:eal_scanner/utils/formatting.dart';
import 'package:eal_scanner/widgets/ui/feedback.dart';
import 'package:eal_scanner/widgets/ui/serial_text.dart';

/// One label, and everywhere it has been — once it is clear which label.
///
/// Every other screen in the app starts from a module: a date, an item, a
/// note. A label in the hand has none of those. It has a number, and the
/// question asked of it is where it came from and where it went.
///
/// The number alone does not answer it. A serial is unique within a book,
/// not across them, so this screen asks which book: it lists the ones that
/// carry the number, with the pack each is for, and the reading happens on
/// the screen after. Where only one book carries it, that step is skipped.
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

  Future<void> _submit() async {
    _focus.unfocus();
    if (_readError.isNotEmpty) setState(() => _readError = '');
    final only = await _controller.search();

    if (!mounted || only == null) return;

    // One book, so there is nothing to choose: go straight to it.
    _open(only);
  }

  void _open(TraceIssuance book) {
    Get.to(
      () => FindEalBookScreen(
        book: book,
        serial:
            int.tryParse(
              _controller.query.value.replaceAll(RegExp(r'[^0-9]'), ''),
            ) ??
            0,
        prefix: book.prefix,
        otherBooks: _controller.books.length,
      ),
    );
  }

  /// Scanning fills the same field, so the answer comes from one place
  /// however the number was obtained.
  /// What a scanned code could not be read as, said on the page rather
  /// than searched for.
  String _readError = '';

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

    if (!mounted) return;

    // The camera offers typing as a way past a torn label. Here that is
    // the field on this screen, so the cursor goes to it; before, the
    // camera closed and nothing happened at all.
    if (outcome is ScannerAskedToType) {
      _focus.requestFocus();
      return;
    }

    if (outcome is! ScannerCaptured) return;

    final barcodes = outcome.capture.barcodes;
    final raw = barcodes.isEmpty ? '' : (barcodes.first.rawValue ?? '');
    final single = EalQrCodec.readSingle(raw);
    final range = EalQrCodec.readRange(raw);

    if (single == null && range == null) {
      // Searching for whatever the camera happened to read sent a carton
      // barcode to the server, which answered that nothing was issued
      // with that number — telling the operator their label is unknown
      // when the app had simply not read it.
      final excerpt = raw.trim().isEmpty
          ? 'nothing'
          : (raw.length > 28 ? '${raw.trim().substring(0, 28)}…' : raw.trim());

      setState(
        () => _readError =
            'That code does not read as an EAL label: "$excerpt". Check '
            'you are scanning the excise label and not the carton '
            'barcode.',
      );
      return;
    }

    // Prefix and serial together. The number alone does not name a label:
    // the same serial sits in more than one book, and the prefix printed
    // on the one in the hand is what tells them apart — so dropping it
    // made every scan ask a question the label had already answered.
    final serial = single != null ? EalQrCodec.pad(single) : range!.from;
    final prefix = EalQrCodec.prefixOf(raw) ?? '';
    final query = '$prefix$serial';

    setState(() => _readError = '');
    _field.text = query;
    _controller.query.value = query;
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
                                  setState(() => _readError = '');
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
    if (_readError.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.all(AppSpace.gutter),
        child: NoticeBanner(
          title: 'That code was not read',
          message: _readError,
          trailing: TextButton(onPressed: _scan, child: const Text('Scan')),
        ),
      );
    }

    if (_controller.isOffline.value) {
      return OfflineState(what: 'this label', onRetry: _submit);
    }

    if (_controller.errorMessage.value.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.all(AppSpace.gutter),
        child: NoticeBanner(
          level: NoticeLevel.error,
          title: 'That did not work',
          message: _controller.errorMessage.value,
          trailing: TextButton(onPressed: _submit, child: const Text('Retry')),
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

    final books = _controller.books;

    if (books.isEmpty) {
      return const EmptyState(
        icon: Icons.qr_code_2_rounded,
        title: 'Type the number, or scan the label',
        message:
            'The number printed under the code, with or without its three '
            'letters. Any label of the run will do.',
        primaryColor: AppColors.blue,
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.gutter,
        AppSpace.md,
        AppSpace.gutter,
        AppSpace.xxl,
      ),
      children: [
        // A sentence, not a section label: these are set in capitals
        // elsewhere, and "2 BOOKS CARRY THIS NUMBER" reads as shouting.
        Text(
          books.length == 1
              ? 'One book carries this number'
              : '${books.length} books carry this number',
          style: const TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w600,
            color: AppColors.ink900,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          books.length == 1
              ? 'Open it to see where this label has been.'
              : 'A serial is unique within a book, not across them. Pick '
                    'the one in your hand.',
          style: AppText.small,
        ),
        const SizedBox(height: AppSpace.md),
        for (final book in books) ...[
          _BookCard(book: book, onTap: () => _open(book)),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

/// One book that carries the number: enough of it to recognise the one in
/// the hand — the prefix, the pack, when it was issued, and how much of it
/// is left.
class _BookCard extends StatelessWidget {
  const _BookCard({required this.book, required this.onTap});

  final TraceIssuance book;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (book.prefix.isNotEmpty) ...[
                SerialPrefixChip(book.prefix),
                const SizedBox(width: 9),
              ],
              Expanded(
                child: Text(
                  book.packLabel,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink900,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: AppColors.ink400,
              ),
            ],
          ),
          const SizedBox(height: 5),
          SerialRangeText(
            prefix: book.prefix,
            from: book.serialFrom,
            to: book.serialTo,
            size: 11.5,
            showPrefix: false,
            color: AppColors.ink700,
          ),
          const SizedBox(height: 3),
          Text.rich(
            TextSpan(
              style: AppText.micro,
              children: [
                TextSpan(
                  text: book.date == null
                      ? 'Issued'
                      : 'Issued ${formatDayMonthYear(book.date!)}',
                ),
                const TextSpan(text: ' · '),
                TextSpan(
                  text: formatQty(book.balanceQuantity),
                  style: AppText.mono(
                    size: 11,
                    weight: FontWeight.w600,
                    color: AppColors.ink700,
                  ),
                ),
                TextSpan(
                  text: ' of ${formatQty(book.issuedQuantity)} still unused',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
