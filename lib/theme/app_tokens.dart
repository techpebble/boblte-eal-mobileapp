import 'package:flutter/material.dart';

/// Design tokens for the EAL Track redesign.
///
/// Every text colour here clears 4.5:1 on the surface it is used against,
/// including the 11px labels. Module accents differ in lightness as well as
/// hue so they stay distinguishable without relying on colour vision.
class AppColors {
  // Brand and primary action
  static const navy = Color(0xFF06235F);
  static const navyInk = Color(0xFF041A47);
  static const blue = Color(0xFF1F5FE0);
  static const blueDeep = Color(0xFF0B3FB0);
  static const blueTint = Color(0xFFEEF3FF);
  static const blueLine = Color(0xFFD6E2FF);
  static const onNavyMuted = Color(0xFFBFD0EE);
  static const onBlueMuted = Color(0xFFCEDDF8);

  // Module accents
  static const indigo = Color(0xFF3D4EA8); // issuance
  static const indigoDeep = Color(0xFF2F3D85);
  static const indigoTint = Color(0xFFEEF0FB);
  static const teal = Color(0xFF0F6E68); // production
  static const tealDeep = Color(0xFF0B4F4A);
  static const tealTint = Color(0xFFE8F4F2);
  static const tealLine = Color(0xFF9FC8C4);
  static const amber = Color(0xFFA8541A); // dispatch
  static const amberDeep = Color(0xFF8A4514);
  static const amberTint = Color(0xFFFBF0E7);

  // Feedback
  static const green = Color(0xFF0E7A4F);
  static const greenDeep = Color(0xFF0B6341);
  static const greenTint = Color(0xFFE7F4EE);
  static const greenLine = Color(0xFFC3E4D4);
  static const caution = Color(0xFF8A5A00);
  static const cautionDeep = Color(0xFF6B4600);
  static const cautionTint = Color(0xFFFBF3E2);
  static const cautionLine = Color(0xFFEBD9B4);
  static const red = Color(0xFFB42318);
  static const redDeep = Color(0xFF8F1D14);
  static const redTint = Color(0xFFFDECEA);
  static const redLine = Color(0xFFE5B6B1);

  // Ink
  static const ink900 = Color(0xFF0B1220);
  static const ink700 = Color(0xFF334155);
  static const ink500 = Color(0xFF5B6B84);

  /// Non-text only: 3.4:1. Used for the dimmed leading zeros of a serial,
  /// which always sit beside the same number at full contrast.
  static const ink400 = Color(0xFF9AA8BE);

  // Surfaces and lines
  static const surface = Color(0xFFFFFFFF);
  static const canvas = Color(0xFFF4F6F9);
  static const sunken = Color(0xFFEDF0F5);
  static const field = Color(0xFFF8FAFC);
  static const line = Color(0xFFE2E6ED);
  static const lineSoft = Color(0xFFEDF0F5);
  static const lineField = Color(0xFFD9E0EB);
  static const lineStrong = Color(0xFFC9D4E8);
  static const skeleton = Color(0xFFE6EAF1);

  // Scanner (dark)
  static const scannerBase = Color(0xFF0C0F14);
  static const scannerCamera = Color(0xFF1A1E25);
  static const scannerInk = Color(0xFFF5F7FA);
  static const scannerMuted = Color(0xFF9FB2CE);
  static const scannerAccent = Color(0xFF7FE3B4);
}

class AppRadius {
  static const control = 12.0;
  static const tile = 14.0;
  static const card = 16.0;
  static const sheet = 24.0;
  static const pill = 999.0;

  static const brControl = BorderRadius.all(Radius.circular(control));
  static const brTile = BorderRadius.all(Radius.circular(tile));
  static const brCard = BorderRadius.all(Radius.circular(card));
  static const brPill = BorderRadius.all(Radius.circular(pill));
  static const brSheet = BorderRadius.vertical(top: Radius.circular(sheet));
}

class AppSpace {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 18.0;
  static const xxl = 24.0;

  /// Horizontal page gutter used by every screen body.
  static const gutter = 18.0;

  /// Minimum interactive size. Android asks for 48dp; the old build had
  /// 20px icon buttons.
  static const touch = 48.0;
}

/// Type scale. Serial numbers use [mono] so digits align column-wise and a
/// transposed figure is visible at a glance.
class AppText {
  static const monoFamily = 'monospace';
  static const _tabular = <FontFeature>[FontFeature.tabularFigures()];

  static const display = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.56,
    height: 1.1,
    color: AppColors.ink900,
  );

  static const headline = TextStyle(
    fontSize: 23,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.46,
    color: AppColors.ink900,
  );

  static const title = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.2,
    color: AppColors.ink900,
  );

  static const appBarTitle = TextStyle(
    fontSize: 16.5,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.17,
    color: AppColors.ink900,
  );

  static const cardTitle = TextStyle(
    fontSize: 15.5,
    fontWeight: FontWeight.w600,
    color: AppColors.ink900,
  );

  static const body = TextStyle(
    fontSize: 15,
    height: 1.45,
    color: AppColors.ink900,
  );

  static const bodyMuted = TextStyle(
    fontSize: 14,
    height: 1.5,
    color: AppColors.ink700,
  );

  static const small = TextStyle(
    fontSize: 12.5,
    height: 1.45,
    color: AppColors.ink700,
  );

  static const label = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: AppColors.ink900,
  );

  static const labelMuted = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: AppColors.ink500,
  );

  static const micro = TextStyle(
    fontSize: 11.5,
    fontWeight: FontWeight.w600,
    color: AppColors.ink500,
  );

  /// Section heading: uppercase, tracked out.
  static const section = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.96,
    color: AppColors.ink500,
  );

  static TextStyle mono({
    double size = 14,
    FontWeight weight = FontWeight.w400,
    Color color = AppColors.ink900,
    double letterSpacing = 0.28,
  }) {
    return TextStyle(
      fontFamily: monoFamily,
      fontFeatures: _tabular,
      fontSize: size,
      fontWeight: weight,
      color: color,
      letterSpacing: letterSpacing,
    );
  }

  /// Large figures (case counts, totals) read better with tabular digits
  /// even in the UI face, so columns of numbers line up.
  static TextStyle figure({
    double size = 21,
    Color color = AppColors.ink900,
    FontWeight weight = FontWeight.w600,
  }) {
    return TextStyle(
      fontFamily: monoFamily,
      fontFeatures: _tabular,
      fontSize: size,
      fontWeight: weight,
      color: color,
      letterSpacing: -0.4,
    );
  }
}

/// The three modules, each with its accent set. Used by lists, tabs and
/// primary actions so a screen's module is readable without its title.
enum AppModule {
  issuance(AppColors.indigo, AppColors.indigoDeep, AppColors.indigoTint),
  production(AppColors.teal, AppColors.tealDeep, AppColors.tealTint),
  dispatch(AppColors.amber, AppColors.amberDeep, AppColors.amberTint),
  neutral(AppColors.blue, AppColors.blueDeep, AppColors.blueTint);

  const AppModule(this.accent, this.accentDeep, this.tint);

  final Color accent;
  final Color accentDeep;
  final Color tint;
}
