import 'package:flutter/material.dart';

/// Calculator Vault visual identity: black / white / neutral gray with one
/// restrained accent color. Deliberately avoids "hacker" styling (matrix
/// green, neon, skulls) — a privacy utility should feel trustworthy, not
/// suspicious.
class AppTheme {
  static const _seed = Color(0xFF2F6FED); // single accent: calm blue

  static ThemeData get light => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: _seed, brightness: Brightness.light),
        scaffoldBackgroundColor: const Color(0xFFFAFAFA),
        appBarTheme: const AppBarTheme(centerTitle: false, elevation: 0),
      );

  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: _seed, brightness: Brightness.dark),
        scaffoldBackgroundColor: const Color(0xFF121212),
        appBarTheme: const AppBarTheme(centerTitle: false, elevation: 0),
      );
}
