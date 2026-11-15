import 'package:flutter/material.dart';

class Colores {
  static const verdeOscuro = Color(0xFF0E3B2C);
  static const verde = Color(0xFF37B24D);
  static const lima = Color(0xFFC8E85A);
  static const fondo = Color(0xFFF3F5F1);
  static const tarjeta = Colors.white;
  static const borde = Color(0xFFE3E7E0);
  static const texto = Color(0xFF17251E);
  static const textoSuave = Color(0xFF6B7A72);
}

ThemeData temaApp() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colores.verde,
      primary: Colores.verde,
      surface: Colores.fondo,
    ),
    scaffoldBackgroundColor: Colores.fondo,
  );
  return base.copyWith(
    appBarTheme: const AppBarTheme(
      backgroundColor: Colores.verdeOscuro,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      color: Colores.tarjeta,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Colores.borde),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colores.borde),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: Colores.verde,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
  );
}
