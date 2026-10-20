import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:eal_scanner/controllers/usageController.dart';
import 'package:eal_scanner/models/usage.dart';
import 'package:eal_scanner/screens/usages/EALStickerScreen.dart';
import 'package:eal_scanner/screens/usages/usageDetailScreen.dart';
import 'package:eal_scanner/theme/app_tokens.dart';
import 'package:eal_scanner/utils/formatting.dart';
import 'package:eal_scanner/widgets/ui/chips.dart';
import 'package:eal_scanner/widgets/ui/feedback.dart';
import 'package:eal_scanner/widgets/ui/list_header.dart';
import 'package:eal_scanner/widgets/ui/serial_text.dart';

/// Labels applied to bottling runs. Figures lead with cases, which is what
/// the floor counts in, with the label count alongside.
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: Column(
        children: [
          Obx(
            () => ListScreenHeader(
              title: 'Production',
              countLabel: _controller.isLoading.value
                  ? null
                  : '${_controller.ealUsages.length} '
                      '${_controller.ealUsages.length == 1 ? 'entry' : 'entries'}',
              searchHint: 'Item, pack or company',
              onSearchChanged: (v) => _controller.searchQuery.value = v,
              dateLabel: formatDayMonth(_controller.selectedDate.value),
              onPickDate: _controller.pickDate,
              accent: AppColors.teal,
              showProgress:
                  _controller.isLoading.value && _controller.ealUsages.isNotEmpty,
            ),
          ),

          Obx(() => _FilterRow(controller: _controller)),

          Obx(() {
            if (_controller.ealUsages.isEmpty) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.gutter,
                AppSpace.md,
                AppSpace.gutter,
                0,
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: const BoxDecoration(
                  color: AppColors.tealTint,
                  borderRadius: AppRadius.brControl,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            formatQty(_controller.totalCases),
                            style: AppText.figure(
                              size: 20,
                              color: AppColors.tealDeep,
                            ),
                          ),
                          const Text(
                            'cases entered',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.tealDeep,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          formatQty(_controller.totalLabels),
                          style: AppText.figure(
                            size: 20,
                            color: AppColors.tealDeep,
                          ),
                        ),
                        const Text(
                          'labels consumed',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.tealDeep,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),

          Expanded(child: Obx(_buildBody)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Get.to(() => EALStickerScreen()),
        backgroundColor: AppColors.teal,
        foregroundColor: Colors.white,
        elevation: 2,
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'New entry',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildBody() {
    final error = _controller.errorMessage.value;

    if (_controller.isLoading.value && _controller.ealUsages.isEmpty) {
      return const SkeletonList();
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

    final rows = _controller.filteredUsages;

    if (rows.isEmpty) {
      if (_controller.searchQuery.value.trim().isNotEmpty) {
        return EmptyState(
          icon: Icons.search_off_rounded,
          title: 'Nothing matches “${_controller.searchQuery.value.trim()}”',
          message: 'Try an item code, a pack size, or part of the item name.',
          accent: AppColors.teal,
          tint: AppColors.tealTint,
        );
      }

      return EmptyState(
        icon: Icons.precision_manufacturing_outlined,
        title: 'No production on '
            '${formatDayMonthYear(_controller.selectedDate.value)}',
        message: 'Widen the range to the last seven days, or record the run '
            'that has just finished.',
        accent: AppColors.teal,
        tint: AppColors.tealTint,
        primaryLabel: 'Show the last 7 days',
        onPrimary: () =>
            _controller.setRange(endDate: DateTime.now(), days: 7),
        secondaryLabel: 'Record production',
        onSecondary: () => Get.to(() => EALStickerScreen()),
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
        itemCount: rows.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) => _UsageCard(usage: rows[i]),
      ),
    );
  }
}

class _FilterRow extends StatelessWidget {
  const _FilterRow({required this.controller});

  final UsageController controller;

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final selected = controller.selectedDate.value;
    final days = controller.rangeDays.value;

    final isToday = days == 1 && _isSameDay(selected, now);
    final isYesterday = days == 1 &&
        _isSameDay(selected, now.subtract(const Duration(days: 1)));
    final isWeek = days == 7;

    return Padding(
      padding: const EdgeInsets.only(top: AppSpace.md),
      child: FilterPillRow(
        children: [
          FilterPill(
            label: 'Today',
            selected: isToday,
            accent: AppColors.teal,
            onTap: () => controller.setRange(endDate: DateTime.now()),
          ),
          FilterPill(
            label: 'Yesterday',
            selected: isYesterday,
            accent: AppColors.teal,
            onTap: () => controller.setRange(
              endDate: DateTime.now().subtract(const Duration(days: 1)),
            ),
          ),
          FilterPill(
            label: 'Last 7 days',
            selected: isWeek,
            accent: AppColors.teal,
            onTap: () => controller.setRange(endDate: DateTime.now(), days: 7),
          ),
          if (!isToday && !isYesterday && !isWeek)
            FilterPill(
              label: formatDayMonth(selected),
              selected: true,
              accent: AppColors.teal,
              onTap: controller.pickDate,
            ),
        ],
      ),
    );
  }
}

class _UsageCard extends StatelessWidget {
  const _UsageCard({required this.usage});

  final UsageModel usage;

  int get _from => int.tryParse(usage.serialFrom) ?? 0;
  int get _to => int.tryParse(usage.serialTo) ?? 0;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: () => Get.to(() => EALUsageDetailScreen(usage: usage)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  usage.itemName,
                  style: AppText.cardTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    MetaChip(
                      usage.packName,
                      background: AppColors.tealTint,
                      foreground: AppColors.tealDeep,
                    ),
                    MarketChip(usage.market, dense: true),
                  ],
                ),
                const SizedBox(height: 9),
                SerialRangeText(
                  prefix: usage.prefix,
                  from: _from,
                  to: _to,
                  size: 13,
                  color: AppColors.ink700,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formatQty(usage.usedQuantityInCases),
                style: AppText.figure(size: 19),
              ),
              const Text(
                'cases',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                formatClock(usage.dateUsed),
                style: const TextStyle(fontSize: 11, color: AppColors.ink500),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
