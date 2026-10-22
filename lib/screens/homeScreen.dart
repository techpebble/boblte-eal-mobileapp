import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:eal_scanner/branding.dart';
import 'package:eal_scanner/controllers/dashboardController.dart';
import 'package:eal_scanner/models/dashboard.dart';
import 'package:eal_scanner/screens/connectionScreen.dart';
import 'package:eal_scanner/screens/dispatches/dispatchListScreen.dart';
import 'package:eal_scanner/screens/issuance/sticker_details_sheet.dart';
import 'package:eal_scanner/screens/usages/EALStickerScreen.dart'
    as production_entry;
import 'package:eal_scanner/theme/app_tokens.dart';
import 'package:eal_scanner/utils/formatting.dart';
import 'package:eal_scanner/widgets/ui/chips.dart';
import 'package:eal_scanner/widgets/ui/feedback.dart';
import 'package:eal_scanner/widgets/ui/serial_text.dart';

/// Replaces the old dashboard of three navigation cards with a screen that
/// does work: the figures for the day, what needs attention, and the most
/// recent entries. The modules themselves now live in the bottom tabs.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<DashboardController>();

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: Column(
        children: [
          _Header(controller: controller),
          Obx(() {
            if (controller.isRefreshing.value) return const ThinLoadingBar();
            return const SizedBox.shrink();
          }),
          Expanded(
            child: Obx(() {
              if (controller.isOffline.value) {
                return ConnectionLostView(
                  onRetry: () => controller.fetch(),
                  isRetrying: controller.isLoading.value,
                  lastReachedAt: controller.lastUpdated.value == null
                      ? null
                      : controller.lastUpdatedLabel,
                );
              }

              if (controller.isLoading.value && controller.data.value == null) {
                return const _HomeSkeleton();
              }

              return RefreshIndicator(
                color: AppColors.blue,
                onRefresh: () => controller.fetch(background: true),
                child: _HomeBody(controller: controller),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.controller});

  final DashboardController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.navy,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpace.gutter, 14, 12, 16),
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(8),
                ),
                clipBehavior: Clip.antiAlias,
                child: Image.asset(
                  AppBrand.logo,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.qr_code_2_rounded,
                    size: 18,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppBrand.name,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 1),
                    Text(
                      'Excise label control',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: AppColors.onNavyMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Obx(
                () => TextButton.icon(
                  onPressed: controller.isLoading.value
                      ? null
                      : () => controller.fetch(background: true),
                  icon: const Icon(
                    Icons.refresh_rounded,
                    size: 15,
                    color: AppColors.onNavyMuted,
                  ),
                  label: Text(
                    controller.lastUpdatedLabel,
                    style: AppText.mono(
                      size: 12,
                      weight: FontWeight.w600,
                      color: const Color(0xFFE6EEFB),
                    ),
                  ),
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.14),
                    padding: const EdgeInsets.symmetric(horizontal: 11),
                    minimumSize: const Size(0, 36),
                    shape: const RoundedRectangleBorder(
                      borderRadius: AppRadius.brPill,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeBody extends StatelessWidget {
  const _HomeBody({required this.controller});

  final DashboardController controller;

  @override
  Widget build(BuildContext context) {
    final data = controller.data.value ?? DashboardData.empty();
    final error = controller.errorMessage.value;

    return ListView(
      padding: const EdgeInsets.only(bottom: AppSpace.xxl),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.gutter,
            AppSpace.xl,
            AppSpace.gutter,
            0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${formatFullDay(DateTime.now()).toUpperCase()} · ${controller.periodLabel.toUpperCase()}',
                style: AppText.section,
              ),
              const SizedBox(height: 5),
              Text(greetingFor(DateTime.now()), style: AppText.headline),
            ],
          ),
        ),

        if (error.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.gutter,
              AppSpace.lg,
              AppSpace.gutter,
              0,
            ),
            child: NoticeBanner(
              level: NoticeLevel.error,
              title: 'Could not load the overview',
              message: error,
              trailing: TextButton(
                onPressed: () => controller.fetch(),
                child: const Text('Retry'),
              ),
            ),
          ),

        // The action people open the app to perform.
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.gutter,
            AppSpace.xl,
            AppSpace.gutter,
            0,
          ),
          child: _ScanCallToAction(onTap: () => _showScanDestinations(context)),
        ),

        const SizedBox(height: AppSpace.xl),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.gutter),
          child: SectionHeading(controller.periodLabel),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.gutter),
          child: _StatRow(data: data),
        ),

        const SizedBox(height: AppSpace.sm),
        Obx(
          () => FilterPillRow(
            children: [
              for (final p in DashboardPeriod.values)
                FilterPill(
                  label: switch (p) {
                    DashboardPeriod.today => 'Today',
                    DashboardPeriod.week => 'Last 7 days',
                    DashboardPeriod.month => 'This month',
                  },
                  selected: controller.period.value == p,
                  accent: AppColors.navy,
                  onTap: () => controller.setPeriod(p),
                ),
            ],
          ),
        ),

        if (data.awaitingLinking.count > 0) ...[
          const SizedBox(height: AppSpace.lg),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.gutter),
            child: SectionHeading('Needs attention'),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.gutter),
            child: NoticeBanner(
              title: _awaitingTitle(data.awaitingLinking),
              message: _awaitingDepots(data.awaitingLinking),
              onTap: () => Get.to(() => const DispatchListScreen()),
            ),
          ),
        ],

        const SizedBox(height: AppSpace.xl),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.gutter),
          child: SectionHeading(
            'Recent entries',
            trailing: data.recentMovement.isEmpty
                ? null
                : Text(
                    '${data.recentMovement.length}',
                    style: AppText.mono(
                      size: 12,
                      weight: FontWeight.w600,
                      color: AppColors.ink500,
                    ),
                  ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.gutter),
          child: data.recentMovement.isEmpty
              ? AppCard(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    'Nothing recorded in this period yet. Scanned ranges show '
                    'up here as soon as they are saved.',
                    style: AppText.small,
                  ),
                )
              : AppCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      for (
                        var i = 0;
                        i < data.recentMovement.length.clamp(0, 5);
                        i++
                      )
                        _MovementRow(
                          movement: data.recentMovement[i],
                          isLast:
                              i == data.recentMovement.length.clamp(0, 5) - 1,
                        ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  String _awaitingTitle(AwaitingLinking awaiting) {
    final notes = awaiting.count;
    final cases = awaiting.casesOutstanding;
    final noteWord = notes == 1 ? 'dispatch' : 'dispatches';
    if (cases <= 0) return '$notes $noteWord short of labels';
    return '${formatCases(cases)} still need labels';
  }

  String _awaitingDepots(AwaitingLinking awaiting) {
    final names = awaiting.notes
        .map((n) => n.depot)
        .whereType<String>()
        .toList();

    if (names.isEmpty) {
      final noteWord = awaiting.count == 1 ? 'dispatch' : 'dispatches';
      return 'Across ${awaiting.count} $noteWord';
    }
    if (names.length == 1) return names.first;
    if (names.length == 2) return '${names[0]} and ${names[1]}';
    return '${names.take(2).join(', ')} and ${names.length - 2} more';
  }

  void _showScanDestinations(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.gutter,
            0,
            AppSpace.gutter,
            AppSpace.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('What are you scanning?', style: AppText.title),
              const SizedBox(height: 6),
              Text(
                'A range has to attach to something, so pick where it belongs.',
                style: AppText.small,
              ),
              const SizedBox(height: AppSpace.lg),
              _ScanDestination(
                icon: Icons.assignment_turned_in_outlined,
                accent: AppColors.indigo,
                tint: AppColors.indigoTint,
                title: 'Labels received',
                subtitle: 'Record a new issuance from the excise office',
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  showStickerDetailsSheetForNext(context);
                },
              ),
              const SizedBox(height: 10),
              _ScanDestination(
                icon: Icons.factory_outlined,
                accent: AppColors.teal,
                tint: AppColors.tealTint,
                title: 'Production entry',
                subtitle: 'Labels applied to a bottling run',
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  Get.to(() => production_entry.EALStickerScreen());
                },
              ),
              const SizedBox(height: 10),
              _ScanDestination(
                icon: Icons.local_shipping_outlined,
                accent: AppColors.amber,
                tint: AppColors.amberTint,
                title: 'Dispatch link',
                subtitle: 'Attach labels to a dispatch line',
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  Get.to(() => const DispatchListScreen());
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScanCallToAction extends StatelessWidget {
  const _ScanCallToAction({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.blue,
      borderRadius: AppRadius.brCard,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.brCard,
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.xl),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.17),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.qr_code_scanner_rounded,
                  size: 24,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Scan labels',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Link a serial range to a run or dispatch',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.onBlueMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.onBlueMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScanDestination extends StatelessWidget {
  const _ScanDestination({
    required this.icon,
    required this.accent,
    required this.tint,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color accent;
  final Color tint;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: tint,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, size: 21, color: accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppText.cardTitle),
                const SizedBox(height: 2),
                Text(subtitle, style: AppText.small, maxLines: 2),
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
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({required this.data});

  final DashboardData data;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatTile(
            value: formatCompactQty(data.issued.value),
            label: 'Labels\nissued',
            color: AppColors.indigo,
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: _StatTile(
            value: formatCompactQty(data.applied.value),
            label: 'Labels\napplied',
            color: AppColors.teal,
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: _StatTile(
            value: formatCompactQty(data.dispatched.value),
            label: 'Cases\ndispatched',
            color: AppColors.amber,
          ),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.value,
    required this.label,
    required this.color,
  });

  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: AppText.figure(size: 21, color: color)),
          const SizedBox(height: 3),
          Text(label, style: AppText.micro),
        ],
      ),
    );
  }
}

