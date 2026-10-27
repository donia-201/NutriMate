import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTextStyles{
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
    fontWeight: FontWeight.w600,
    color: Colors.white, 
    
  );
    static const TextStyle skipText= TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.textDark, 
  );

}