import 'package:flutter/cupertino.dart';

/// Minimal Fitness-inspired palette with light / dark variants.
/// Toggle [dark] from the store before rebuilds.
class AppColors {
  static bool dark = false;

  static Color get background =>
      dark ? const Color(0xFF000000) : const Color(0xFFF2F2F7);
  static Color get canvas =>
      dark ? const Color(0xFF000000) : const Color(0xFFFFFFFF);
  static Color get groupedBackground =>
      dark ? const Color(0xFF1C1C1E) : const Color(0xFFF2F2F7);
  static Color get card =>
      dark ? const Color(0xFF1C1C1E) : const Color(0xFFFFFFFF);
  static Color get label =>
      dark ? const Color(0xFFF5F5F7) : const Color(0xFF1C1C1E);
  static Color get secondaryLabel =>
      dark ? const Color(0xFF8E8E93) : const Color(0xFF8E8E93);
  static Color get tertiaryLabel =>
      dark ? const Color(0xFF48484A) : const Color(0xFFC7C7CC);
  static Color get separator =>
      dark ? const Color(0xFF38383A) : const Color(0xFFE5E5EA);
  static Color get fill =>
      dark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7);
  static Color get navBar =>
      dark ? const Color(0xF01C1C1E) : const Color(0xF0F9F9F9);
  static Color get tabBar =>
      dark ? const Color(0xF01C1C1E) : const Color(0xF0F9F9F9);

  static const indigo = Color(0xFF5856D6);
  static const blue = Color(0xFF0A84FF);
  static const teal = Color(0xFF64D2FF);
  static const green = Color(0xFF30D158);
  static const orange = Color(0xFFFF9F0A);
  static const red = Color(0xFFFF453A);
  static const pink = Color(0xFFFF375F);

  static const ringMove = Color(0xFFFA4D67);
  static const ringExercise = Color(0xFF9BFF37);
  static const ringExerciseDark = Color(0xFF7CD300);
  static const ringStand = Color(0xFF5CE5FF);

  static const dotTests = Color(0xFF8B7CFF);
  static const dotGross = Color(0xFFFFCC00);
  static const dotNet = Color(0xFFFF6BCB);
  static const dotAcc = Color(0xFF30D158);

  static const gradientStart = Color(0xFFFA4D67);
  static const gradientEnd = Color(0xFFFF9F0A);

  static const _base = CupertinoTextThemeData();

  static CupertinoThemeData cupertinoTheme() {
    final brightness = dark ? Brightness.dark : Brightness.light;
    return CupertinoThemeData(
      brightness: brightness,
      primaryColor: indigo,
      scaffoldBackgroundColor: canvas,
      barBackgroundColor: navBar,
      // Derive from Cupertino's defaults (inherit: false) — the nav-bar
      // back-swipe animation interpolates these with the back-button label
      // style and throws if the `inherit` values differ.
      textTheme: CupertinoTextThemeData(
        textStyle: _base.textStyle.copyWith(color: label, fontSize: 16),
        navLargeTitleTextStyle: _base.navLargeTitleTextStyle.copyWith(
          fontSize: 34,
          fontWeight: FontWeight.w700,
          color: label,
          letterSpacing: -0.5,
        ),
        navTitleTextStyle: _base.navTitleTextStyle.copyWith(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: label,
        ),
      ),
    );
  }
}
