import 'package:flutter/material.dart';

class AppTheme {
  static const Color primaryColor = Color(0xFF6C63FF); // Purple
  static const Color accentColor = Color(0xFF00BCD4);  // Teal
  static const Color premiumGold = Color(0xFFFFD700);   // For premium badges

  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    colorSchemeSeed: primaryColor,
    brightness: Brightness.light,
    appBarTheme: const AppBarTheme(
      centerTitle: true,
      elevation: 0,
    ),
    cardTheme: CardThemeData(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: primaryColor,
      foregroundColor: Colors.white,
    ),
  );

  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    colorSchemeSeed: primaryColor,
    brightness: Brightness.dark,
    appBarTheme: const AppBarTheme(
      centerTitle: true,
      elevation: 0,
    ),
    cardTheme: CardThemeData(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: primaryColor,
      foregroundColor: Colors.white,
    ),
  );

  // Difficulty colors
  static Color difficultyColor(String difficulty) {
    switch (difficulty) {
      case 'easy': return Colors.green;
      case 'medium': return Colors.orange;
      case 'advanced': return Colors.red;
      default: return Colors.grey;
    }
  }

  // Category colors
  static Color categoryColor(String category) {
    switch (category) {
      case 'boy': return const Color(0xFF42A5F5);
      case 'girl': return const Color(0xFFEC407A);
      case 'couple': return const Color(0xFFAB47BC);
      case 'aesthetic': return const Color(0xFFFF6D00); // Vibrant neon orange
      default: return primaryColor;
    }
  }

  // Category icons
  static IconData categoryIcon(String category) {
    switch (category) {
      case 'boy': return Icons.person;
      case 'girl': return Icons.person_outline;
      case 'couple': return Icons.people;
      case 'aesthetic': return Icons.auto_awesome;
      default: return Icons.photo_camera;
    }
  }
}
