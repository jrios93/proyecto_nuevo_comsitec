// import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:new_pro_com/config/theme/app_theme.dart';

// Un objeto de tipo AppTheme(custom)
class ThemeNotifier extends StateNotifier<AppTheme> {
  ThemeNotifier() : super(AppTheme()) {
    loadTheme();
  }

  Future<void> loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final isDarkmode = prefs.getBool('isDarkmode') ?? false;
    final selectedColor = prefs.getInt('selectedColor') ?? 0;

    state = AppTheme(isDarkmode: isDarkmode, selectedColor: selectedColor);
  }

  Future<void> toggleDarkMode() async {
    state = state.copyWith(isDarkmode: !state.isDarkmode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkmode', state.isDarkmode);
  }

  Future<void> changeColor(int colorIndex) async {
    state = state.copyWith(selectedColor: colorIndex);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('selectedColor', colorIndex);
  }

  Future<void> nextThemeColor() async {
    int nextColorIndex = (state.selectedColor + 1) % colorList.length;
    state = state.copyWith(selectedColor: nextColorIndex);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('selectedColor', nextColorIndex);
  }
}

final themeNotifierProvider = StateNotifierProvider<ThemeNotifier, AppTheme>(
  (ref) => ThemeNotifier(),
);
