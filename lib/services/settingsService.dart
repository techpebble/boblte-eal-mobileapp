import 'package:get_storage/get_storage.dart';

/// Device-local preferences for the scanning flow. These change how the
/// scanner behaves on the plant floor, so they are deliberately few.
class SettingsService {
  static final GetStorage _storage = GetStorage();

  static const _torchKey = 'pref_torch_default';
  static const _feedbackKey = 'pref_scan_feedback';
  static const _prefixKey = 'pref_default_prefix';

  /// Poor light in the bottling hall is the norm, so the torch defaults on.
  static bool get torchByDefault => _storage.read(_torchKey) ?? true;

  static Future<void> setTorchByDefault(bool value) =>
      _storage.write(_torchKey, value);

  /// A beep and a buzz confirm a read without the operator looking up.
  static bool get scanFeedback => _storage.read(_feedbackKey) ?? true;

  static Future<void> setScanFeedback(bool value) =>
      _storage.write(_feedbackKey, value);

  /// Remembered so the first step of the scan wizard is usually pre-filled.
  static String get defaultPrefix =>
      (_storage.read(_prefixKey) as String?)?.toUpperCase() ?? '';

  static Future<void> setDefaultPrefix(String value) =>
      _storage.write(_prefixKey, value.trim().toUpperCase());
}
