import 'package:get/get.dart';

import 'package:eal_scanner/controllers/dashboardController.dart';
import 'package:eal_scanner/controllers/dispatchController.dart';
import 'package:eal_scanner/controllers/issuanceController.dart';
import 'package:eal_scanner/controllers/usageController.dart';

/// A list that knows its records may have moved on without it.
///
/// Every tab is built once and kept alive in the shell's stack, and each one
/// asked the server for its records exactly once, when it was first opened.
/// Nothing ever asked again, so a record added on one tab left the others
/// showing what was true before it — and showing it with no sign that
/// anything had changed.
mixin StaleRecords on GetxController {
  /// Set when something changed the records this list shows. Cleared by the
  /// fetch, so the screen is brought up to date once rather than on every
  /// glance at it.
  final isStale = false.obs;

  void markStale() => isStale.value = true;

  /// Fetches again, but only where something has actually changed. This is
  /// what a tab calls when it is opened: switching tabs is not a reason to
  /// ask the server anything.
  Future<void> refreshIfStale() async {
    if (isStale.value) await refreshRecords();
  }

  /// Asks the server for this list again.
  Future<void> refreshRecords();
}

/// Says that a record was written, so every list showing figures drawn from
/// it fetches again when it is next looked at.
///
/// A write reaches further than the list it was made from. Applying labels
/// moves the issuance's unused balance; linking a range moves the production
/// run's waiting count; either one moves the day's totals on the home screen.
/// The list that owns the write refetches itself at once, because it is the
/// one being looked at — the rest wait until they are.
void recordsChanged() {
  _mark(() => Get.find<Issuancecontroller>());
  _mark(() => Get.find<UsageController>());
  _mark(() => Get.find<DispatchController>());
  _mark(() => Get.find<DashboardController>());
}

/// A controller that is not registered yet has nothing stale to mark: it
/// will fetch when it is first built.
void _mark(StaleRecords Function() find) {
  try {
    find().markStale();
  } catch (_) {}
}
