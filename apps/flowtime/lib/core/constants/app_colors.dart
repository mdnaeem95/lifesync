import 'package:flutter/material.dart';

class AppColors {
  // Primary colors
  static const Color primary = Color(0xFF6366F1);
  static const Color primaryDark = Color(0xFF8B5CF6);
  static const Color primaryLight = Color(0xFF818CF8);
  
  // Task type colors
  static const Color focus = Color(0xFF3B82F6);
  static const Color meeting = Color(0xFF0EA5E9);    // Soft blue-teal
  static const Color admin = Color(0xFF6366F1);      // Muted indigo (uses your primary)
  static const Color breakTask = Color(0xFFFAE8B7);
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  
  // Background colors
  static const Color backgroundLight = Color(0xFFF8FAFC);
  static const Color backgroundDark = Color(0xFF0F0F1E);
  static const Color surfaceDark = Color(0xFF1A1A2E);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color cardDark = Color(0x0DFFFFFF); // 5% white
  static const Color cardLight = Color(0xFFF1F5F9);
  
  // Border colors
  static const Color borderSubtle = Color(0x1AFFFFFF); // 10% white
  static const Color borderSubtleLight = Color(0xFFE2E8F0);
  
  // Text colors
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xB3FFFFFF); // 70% white
  static const Color textTertiary = Color(0x80FFFFFF); // 50% white
  static const Color textPrimaryLight = Color(0xFF0F172A); // Almost black, high contrast but less harsh
  static const Color textSecondaryLight = Color(0xFF64748B); // Cool muted gray-blue
  static const Color textTertiaryLight = Color(0xFF94A3B8); 
  
  // Semantic colors
  static const Color info = Color(0xFF0EA5E9);
  static const Color secondary = Color(0xFF64748B);
  
  // Gradient definitions
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, primaryDark],
  );
  
  static const LinearGradient focusGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [focus, primary],
  );
  
  static const LinearGradient successGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [success, Color(0xFF059669)],
  );
}