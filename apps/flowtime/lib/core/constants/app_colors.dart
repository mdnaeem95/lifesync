import 'package:flutter/material.dart';

class AppColors {
  // Primary colors (gradient)
  static const Color primary = Color(0xFF6366F1);
  static const Color primaryDark = Color(0xFF8B5CF6);
  
  // Secondary colors
  static const Color secondary = Color(0xFF3B82F6);
  
  // Energy level colors
  static const Color energyHigh = Color(0xFF10B981);
  static const Color energyMedium = Color(0xFFF59E0B);
  static const Color energyLow = Color(0xFFEF4444);
  
  // Background colors
  static const Color backgroundDark = Color(0xFF0F0F1E);
  static const Color backgroundLight = Color(0xFFF5F5F5);
  
  // Surface colors
  static const Color surfaceDark = Color(0xFF1A1A2E);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  
  // Common colors
  static const Color error = Color(0xFFEF4444);
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  
  // Gradient definitions
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, primaryDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}