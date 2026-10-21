import 'package:intl/intl.dart';

final NumberFormat _decimal = NumberFormat.decimalPattern();
final NumberFormat _compact = NumberFormat.compact();
final DateFormat _dayMonth = DateFormat('d MMM');
final DateFormat _dayMonthYear = DateFormat('d MMM yyyy');
final DateFormat _fullDay = DateFormat('EEEE, d MMMM');
final DateFormat _clock = DateFormat('HH:mm');
final DateFormat _monthYear = DateFormat('MMMM yyyy');

/// `48,000`. Trailing `.0` is dropped: case counts arrive as doubles from the
/// API because they are derived by division.
String formatQty(num value) {
  final rounded = value.roundToDouble();
  if ((value - rounded).abs() < 0.005) {
    return _decimal.format(rounded.toInt());
  }
  return _decimal.format(double.parse(value.toStringAsFixed(2)));
}

/// `48K` — for the narrow stat tiles, where three figures share one row.
String formatCompactQty(num value) {
  if (value.abs() < 10000) return formatQty(value);
  return _compact.format(value);
}

/// `200 cases` / `1 case`
String formatCases(num value) {
  final n = formatQty(value);
  final singular = (value - 1).abs() < 0.005;
  return '$n ${singular ? 'case' : 'cases'}';
}

String formatLabels(num value) {
  final n = formatQty(value);
  final singular = (value - 1).abs() < 0.005;
  return '$n ${singular ? 'label' : 'labels'}';
}

String formatDayMonth(DateTime date) => _dayMonth.format(date);

/// For a calendar heading, e.g. "October 2026".
String formatMonthYear(DateTime date) => _monthYear.format(date);

String formatDayMonthYear(DateTime date) => _dayMonthYear.format(date);

String formatFullDay(DateTime date) => _fullDay.format(date);

String formatClock(DateTime date) => _clock.format(date);

/// Relative wording for a date the user is filtering by, so the chip reads
/// "Today" rather than a date they have to decode.
String formatRelativeDay(DateTime date) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final target = DateTime(date.year, date.month, date.day);
  final diff = today.difference(target).inDays;

  if (diff == 0) return 'Today';
  if (diff == 1) return 'Yesterday';
  if (diff == -1) return 'Tomorrow';
  return formatDayMonth(date);
}

/// Title-cases a backend enum value such as `local` or `draft`.
String titleCase(String value) {
  final v = value.trim();
  if (v.isEmpty) return v;
  return v[0].toUpperCase() + v.substring(1).toLowerCase();
}

/// Greeting for the home screen, by local clock.
String greetingFor(DateTime now) {
  final hour = now.hour;
  if (hour < 12) return 'Good morning';
  if (hour < 17) return 'Good afternoon';
  return 'Good evening';
}
