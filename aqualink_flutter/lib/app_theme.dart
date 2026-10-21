import 'package:flutter/material.dart';

class AppColors {
  static const brand50 = Color(0xFFE6F7FB);
  static const brand600 = Color(0xFF087F9D);
  static const brand700 = Color(0xFF06677F);
  static const emerald600 = Color(0xFF059669);
  static const amber400 = Color(0xFFFBBF24);
  static const slate50 = Color(0xFFF8FAFC);
  static const slate200 = Color(0xFFE2E8F0);
  static const slate100 = Color(0xFFF1F5F9);
  static const slate400 = Color(0xFF94A3B8);
  static const slate500 = Color(0xFF64748B);
  static const slate600 = Color(0xFF475569);
  static const slate700 = Color(0xFF334155);
  static const slate800 = Color(0xFF1E293B);
  static const slate900 = Color(0xFF0F172A);
}

ThemeData buildAppTheme() => ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: AppColors.brand600),
      scaffoldBackgroundColor: AppColors.slate100,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
