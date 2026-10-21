import 'package:flutter/material.dart';

import 'package:eal_scanner/theme/app_tokens.dart';

/// The standard white card used across every screen. Replaces the old
/// `elevation: 6` tinted cards, which stacked heavy shadows on tinted fills.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.borderColor = AppColors.line,
    this.borderWidth = 1,
    this.background = AppColors.surface,
    this.radius = AppRadius.tile,
    this.onTap,
  });

  final Widget child;
  final EdgeInsets padding;
  final Color borderColor;
  final double borderWidth;
  final Color background;
  final double radius;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final decorated = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor, width: borderWidth),
      ),
      child: child,
    );

    if (onTap == null) return decorated;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(radius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: decorated,
      ),
    );
  }
}

/// Severity of an inline message. Colour is never the only carrier: each
/// level brings its own icon and the copy states the fact in words.
enum NoticeLevel { caution, success, info, error }

class NoticeBanner extends StatelessWidget {
  const NoticeBanner({
    super.key,
    this.title,
    this.message,
    this.level = NoticeLevel.caution,
    this.trailing,
    this.onTap,
  });

  /// Omitted where the note is a single sentence that needs no heading.
  final String? title;
  final String? message;
  final NoticeLevel level;
  final Widget? trailing;
  final VoidCallback? onTap;

  ({Color bg, Color border, Color fg, IconData icon}) get _style {
    switch (level) {
      case NoticeLevel.success:
        return (
          bg: AppColors.greenTint,
          border: AppColors.greenLine,
          fg: AppColors.greenDeep,
          icon: Icons.check_circle_outline_rounded,
        );
      case NoticeLevel.info:
        return (
          bg: AppColors.blueTint,
          border: AppColors.blueLine,
          fg: AppColors.blueDeep,
          icon: Icons.info_outline_rounded,
        );
      case NoticeLevel.error:
        return (
          bg: AppColors.redTint,
          border: AppColors.redLine,
          fg: AppColors.redDeep,
          icon: Icons.error_outline_rounded,
        );
      case NoticeLevel.caution:
        return (
          bg: AppColors.cautionTint,
          border: AppColors.cautionLine,
          fg: AppColors.cautionDeep,
          icon: Icons.warning_amber_rounded,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _style;

    return AppCard(
      onTap: onTap,
      background: s.bg,
      borderColor: s.border,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(s.icon, size: 20, color: s.fg == AppColors.cautionDeep
              ? AppColors.caution
              : s.fg),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null)
                  Text(
                    title!,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: s.fg,
                    ),
                  ),
                if (message != null) ...[
                  if (title != null) const SizedBox(height: 3),
                  Text(message!, style: AppText.small),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 10), trailing!],
          if (trailing == null && onTap != null)
            Icon(Icons.chevron_right_rounded, size: 20, color: s.fg),
        ],
      ),
    );
  }
}

/// How far a quantity is towards being fully covered by EAL links. Amber
/// while short, green when complete — plus the figures in words beside it.
class LinkedProgressBar extends StatelessWidget {
  const LinkedProgressBar({
    super.key,
    required this.linked,
    required this.required_,
    this.height = 7,
    this.accent,
    this.label,
    this.trailing,
  });

  final num linked;
  final num required_;
  final double height;
  final Color? accent;
  final Widget? label;
  final Widget? trailing;

  double get fraction {
    if (required_ <= 0) return 0;
    final f = linked / required_;
    return f.clamp(0.0, 1.0).toDouble();
  }

  bool get isComplete => required_ > 0 && linked + 1e-6 >= required_;

  @override
  Widget build(BuildContext context) {
    final color = accent ??
        (isComplete
            ? AppColors.green
            : (linked <= 0 ? AppColors.ink400 : AppColors.caution));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null || trailing != null) ...[
          Row(
            children: [
              if (label != null) Expanded(child: label!),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 6),
        ],
        ClipRRect(
          borderRadius: AppRadius.brPill,
          child: SizedBox(
            height: height,
            child: LinearProgressIndicator(
              value: fraction,
              backgroundColor: AppColors.sunken,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ),
      ],
    );
  }
}

/// A thin determinate strip under the header, in place of the full-screen
/// `Colors.black26` barrier the old build threw up on every fetch.
class ThinLoadingBar extends StatelessWidget {
  const ThinLoadingBar({super.key, this.color = AppColors.blue});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 3,
      child: LinearProgressIndicator(
        backgroundColor: AppColors.skeleton,
        valueColor: AlwaysStoppedAnimation<Color>(color),
      ),
    );
  }
}

/// A grey placeholder bar, sized like the text it stands in for.
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({
    super.key,
    this.width,
    this.height = 12,
    this.radius = 6,
  });

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.skeleton,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// The shape of a list row while the day loads.
class SkeletonListCard extends StatelessWidget {
  const SkeletonListCard({super.key, this.opacity = 1});

  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity,
      child: const AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                SkeletonBox(width: 116, height: 14),
                SkeletonBox(width: 74, height: 22, radius: 999),
              ],
            ),
            SizedBox(height: 9),
            SkeletonBox(width: 92, height: 10),
            SizedBox(height: 14),
            SkeletonBox(width: 218, height: 14),
            SizedBox(height: 18),
            SkeletonBox(height: 7, radius: 999),
          ],
        ),
      ),
    );
  }
}

/// Several skeleton rows, fading out down the list.
class SkeletonList extends StatelessWidget {
  const SkeletonList({super.key, this.count = 3});

  final int count;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.gutter,
        AppSpace.lg,
        AppSpace.gutter,
        AppSpace.lg,
      ),
      itemCount: count,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) => SkeletonListCard(opacity: i == count - 1 ? 0.55 : 1),
    );
  }
}

/// Replaces `Center(child: Text("No dispatches found."))`: says what is
/// missing, gives the nearest useful fact, and offers the next action.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.accent = AppColors.blue,
    this.tint = AppColors.blueTint,
    this.primaryLabel,
    this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
  });

  final IconData icon;
  final String title;
  final String? message;
  final Color accent;
  final Color tint;
  final String? primaryLabel;
  final VoidCallback? onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 34, vertical: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: tint,
                borderRadius: BorderRadius.circular(21),
              ),
              child: Icon(icon, size: 36, color: accent),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.19,
                color: AppColors.ink900,
              ),
            ),
            if (message != null) ...[
              const SizedBox(height: 9),
              Text(message!, textAlign: TextAlign.center, style: AppText.bodyMuted),
            ],
            if (onPrimary != null) ...[
              const SizedBox(height: 26),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onPrimary,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accent,
                    minimumSize: const Size.fromHeight(50),
                  ),
                  child: Text(primaryLabel ?? 'Continue'),
                ),
              ),
            ],
            if (onSecondary != null) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: onSecondary,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                  ),
                  child: Text(secondaryLabel ?? 'Back'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A labelled figure, as used in the stat tiles and detail summaries.
class FigureTile extends StatelessWidget {
  const FigureTile({
    super.key,
    required this.value,
    required this.label,
    this.color = AppColors.ink900,
    this.size = 21,
  });

  final String value;
  final String label;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: AppText.figure(size: size, color: color)),
        const SizedBox(height: 3),
        Text(label, style: AppText.micro, maxLines: 2),
      ],
    );
  }
}
