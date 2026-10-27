// OOTD365 design tokens: one place for color, type, spacing, radii and motion.
// Screens use these names, never raw values.

import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

/// Warm neutrals: ivory paper, sand for image grounds, espresso ink, one clay accent.
abstract final class OColors {
  static const canvas = Color(0xFFF7F3EE);
  static const surface = Color(0xFFFFFDFA);
  static const sand = Color(0xFFEFE8DF);
  static const sandDeep = Color(0xFFE4DACD);
  static const line = Color(0xFFE6DDD2);

  static const ink = Color(0xFF2A2420);
  static const inkSoft = Color(0xFF5C524B);
  static const inkMuted = Color(0xFF8C8178);
  static const inkFaint = Color(0xFFB3A89E);
  static const onInk = Color(0xFFFBF8F4);

  static const clay = Color(0xFFA8714F);
  static const claySoft = Color(0xFFF1E4D9);
  static const error = Color(0xFFA9483A);
  static const errorSoft = Color(0xFFF6E3DE);

  /// Dim layer over photos for legible captions.
  static const scrim = Color(0x662A2420);
}

/// 4-pt rhythm. `gutter` is the screen edge.
abstract final class OSpace {
  static const xxs = 4.0;
  static const xs = 8.0;
  static const sm = 12.0;
  static const md = 16.0;
  static const gutter = 20.0;
  static const lg = 24.0;
  static const xl = 32.0;
  static const xxl = 48.0;
}

abstract final class ORadius {
  static const tile = 14.0;
  static const card = 20.0;
  static const sheet = 28.0;
  static const pill = 999.0;
}

/// Wardrobe assets are portrait, like a garment on a hanger.
abstract final class OAspect {
  static const asset = 3 / 4;
  static const look = 4 / 5;
}

abstract final class OMotion {
  static const quick = Duration(milliseconds: 160);
  static const standard = Duration(milliseconds: 240);
  static const curve = Curves.easeOutCubic;
}

/// Serif for moments (dates, numbers, Latin headers); platform sans for everything you read.
/// The serif has no CJK glyphs: never set Chinese in it. Chinese headings use [heading].
abstract final class OType {
  static const serif = 'InstrumentSerif';

  static const display = TextStyle(fontFamily: serif, fontSize: 40, height: 1.05, color: OColors.ink, letterSpacing: -0.4);
  static const headline = TextStyle(fontFamily: serif, fontSize: 30, height: 1.1, color: OColors.ink, letterSpacing: -0.2);
  static const numeral = TextStyle(fontFamily: serif, fontSize: 28, height: 1.0, color: OColors.ink);
  static const serifItalic = TextStyle(fontFamily: serif, fontStyle: FontStyle.italic, fontSize: 18, height: 1.2, color: OColors.inkSoft);

  /// Chinese display heading: light sans, slightly open tracking.
  static const heading = TextStyle(fontSize: 28, height: 1.25, fontWeight: FontWeight.w300, letterSpacing: 1.2, color: OColors.ink);
  static const title = TextStyle(fontSize: 17, height: 1.35, fontWeight: FontWeight.w600, color: OColors.ink);
  static const body = TextStyle(fontSize: 15, height: 1.5, color: OColors.ink);
  static const bodyMuted = TextStyle(fontSize: 14, height: 1.5, color: OColors.inkMuted);
  static const label = TextStyle(fontSize: 13, height: 1.3, fontWeight: FontWeight.w500, color: OColors.ink);
  static const caption = TextStyle(fontSize: 12, height: 1.3, color: OColors.inkMuted);

  /// Small spaced capitals above sections: "TUESDAY", "TOPS".
  static const overline =
      TextStyle(fontSize: 11, height: 1.2, fontWeight: FontWeight.w600, letterSpacing: 1.6, color: OColors.inkMuted);
}

ThemeData buildTheme() {
  const scheme = ColorScheme(
    brightness: Brightness.light,
    primary: OColors.ink,
    onPrimary: OColors.onInk,
    secondary: OColors.clay,
    onSecondary: OColors.onInk,
    error: OColors.error,
    onError: OColors.onInk,
    surface: OColors.canvas,
    onSurface: OColors.ink,
    surfaceContainerHighest: OColors.sand,
    surfaceContainerHigh: OColors.sand,
    surfaceContainer: OColors.surface,
    surfaceContainerLow: OColors.surface,
    surfaceContainerLowest: OColors.surface,
    outline: OColors.line,
    outlineVariant: OColors.line,
  );
  final base = ThemeData(useMaterial3: true, colorScheme: scheme);
  return base.copyWith(
    scaffoldBackgroundColor: OColors.canvas,
    splashFactory: NoSplash.splashFactory,
    highlightColor: OColors.sand.withValues(alpha: 0.5),
    textTheme: base.textTheme.apply(bodyColor: OColors.ink, displayColor: OColors.ink),
    appBarTheme: const AppBarTheme(
      backgroundColor: OColors.canvas,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      foregroundColor: OColors.ink,
      titleTextStyle: OType.title,
    ),
    dividerTheme: const DividerThemeData(color: OColors.line, thickness: 0.5, space: 0.5),
    inputDecorationTheme: const InputDecorationTheme(
      labelStyle: OType.overline,
      floatingLabelStyle: OType.overline,
      hintStyle: TextStyle(color: OColors.inkFaint),
      border: UnderlineInputBorder(borderSide: BorderSide(color: OColors.line)),
      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: OColors.line)),
      focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: OColors.ink, width: 1.2)),
      contentPadding: EdgeInsets.symmetric(vertical: OSpace.sm),
    ),
    textSelectionTheme: const TextSelectionThemeData(cursorColor: OColors.ink, selectionColor: OColors.claySoft),
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: OColors.ink,
      contentTextStyle: TextStyle(color: OColors.onInk, fontSize: 14),
      shape: StadiumBorder(),
      elevation: 0,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: OColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(ORadius.sheet))),
      showDragHandle: true,
      dragHandleColor: OColors.sandDeep,
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: OColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(ORadius.card))),
      titleTextStyle: OType.title,
      contentTextStyle: OType.bodyMuted,
    ),
    datePickerTheme: const DatePickerThemeData(
      backgroundColor: OColors.surface,
      surfaceTintColor: Colors.transparent,
      headerBackgroundColor: OColors.canvas,
      headerForegroundColor: OColors.ink,
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: OColors.ink, linearTrackColor: OColors.sand),
    pageTransitionsTheme: const PageTransitionsTheme(builders: {
      TargetPlatform.android: CupertinoPageTransitionsBuilder(),
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
    }),
  );
}

const _months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
const _weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
const _weekdaysZh = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];

/// Editorial date words. The archive speaks in English display type; body copy stays Chinese.
abstract final class ODate {
  static String month(DateTime d) => _months[d.month - 1];
  static String weekday(DateTime d) => _weekdays[d.weekday - 1];
  static String weekdayZh(DateTime d) => _weekdaysZh[d.weekday - 1];

  /// Parses the contract's `YYYY-MM-DD`.
  static DateTime parse(String date) {
    final parts = date.split('-').map(int.parse).toList();
    return DateTime(parts[0], parts[1], parts[2]);
  }
}
