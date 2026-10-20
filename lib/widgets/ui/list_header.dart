import 'package:flutter/material.dart';

import 'package:eal_scanner/theme/app_tokens.dart';
import 'package:eal_scanner/widgets/ui/feedback.dart';

/// The header every module list shares: title, record count, a search field
/// and a visible date button.
///
/// The old screens put the date behind a bare `Icons.date_range` in the app
/// bar and showed the selected day only on the dispatch list, so two
/// identical-looking screens could be showing different days.
class ListScreenHeader extends StatelessWidget {
  const ListScreenHeader({
    super.key,
    required this.title,
    required this.searchHint,
    required this.onSearchChanged,
    required this.dateLabel,
    required this.onPickDate,
    this.countLabel,
    this.accent = AppColors.blue,
    this.showProgress = false,
  });

  final String title;
  final String searchHint;
  final ValueChanged<String> onSearchChanged;
  final String dateLabel;
  final VoidCallback onPickDate;
  final String? countLabel;
  final Color accent;

  /// A refresh over existing content: a 3px strip, not a modal barrier.
  final bool showProgress;

  @override
  Widget build(BuildContext context) {
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
                13,
                AppSpace.gutter,
                12,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Both are flexible: a long title, or a large system
                      // font, must shorten rather than overflow the row.
                      Flexible(
                        child: Text(
                          title,
                          style: AppText.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 9),
                      if (countLabel != null)
                        Flexible(
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: Text(
                              countLabel!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.mono(
                                size: 13,
                                color: AppColors.ink500,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 44,
                          child: TextField(
                            onChanged: onSearchChanged,
                            textInputAction: TextInputAction.search,
                            style: const TextStyle(fontSize: 14.5),
                            decoration: InputDecoration(
                              isDense: true,
                              hintText: searchHint,
                              fillColor: AppColors.field,
                              prefixIcon: const Icon(
                                Icons.search_rounded,
                                size: 19,
                                color: AppColors.ink500,
                              ),
                              prefixIconConstraints: const BoxConstraints(
                                minWidth: 38,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 11,
                              ),
                              enabledBorder: const OutlineInputBorder(
                                borderRadius: BorderRadius.all(
                                  Radius.circular(11),
                                ),
                                borderSide: BorderSide(
                                  color: AppColors.lineField,
                                  width: 1.5,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 9),
                      OutlinedButton.icon(
                        onPressed: onPickDate,
                        icon: const Icon(Icons.calendar_today_rounded, size: 16),
                        label: Text(dateLabel),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 44),
                          padding: const EdgeInsets.symmetric(horizontal: 13),
                          side: const BorderSide(
                            color: AppColors.lineField,
                            width: 1.5,
                          ),
                          textStyle: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.all(Radius.circular(11)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (showProgress) ThinLoadingBar(color: accent),
          ],
        ),
      ),
    );
  }
}
