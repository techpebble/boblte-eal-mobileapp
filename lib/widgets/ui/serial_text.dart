import 'package:flutter/material.dart';

import 'package:eal_scanner/theme/app_tokens.dart';

/// Serial numbers are the app's primary datum, so they get a treatment of
/// their own: the prefix is chipped off, the padding zeros drop back to a
/// lighter ink, and the digits that actually differ carry the weight. The old
/// build printed `From: ML0000012001` as flat body text, where two ranges an
/// hour apart looked identical.
const int kSerialDigits = 10;

/// Splits a padded serial into its leading zeros and its significant digits.
({String zeros, String digits}) splitSerial(int serial) {
  final padded = serial.toString().padLeft(kSerialDigits, '0');
  final firstSignificant = padded.indexOf(RegExp(r'[1-9]'));

  // A serial of 0 is all padding; keep one digit so something renders.
  if (firstSignificant < 0) {
    return (
      zeros: padded.substring(0, padded.length - 1),
      digits: padded.substring(padded.length - 1),
    );
  }

  return (
    zeros: padded.substring(0, firstSignificant),
    digits: padded.substring(firstSignificant),
  );
}

/// The small navy prefix chip, e.g. `ML`.
class SerialPrefixChip extends StatelessWidget {
  const SerialPrefixChip(this.prefix, {super.key, this.size = 11});

  final String prefix;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: size * 0.6, vertical: size * 0.25),
      decoration: const BoxDecoration(
        color: AppColors.navy,
        borderRadius: BorderRadius.all(Radius.circular(5)),
      ),
      child: Text(
        prefix.toUpperCase(),
        style: AppText.mono(
          size: size,
          weight: FontWeight.w600,
          color: Colors.white,
          letterSpacing: size * 0.06,
        ),
      ),
    );
  }
}

/// One serial, with its padding zeros dimmed.
class SerialValue extends StatelessWidget {
  const SerialValue({
    super.key,
    required this.serial,
    this.prefix,
    this.size = 14,
    this.color = AppColors.ink900,
    this.dimColor = AppColors.ink400,
  });

  final int serial;
  final String? prefix;
  final double size;
  final Color color;
  final Color dimColor;

  @override
  Widget build(BuildContext context) {
    final parts = splitSerial(serial);

    final number = Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: parts.zeros,
            style: AppText.mono(size: size, color: dimColor),
          ),
          TextSpan(
            text: parts.digits,
            style: AppText.mono(
              size: size,
              weight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );

    if (prefix == null || prefix!.isEmpty) return number;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SerialPrefixChip(prefix!, size: size * 0.78),
        SizedBox(width: size * 0.5),
        Flexible(child: number),
      ],
    );
  }
}

/// A `from → to` range on one line. Falls back to stacking when the available
/// width cannot hold both serials.
class SerialRangeText extends StatelessWidget {
  const SerialRangeText({
    super.key,
    required this.prefix,
    required this.from,
    required this.to,
    this.size = 13.5,
    this.showPrefix = true,
    this.color = AppColors.ink900,
  });

  final String prefix;
  final int from;
  final int to;
  final double size;
  final bool showPrefix;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showPrefix) ...[
          SerialPrefixChip(prefix, size: size * 0.74),
          SizedBox(width: size * 0.45),
        ],
        Flexible(
          child: SerialValue(serial: from, size: size, color: color),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: size * 0.4),
          child: Icon(
            Icons.arrow_right_alt_rounded,
            size: size * 1.25,
            color: AppColors.ink500,
          ),
        ),
        Flexible(
          child: SerialValue(serial: to, size: size, color: color),
        ),
      ],
    );
  }
}

/// The stacked form used on detail screens, where the range is the headline
/// fact rather than one line of many.
class SerialRangeBlock extends StatelessWidget {
  const SerialRangeBlock({
    super.key,
    required this.prefix,
    required this.from,
    required this.to,
    this.size = 19,
  });

  final String prefix;
  final int from;
  final int to;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SerialValue(serial: from, prefix: prefix, size: size),
        Padding(
          padding: const EdgeInsets.only(left: 4, top: 6, bottom: 6),
          child: Icon(
            Icons.arrow_downward_rounded,
            size: 16,
            color: AppColors.ink400,
          ),
        ),
        SerialValue(serial: to, prefix: prefix, size: size),
      ],
    );
  }
}
