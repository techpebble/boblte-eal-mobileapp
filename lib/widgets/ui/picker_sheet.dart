import 'package:flutter/material.dart';

import 'package:eal_scanner/theme/app_tokens.dart';
import 'package:eal_scanner/widgets/ui/chips.dart';

/// One row of a picker.
class PickerOption<T> {
  const PickerOption({
    required this.value,
    required this.label,
    this.chips = const [],
    this.subtitle,
    this.searchText,
  });

  final T value;
  final String label;

  /// Extra text to match on without showing it. Items are listed by their
  /// short alias, but typing any part of the full name still finds them.
  final String? searchText;

  /// Short metadata shown beneath the label — item code, pack, market.
  final List<String> chips;
  final String? subtitle;

  /// Inactive options are listed but cannot be chosen, so an operator can see
  /// that a discontinued item exists rather than wondering why it is missing.

  String get _haystack => [
    label,
    subtitle ?? '',
    searchText ?? '',
    ...chips,
  ].join(' ').toLowerCase();
}

/// A searchable selection sheet.
///
/// Replaces the bare `ListTile(title: Text(item.name))` list the production
/// screen used: codes, pack sizes and markets are all visible, so two items
/// with similar names can be told apart.
Future<T?> showPickerSheet<T>({
  required BuildContext context,
  required String title,
  required List<PickerOption<T>> options,
  String searchHint = 'Search',
  String? subtitle,
  T? selected,
  Color accent = AppColors.blue,
  List<T> recentValues = const [],
  String recentLabel = 'Used today',
  String? emptyMessage,
  String? errorMessage,
  VoidCallback? onRetry,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _PickerSheet<T>(
      title: title,
      subtitle: subtitle,
      options: options,
      searchHint: searchHint,
      selected: selected,
      accent: accent,
      recentValues: recentValues,
      recentLabel: recentLabel,
      emptyMessage: emptyMessage,
      errorMessage: errorMessage,
      onRetry: onRetry,
    ),
  );
}

class _PickerSheet<T> extends StatefulWidget {
  const _PickerSheet({
    required this.title,
    required this.options,
    required this.searchHint,
    required this.accent,
    required this.recentValues,
    required this.recentLabel,
    this.subtitle,
    this.selected,
    this.emptyMessage,
    this.errorMessage,
    this.onRetry,
  });

  final String title;
  final String? subtitle;
  final List<PickerOption<T>> options;
  final String searchHint;
  final T? selected;
  final Color accent;
  final List<T> recentValues;
  final String recentLabel;
  final String? emptyMessage;

  /// Why the list could not be read, where it could not be. A list that
  /// failed is not an empty list: saying "nothing to choose" sends someone
  /// looking for records that are there and that they were refused.
  final String? errorMessage;
  final VoidCallback? onRetry;

  @override
  State<_PickerSheet<T>> createState() => _PickerSheetState<T>();
}

class _PickerSheetState<T> extends State<_PickerSheet<T>> {
  String _query = '';

