/// Ordering rules the grouped lists share.

/// `local` before `export`, matching the server's own enum order.
int marketRank(String market) => market.toLowerCase() == 'local' ? 0 : 1;

/// The millilitres leading a name, so 90ml sorts before 180ml. Names that do
/// not start with a number fall back to their text, after the sized ones.
int? leadingSize(String name) {
  final match = RegExp(r'^\s*(\d+)').firstMatch(name);
  return match == null ? null : int.tryParse(match.group(1)!);
}

int compareBySize(String a, String b) {
  final sa = leadingSize(a);
  final sb = leadingSize(b);
  if (sa != null && sb != null && sa != sb) return sa.compareTo(sb);
  if (sa != null && sb == null) return -1;
  if (sa == null && sb != null) return 1;
  return a.toLowerCase().compareTo(b.toLowerCase());
}
