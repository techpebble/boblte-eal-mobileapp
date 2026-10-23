import 'package:get_storage/get_storage.dart';

/// Device-local preferences for the scanning flow. These change how the
/// scanner behaves on the plant floor, so they are deliberately few.
class SettingsService {
  static final GetStorage _storage = GetStorage();

  static const _torchKey = 'pref_torch_default';
  static const _feedbackKey = 'pref_scan_feedback';

  /// Both start off, so a fresh install behaves the same way on every
  /// phone and nothing happens at the first scan that was not asked for.
  /// The torch is one tap away inside the scanner itself.
  static bool get torchByDefault => _storage.read(_torchKey) ?? false;

  static Future<void> setTorchByDefault(bool value) =>
      _storage.write(_torchKey, value);

  /// A beep and a buzz confirm a read without the operator looking up.
  static bool get scanFeedback => _storage.read(_feedbackKey) ?? false;

  static Future<void> setScanFeedback(bool value) =>
      _storage.write(_feedbackKey, value);
}