  List<PickerOption<T>> get _visible {
    final q = _query.trim().toLowerCase();

    return widget.options.where((o) {
      if (q.isEmpty) return true;
      return o._haystack.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visible;

    // A list that could not be read is not a list with nothing in it.
    final failed =
        widget.errorMessage != null &&
        widget.errorMessage!.isNotEmpty &&
        widget.options.isEmpty;
    final recent = visible
        .where((o) => widget.recentValues.contains(o.value))
        .toList();
    final rest = visible
        .where((o) => !widget.recentValues.contains(o.value))
        .toList();

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.86,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.gutter,
                0,
                AppSpace.gutter,
                0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(widget.title, style: AppText.title)),
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
                  if (widget.subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(widget.subtitle!, style: AppText.small),
                  ],
                  const SizedBox(height: AppSpace.md),
                  TextField(
                    autofocus: widget.options.length > 8,
                    onChanged: (v) => setState(() => _query = v),
                    style: const TextStyle(fontSize: 15.5),
                    decoration: InputDecoration(
                      hintText: widget.searchHint,
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        size: 19,
                        color: AppColors.ink500,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 13,
                      ),
                    ),
                  ),
                  const SizedBox(height: 11),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${visible.length} of ${widget.options.length} '
                          '${widget.options.length == 1 ? 'option' : 'options'}',
                          style: AppText.small,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            Flexible(
              child: visible.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(AppSpace.xxl),
                      child: Column(
                        children: [
                          Icon(
                            failed
                                ? Icons.lock_outline_rounded
                                : Icons.search_off_rounded,
                            size: 32,
                            color: failed
                                ? AppColors.cautionDeep
                                : AppColors.ink400,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            failed
                                ? widget.errorMessage!
                                : _query.isEmpty
                                ? (widget.emptyMessage ?? 'Nothing to choose')
                                : 'Nothing matches “${_query.trim()}”',
                            textAlign: TextAlign.center,
                            style: AppText.bodyMuted,
                          ),
                          if (failed && widget.onRetry != null) ...[
                            const SizedBox(height: AppSpace.md),
                            OutlinedButton(
                              onPressed: () {
                                Navigator.pop(context);
                                widget.onRetry!();
                              },
                              child: const Text('Try again'),
                            ),
                          ],
                        ],
                      ),
                    )
                  : ListView(
                      padding: EdgeInsets.zero,
                      children: [
                        if (recent.isNotEmpty) ...[
                          _GroupLabel(widget.recentLabel),
                          for (final o in recent)
                            _OptionRow<T>(
                              option: o,
                              accent: widget.accent,
                              isSelected: o.value == widget.selected,
                              highlight: true,
                            ),
                          if (rest.isNotEmpty) _GroupLabel('All options'),
                        ],
                        for (final o in rest)
                          _OptionRow<T>(
                            option: o,
                            accent: widget.accent,
                            isSelected: o.value == widget.selected,
                          ),
                        const SizedBox(height: AppSpace.lg),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.field,
      padding: const EdgeInsets.fromLTRB(
        AppSpace.gutter,
        14,
        AppSpace.gutter,
        7,
      ),
      child: Text(text.toUpperCase(), style: AppText.section),
    );
  }
}

class _OptionRow<T> extends StatelessWidget {
  const _OptionRow({
    required this.option,
    required this.accent,
    required this.isSelected,
    this.highlight = false,
  });

  final PickerOption<T> option;
  final Color accent;
  final bool isSelected;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.pop(context, option.value),
      child: Container(
        constraints: const BoxConstraints(minHeight: 62),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.gutter,
          vertical: 12,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? accent.withValues(alpha: 0.08)
              : (highlight ? AppColors.field : null),
          border: const Border(
            bottom: BorderSide(color: AppColors.lineSoft, width: 1),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    option.label,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink900,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (option.subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      option.subtitle!,
                      style: AppText.small,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (option.chips.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [for (final c in option.chips) MetaChip(c)],
                    ),
                  ],
                ],
              ),
            ),
            if (isSelected) Icon(Icons.check_rounded, size: 20, color: accent),
          ],
        ),
      ),
    );
  }
}

/// A labelled row that opens a picker — the form control the entry screens
/// are built from.
class PickerField extends StatelessWidget {
  const PickerField({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
    this.placeholder = 'Choose',
    this.isLast = false,
  });

  final String label;
  final String? value;
  final IconData icon;
  final VoidCallback onTap;
  final String placeholder;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final chosen = value != null && value!.isNotEmpty;

    return InkWell(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 58),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          border: isLast
              ? null
              : const Border(
                  bottom: BorderSide(color: AppColors.lineSoft, width: 1),
                ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 19, color: AppColors.ink500),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: AppText.micro),
                  const SizedBox(height: 1),
                  Text(
                    chosen ? value! : placeholder,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: chosen ? AppColors.ink900 : AppColors.ink500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: AppColors.ink400,
            ),
          ],
        ),
      ),
    );
  }
}
