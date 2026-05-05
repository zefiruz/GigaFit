import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  // Главные акценты: Яркий, спортивный зеленый (неоновый изумруд)
  static const Color primary = Color(0xFF00E676); 
  static const Color primaryDark = Color(0xFF00B259);
  
  // Темные оттенки для фона и карточек
  static const Color background = Color(0xFF0A0A0A); // Глубокий черный фон
  static const Color surface = Color(0xFF141414);    // Чуть светлее для нижнего меню
  static const Color card = Color(0xFF1C1C1E);       // Темно-серый для карточек (эффект глубины)
  
  // Текст
  static const Color textPrimary = Color(0xFFF5F5F5); // Почти белый для заголовков
  static const Color textSecondary = Color(0xFFA1A1A1); // Серый для описаний
  
  // Ошибки
  static const Color error = Color(0xFFFF4C4C);
}

class AppTheme {
  static ThemeData get dark {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.background,
      
      // Базовая цветовая схема
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primary,
        secondary: AppColors.primaryDark,
        surface: AppColors.surface,
        error: AppColors.error,
      ),
      
      // Шрифты: Poppins отлично смотрится в фитнес-аппках (он круглый и читаемый)
      textTheme: GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme).copyWith(
        bodyLarge: const TextStyle(color: AppColors.textPrimary),
        bodyMedium: const TextStyle(color: AppColors.textSecondary),
        titleLarge: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
      ),
      
      // Настройка верхней панели (AppBar)
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        titleTextStyle: GoogleFonts.poppins(
          color: AppColors.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
      
      // Настройка карточек (Тень и скругления)
      cardTheme: CardThemeData(
        color: AppColors.card,
        elevation: 8,
        shadowColor: Colors.black.withOpacity(0.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      
      // Настройка главных кнопок (Зеленый фон, черный текст)
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.black, // Текст на кнопке будет черным — это стиль!
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),

      // Текстовые кнопки
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
      ),
      
      // Настройка полей ввода (Логин/Регистрация/Чат)
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.card,
        hintStyle: const TextStyle(color: AppColors.textSecondary),
        labelStyle: const TextStyle(color: AppColors.textSecondary),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        prefixIconColor: AppColors.textSecondary,
        suffixIconColor: AppColors.textSecondary,
      ),
      
      // Нижнее навигационное меню (BottomNavigationBar)
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.surface,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 20,
        showUnselectedLabels: true,
      ),
    );
  }
}