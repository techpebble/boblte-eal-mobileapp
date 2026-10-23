import 'package:eal_scanner/config/app_version.dart';
import 'package:flutter/material.dart';

class AppBrand {
  static const name = 'EAL Track';
  static const logo = 'assets/branding/eal-track.png';
  static const navy = Color(0xFF06235F);

  static const tagline =
      'Issuance, production and dispatch for excise '
      'adhesive labels.';

  /// Shown on the sign-in and account screens so a field report can name the
  /// exact build. Built from [AppVersion] rather than written out again: this
  /// read 1.0.1+2 while the APK was 1.0.3+3, which is precisely the question
  /// the About page exists to answer.
  static const version = '${AppVersion.name}+${AppVersion.build}';
}
