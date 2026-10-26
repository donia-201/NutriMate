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
}

class AppTheme {
  static const TextStyle titleBold= TextStyle(
    fontSize:28,
    fontWeight: FontWeight.bold,
    color: AppColors.textDark,
    height: 1.2,
  );
  static const TextStyle subTitle= TextStyle(
    fontSize:15,
    fontWeight: FontWeight.w400,
    color: AppColors.textMuted,
    height: 1.2,
  );
  static const TextStyle buttonText= TextStyle(
    fontSize:16,
    fontWeight: FontWeight.bold,
    color: AppColors.buttonText,

  );
  static const TextStyle skipText= TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.textDark,
  );
  static const TextStyle label = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.textDark,
  );
  static const TextStyle body = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textDark,
  );
  static const TextStyle small = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.textMuted,
    height: 1.4,
  );
  static const _radius = BorderRadius.all(Radius.circular(16));
  static const _shape = RoundedRectangleBorder(borderRadius: _radius);
  static const _minSize = Size.fromHeight(48);

  static OutlineInputBorder _border([Color? color, double width = 1]) =>
      OutlineInputBorder(
        borderRadius: _radius,
        borderSide: color == null ? BorderSide.none : BorderSide(color: color, width: width),
      );

  static final outlinedStyle = OutlinedButton.styleFrom(
    backgroundColor: AppColors.white,
    foregroundColor: AppColors.textDark,
    minimumSize: _minSize,
    side: const BorderSide(color: AppColors.border),
    shape: _shape,
    textStyle: skipText,
  );


  static ThemeData get light => ThemeData(
    scaffoldBackgroundColor: AppColors.background,
    colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primaryGreen),
    textTheme: GoogleFonts.poppinsTextTheme(),
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
    outlinedButtonTheme: OutlinedButtonThemeData(style: outlinedStyle),
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