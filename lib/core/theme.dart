import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

// ── CleanCruisers design tokens ───────────────────────────────────────────────
// Every screen should pull colour, spacing, radius, shadow and type from here.

class AppColors {
  // Brand
  static const brand = Color(0xFF1DE874); // logo green — accents on dark only
  static const primary = Color(0xFF15803D); // buttons, links (AA on white)
  static const primaryDk = Color(0xFF166534);
  static const primarySoft = Color(0xFFE8F7EE); // tinted backgrounds
  static const ink = Color(0xFF0B0F10); // brand black — hero, splash
  static const forest = Color(0xFF083322); // deep green — Home hero overlay

  // Neutrals
  static const bg = Color(0xFFF5F6F8);
  static const surface = Colors.white;
  static const surfaceAlt = Color(0xFFF0F2F5);
  static const border = Color(0xFFE3E6EA);
  static const text = Color(0xFF111827);
  static const textMuted = Color(0xFF4B5563);
  static const textSubtle = Color(0xFF5A6270);

  // Status
  static const error = Color(0xFFDC2626);
  static const errorSoft = Color(0xFFFEF2F2);
  static const warning = Color(0xFFB45309);
  static const warningSoft = Color(0xFFFFF7E6);
  static const star = Color(0xFFF59E0B);
}

class AppSpace {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const xxl = 24.0;
  static const section = 32.0;
  static const page = 20.0; // horizontal page gutter
}

class AppRadius {
  static const sm = 10.0;
  static const thumb = 12.0; // small photos in list rows
  static const md = 14.0;
  static const lg = 20.0;
  static const sheet = 28.0; // content sheet over a hero photo
  static const pill = 999.0;
}

class AppShadow {
  static const card = [
    BoxShadow(color: Color(0x0F101828), blurRadius: 12, offset: Offset(0, 4)),
    BoxShadow(color: Color(0x08101828), blurRadius: 2, offset: Offset(0, 1)),
  ];
  static const raised = [
    BoxShadow(color: Color(0x1A101828), blurRadius: 24, offset: Offset(0, -4)),
  ];
}

/// Type scale (Manrope), size/line-height: Home hero 32/38 800, display
/// 30/36 800, screen 24/30 800, section 20/26 800, card 16/22 700,
/// price 22/28 800, button 16/700, body 14/20 400, secondary 13/400,
/// labels 12/600, bottom nav 12/16 600.
/// Recolour with `copyWith(color: …)`; don't build new TextStyles.
class AppText {
  static TextStyle _f(double size, FontWeight w, Color c,
          {double? h, double ls = 0}) =>
      GoogleFonts.manrope(
          fontSize: size,
          fontWeight: w,
          color: c,
          height: h,
          letterSpacing: ls);

  /// The Home hero headline: the strongest text in the app.
  static TextStyle get hero =>
      _f(32, FontWeight.w800, AppColors.text, h: 38 / 32, ls: -0.8);

  /// Big headings (dark status cards, sign-in hero, splash).
  static TextStyle get display =>
      _f(30, FontWeight.w800, AppColors.text, h: 36 / 30, ls: -0.6);

  /// Screen headings.
  static TextStyle get h1 =>
      _f(24, FontWeight.w800, AppColors.text, h: 30 / 24, ls: -0.4);

  /// Section headings.
  static TextStyle get h2 =>
      _f(20, FontWeight.w800, AppColors.text, h: 26 / 20, ls: -0.3);

  /// Card titles and step headings.
  static TextStyle get h3 =>
      _f(16, FontWeight.w700, AppColors.text, h: 22 / 16, ls: -0.2);

  /// Titles of compact cards and tiles.
  static TextStyle get title =>
      _f(16, FontWeight.w600, AppColors.text, h: 1.35, ls: -0.1);

  /// Body text.
  static TextStyle get body =>
      _f(14, FontWeight.w400, AppColors.textMuted, h: 20 / 14);
  static TextStyle get bodyStrong =>
      _f(14, FontWeight.w600, AppColors.text, h: 1.45);

  /// Secondary text.
  static TextStyle get small =>
      _f(13, FontWeight.w400, AppColors.textMuted, h: 1.45);
  static TextStyle get smallStrong =>
      _f(13, FontWeight.w600, AppColors.text, h: 1.4);

  /// Small labels.
  static TextStyle get caption =>
      _f(12, FontWeight.w600, AppColors.textSubtle, h: 1.35);

