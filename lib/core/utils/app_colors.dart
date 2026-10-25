import 'package:flutter/material.dart';
 
 class AppColors {
  
 static const Color primaryGreen = Color(0xFF7BA88C);
  static const Color background = Color(0xFFF7F2EC);    
  static const Color surface = Color(0xFFFAF8F5);      
  static const Color textDark = Color(0xFF2C2C2C);
  static const Color textMuted = Color(0xFF6B6B6B);
  static const Color textHint = Color(0xFFA8A8A8);
  static const Color divider = Color(0xFFF0EDE5);
  static const Color accentHeart = Color(0xFFC29B72);   
  static const Color buttonText = Color(0xFFFFFFFF);

  static const Color dotInactive = Color(0xFFE0DCD3); 
  
  static const Color error = Color(0xFFD64545);
  static const Color success = Color(0xFF52B788);
  static const Color warning = Color(0xFFFFA500);
  
  static Color primaryGreenwithValues({required double opacity}) =>
      primaryGreen.withValues( alpha : opacity);
 }