import 'package:flutter/material.dart';

const _bg = Color(0xFF0B1020);
const _surface = Color(0xFF151B30);
const accent = Color(0xFF8FA8FF);

final nightTheme = ThemeData(
  brightness: Brightness.dark,
  scaffoldBackgroundColor: _bg,
  colorScheme: const ColorScheme.dark(
    primary: accent,
    onPrimary: _bg,
    surface: _bg,
    surfaceContainer: _surface,
    surfaceContainerHigh: Color(0xFF1E2642),
  ),
  appBarTheme: const AppBarTheme(backgroundColor: _bg, centerTitle: false),
  cardTheme: const CardThemeData(
    color: _surface,
    margin: EdgeInsets.zero,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      minimumSize: const Size.fromHeight(52),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(14))),
      textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
    ),
  ),
);