  /// ALL-CAPS small labels.
  static TextStyle get overline =>
      _f(12, FontWeight.w600, AppColors.textSubtle, ls: 1.0);

  /// Prices.
  static TextStyle get price =>
      _f(22, FontWeight.w800, AppColors.text, h: 28 / 22, ls: -0.4);

  /// Prices inside dense rows and tiles, where 24 would crowd the layout.
  static TextStyle get priceSm =>
      _f(18, FontWeight.w800, AppColors.text, h: 1.25, ls: -0.2);

  /// Buttons (set by the button themes).
  static TextStyle get button => _f(16, FontWeight.w700, Colors.white);

  /// Bottom navigation labels.
  static TextStyle get nav =>
      _f(12, FontWeight.w600, AppColors.textSubtle, h: 16 / 12);
}

class AppTheme {
  static const overlayDark = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
    systemNavigationBarColor: Colors.white,
    systemNavigationBarIconBrightness: Brightness.dark,
  );

  static ThemeData get light {
    final base = ThemeData.light(useMaterial3: true);
    final radius = BorderRadius.circular(AppRadius.md);
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.bg,
      colorScheme: const ColorScheme.light(
        primary: AppColors.primary,
        onPrimary: Colors.white,
        secondary: AppColors.primary,
        surface: AppColors.surface,
        onSurface: AppColors.text,
        outline: AppColors.border,
        error: AppColors.error,
      ),
      textTheme: GoogleFonts.manropeTextTheme(base.textTheme).apply(
        bodyColor: AppColors.text,
        displayColor: AppColors.text,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        systemOverlayStyle: overlayDark,
        titleTextStyle: AppText.h3,
        iconTheme: const IconThemeData(color: AppColors.text),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.border,
          disabledForegroundColor: AppColors.textSubtle,
          minimumSize: const Size(64, 54),
          padding: const EdgeInsets.symmetric(horizontal: 22),
          shape: RoundedRectangleBorder(borderRadius: radius),
          elevation: 0,
          textStyle: AppText.button,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.text,
          side: const BorderSide(color: AppColors.border, width: 1.2),
          backgroundColor: AppColors.surface,
          minimumSize: const Size(64, 54),
          padding: const EdgeInsets.symmetric(horizontal: 22),
          shape: RoundedRectangleBorder(borderRadius: radius),
          textStyle: AppText.button,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          minimumSize: const Size(48, 44),
          textStyle: AppText.smallStrong,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
            borderRadius: radius,
            borderSide: const BorderSide(color: AppColors.border)),
        enabledBorder: OutlineInputBorder(
            borderRadius: radius,
            borderSide: const BorderSide(color: AppColors.border)),
        focusedBorder: OutlineInputBorder(
            borderRadius: radius,
            borderSide: const BorderSide(color: AppColors.primary, width: 1.8)),
        errorBorder: OutlineInputBorder(
            borderRadius: radius,
            borderSide: const BorderSide(color: AppColors.error)),
        focusedErrorBorder: OutlineInputBorder(
            borderRadius: radius,
            borderSide: const BorderSide(color: AppColors.error, width: 1.8)),
        hintStyle: AppText.body.copyWith(color: AppColors.textSubtle),
        errorStyle: AppText.caption.copyWith(color: AppColors.error),
        prefixIconColor: AppColors.textSubtle,
      ),
      dividerTheme: const DividerThemeData(
          color: AppColors.border, thickness: 1, space: 1),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: AppColors.primarySoft,
        height: 68,
        labelTextStyle:
            WidgetStateProperty.resolveWith((s) => AppText.nav.copyWith(
                  color: s.contains(WidgetState.selected)
                      ? AppColors.primary
                      : AppColors.textSubtle,
                )),
        iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(
              color: s.contains(WidgetState.selected)
                  ? AppColors.primary
                  : AppColors.textSubtle,
            )),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.text,
        contentTextStyle: AppText.small.copyWith(color: Colors.white),
        actionTextColor: AppColors.brand,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm)),
        behavior: SnackBarBehavior.floating,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(AppRadius.lg))),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg)),
        titleTextStyle: AppText.h3,
        contentTextStyle: AppText.body,
      ),
      progressIndicatorTheme:
          const ProgressIndicatorThemeData(color: AppColors.primary),
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
      }),
    );
  }
}
