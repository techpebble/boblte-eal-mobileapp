import 'package:flutter/material.dart';

class AppBrand {
  static const name = 'EAL Track';
  static const logo = 'assets/branding/eal-track.png';
  static const navy = Color(0xFF06235F);

  static const tagline =
      'Issuance, production and dispatch for excise '
      'adhesive labels.';

  /// Kept in step with `version:` in pubspec.yaml. Shown on the sign-in and
  /// account screens so a field report can name the exact build.
  static const version = '1.0.1+2';
}
