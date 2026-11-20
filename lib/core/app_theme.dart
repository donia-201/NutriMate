import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const Color primaryGreen = Color(0xFF7BA88C);
  static const Color buttonGreen = Color(0xFF7C9079);
  static const Color background = Color(0xFFF6ECDC);
  static const Color surface = Color(0xFFFAF8F5);
  static const Color textDark = Color(0xFF2C2C2C);
  static const Color textMuted = Color(0xFF6B6B6B);
  static const Color textHint = Color(0xFFA8A8A8);
  static const Color divider = Color(0xFFF0EDE5);
  static const Color accentHeart = Color(0xFFC29B72);
  static const Color buttonText = Color(0xFF4B4A38);
  static const Color dotInactive = Color(0xFFE0DCD3);
  static const Color error = Color(0xFFD64545);
  static const Color success = Color(0xFF52B788);
  static const Color warning = Color(0xFFFFA500);
  static const Color white = Colors.white;
  static const Color border = Color(0xFFCFC9B8);
  static const Color inputBeige = Color(0xFFEFE2CD); // جديد: لون حقل الكتابة في الـ Light

  // ---------- Dark ----------
  static const Color darkBackground = Color(
    0xFF1E1F18,
  ); // background/cream (dark)
  static const Color darkSurface = Color(0xFF303229); // surface/white (dark)
  static const Color darkElevated = Color(0xFF33332B); // surface-elevated
  static const Color darkTextPrimary = Color(0xFFF6EDDC);
  static const Color darkTextSecondary = Color(0xFFC9C4B0);
  static const Color darkAccent = Color(0xFF9DB5A0); // accent-primary
  static const Color darkTextOnAccent = Color(0xFF1C1B18);
  static const Color darkBorder = Color(0xFF3D3F33);

  // ---------- Favorite heart ----------
  static const Color heart = Color(0xFFC9A27A);
}

class AppTheme {
  static const double smallRadius = 12;
  static const double cardRadius = 24;
  static const double sheetRadius = 24;
  static const double gridGap = 12;
  static const double pagePadding = 20;
  static const double gridUnit = 8;

  static const TextStyle titleBold = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.bold,
    height: 1.2,
  );
  static const TextStyle subTitle = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    height: 1.2,
  );
  static const TextStyle buttonText = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.bold,
  );
  static const TextStyle skipText = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
  );
  static const TextStyle label = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
  );
  static const TextStyle body = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
  );
  static const TextStyle small = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.4,
  );
  static const _radius = BorderRadius.all(Radius.circular(16));
  static const _shape = RoundedRectangleBorder(borderRadius: _radius);
  static const _minSize = Size.fromHeight(48);

  static OutlineInputBorder _border([Color? color, double width = 1]) =>
      OutlineInputBorder(
        borderRadius: _radius,
        borderSide: color == null
            ? BorderSide.none
            : BorderSide(color: color, width: width),
      );

  static ButtonStyle outlined(ColorScheme c) => OutlinedButton.styleFrom(
    backgroundColor: c.surface,
    foregroundColor: c.onSurface,
    minimumSize: _minSize,
    side: BorderSide(color: c.outline),
    shape: _shape,
    textStyle: skipText,
  );

  static ThemeData get dark => ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.darkBackground,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.darkAccent,
      onPrimary: AppColors.darkTextOnAccent,
      surface: AppColors.darkSurface,
      onSurface: AppColors.darkTextPrimary,
      onSurfaceVariant: AppColors.darkTextSecondary,
      outline: AppColors.darkBorder,
      error: AppColors.error,
      surfaceContainerHighest: AppColors.darkElevated, // جديد
    ),
    textTheme: GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme),
    listTileTheme: ListTileThemeData(
      tileColor: AppColors.darkSurface,
      textColor: AppColors.darkTextPrimary,
      iconColor: AppColors.darkTextSecondary,
      selectedTileColor: AppColors.darkAccent.withValues(alpha: 0.16),
      selectedColor: AppColors.darkAccent,
      shape: _shape,
    ),
    cardTheme: CardThemeData(
      color: AppColors.darkSurface,
      elevation: 0,
      shape: _shape,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.darkSurface,
      contentPadding: const EdgeInsets.all(16),
      hintStyle: body.copyWith(color: AppColors.textHint),
      border: _border(),
      enabledBorder: _border(),
      focusedBorder: _border(AppColors.darkAccent, 1.5),
      errorBorder: _border(AppColors.error),
      focusedErrorBorder: _border(AppColors.error, 1.5),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.darkAccent,
        foregroundColor: AppColors.darkTextOnAccent,
        minimumSize: _minSize,
        elevation: 0,
        shape: _shape,
        textStyle: skipText,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: outlined(
        const ColorScheme.dark(
          surface: AppColors.darkSurface,
          onSurface: AppColors.darkTextPrimary,
          outline: AppColors.darkBorder,
        ),
      ),
    ),
  );

  static ThemeData get light => ThemeData(
    scaffoldBackgroundColor: AppColors.background,
    colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primaryGreen)
        .copyWith(
      primary: AppColors.primaryGreen, // جديد
      onPrimary: AppColors.buttonText, // جديد
      surface: AppColors.surface,
      onSurface: AppColors.textDark,
      onSurfaceVariant: AppColors.textMuted,
      outline: AppColors.border,
      surfaceContainerHighest: AppColors.inputBeige, // جديد
    ),
    textTheme: GoogleFonts.poppinsTextTheme(),
    listTileTheme: ListTileThemeData(
      tileColor: AppColors.surface,
      textColor: AppColors.textDark,
      iconColor: AppColors.textMuted,
      selectedTileColor: AppColors.primaryGreen.withValues(alpha: 0.12),
      selectedColor: AppColors.primaryGreen,
      shape: _shape,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.white,
      contentPadding: const EdgeInsets.all(16),
      hintStyle: body.copyWith(color: AppColors.textHint),
      border: _border(),
      enabledBorder: _border(),
      focusedBorder: _border(AppColors.primaryGreen, 1.5),
      errorBorder: _border(AppColors.error),
      focusedErrorBorder: _border(AppColors.error, 1.5),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: AppColors.buttonText,
        disabledBackgroundColor: AppColors.primaryGreen,
        disabledForegroundColor: AppColors.buttonText,
        minimumSize: _minSize,
        elevation: 0,
        shape: _shape,
        textStyle: skipText,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: outlined(ColorScheme.fromSeed(seedColor: AppColors.primaryGreen)),
    ),
  );

  static ThemeData authTheme(ThemeData base) => base.copyWith(
    colorScheme: base.colorScheme.copyWith(
      primary: AppColors.primaryGreen,
      onPrimary: AppColors.buttonText,
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        backgroundColor: AppColors.buttonGreen,
        foregroundColor: AppColors.buttonText,
        minimumSize: _minSize,
        side: BorderSide.none,
        shape: _shape,
        textStyle: buttonText,
      ),
    ),
  );
}