class _MovementRow extends StatelessWidget {
  const _MovementRow({required this.movement, required this.isLast});

  final Movement movement;
  final bool isLast;

  ({Color accent, Color tint, IconData icon}) get _look {
    switch (movement.type) {
      case MovementType.issuance:
        return (
          accent: AppColors.indigo,
          tint: AppColors.indigoTint,
          icon: Icons.assignment_turned_in_outlined,
        );
      case MovementType.usage:
        return (
          accent: AppColors.teal,
          tint: AppColors.tealTint,
          icon: Icons.factory_outlined,
        );
      case MovementType.dispatchLink:
        return (
          accent: AppColors.amber,
          tint: AppColors.amberTint,
          icon: Icons.local_shipping_outlined,
        );
      case MovementType.unknown:
        return (
          accent: AppColors.ink500,
          tint: AppColors.sunken,
          icon: Icons.history_rounded,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final look = _look;
    final cases = movement.cases;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(
                bottom: BorderSide(color: AppColors.lineSoft, width: 1),
              ),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: look.tint,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(look.icon, size: 17, color: look.accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  movement.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink900,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                SerialRangeText(
                  prefix: movement.prefix,
                  from: movement.serialFrom,
                  to: movement.serialTo,
                  size: 11.5,
                  showPrefix: false,
                  color: AppColors.ink700,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formatCompactQty(cases ?? movement.quantity),
                style: AppText.mono(size: 14, weight: FontWeight.w600),
              ),
              Text(
                cases == null ? movement.unit : 'cases',
                style: AppText.mono(size: 10.5, color: AppColors.ink500),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HomeSkeleton extends StatelessWidget {
  const _HomeSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.gutter,
        AppSpace.xl,
        AppSpace.gutter,
        AppSpace.xxl,
      ),
      children: [
        const SkeletonBox(width: 180, height: 11),
        const SizedBox(height: 10),
        const SkeletonBox(width: 150, height: 22),
        const SizedBox(height: AppSpace.xl),
        const SkeletonBox(height: 82, radius: AppRadius.card),
        const SizedBox(height: AppSpace.xl),
        Row(
          children: [
            for (var i = 0; i < 3; i++) ...[
              if (i > 0) const SizedBox(width: 9),
              const Expanded(
                child: SkeletonBox(height: 72, radius: AppRadius.tile),
              ),
            ],
          ],
        ),
        const SizedBox(height: AppSpace.xl),
        const SkeletonBox(width: 120, height: 11),
        const SizedBox(height: 10),
        const SkeletonBox(height: 190, radius: AppRadius.tile),
      ],
    );
  }
}
