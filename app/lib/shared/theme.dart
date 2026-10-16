import 'package:flutter/material.dart';

/// Warna dari desain Figma (docs/figma) dan logo ReLa.
abstract final class RelaColors {
  static const primary = Color(0xFF356A90);
  static const cream = Color(0xFFF3DFC0); // kotak info, chip ringan
  static const sand = Color(0xFFDDBEA9); // avatar, chip berat
  static const border = Color(0xFFE6CBB5);
  static const paper = Color(0xFFFAF7F0); // judul akordeon, catatan
  static const danger = Color(0xFFB3261E);
  static const ink = Color(0xFF1C1A2E);
  static const muted = Color(0xFF6B6680);
  static const okBg = Color(0xFFDDEFEE);
  static const okText = Color(0xFF1D5E57);
}

final _round = RoundedRectangleBorder(borderRadius: BorderRadius.circular(20));
const _bigLabel = TextStyle(fontFamily: 'Roboto', fontSize: 18, fontWeight: FontWeight.w600);

/// Tombol besar selebar layar seperti di Figma. Tidak dipasang di tema global karena lebar penuh merusak tombol
/// di dialog dan di dalam Row.
final bigFilled = FilledButton.styleFrom(minimumSize: const Size.fromHeight(56), shape: _round, textStyle: _bigLabel);
final bigDanger = bigFilled.copyWith(backgroundColor: const WidgetStatePropertyAll(RelaColors.danger));
final bigOutlined = OutlinedButton.styleFrom(
  minimumSize: const Size.fromHeight(56),
  shape: _round,
  textStyle: _bigLabel,
  foregroundColor: RelaColors.ink,
);

final relaTheme = ThemeData(
  colorScheme: ColorScheme.fromSeed(seedColor: RelaColors.primary, primary: RelaColors.primary, surface: Colors.white),
  scaffoldBackgroundColor: Colors.white,
  appBarTheme: const AppBarTheme(backgroundColor: Colors.white, surfaceTintColor: Colors.transparent),
  cardTheme: CardThemeData(
    color: Colors.white,
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(24),
      side: const BorderSide(color: RelaColors.border),
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: RelaColors.border),
    ),
  ),
  navigationBarTheme: NavigationBarThemeData(
    backgroundColor: Colors.white,
    indicatorColor: Colors.transparent,
    iconTheme: WidgetStateProperty.resolveWith((s) =>
        IconThemeData(size: 30, color: s.contains(WidgetState.selected) ? RelaColors.primary : RelaColors.muted)),
    labelTextStyle: WidgetStateProperty.resolveWith((s) => TextStyle(
          color: s.contains(WidgetState.selected) ? RelaColors.primary : RelaColors.muted,
          fontWeight: s.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w400,
        )),
  ),
);
