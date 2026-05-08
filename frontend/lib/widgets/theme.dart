// import 'package:flutter/material.dart';
// import 'package:google_fonts/google_fonts.dart';

// class AppColors {
//   // 1. ФОНЫ: Темно-серые, строгие (не чисто черный)
//   static const Color background = Color(0xFF1C1C1E); // Основной фон (глубокий темно-серый)
//   static const Color surface = Color(0xFF242426);    // Поверхности (нижнее меню, модальные окна)
//   static const Color card = Color(0xFF2C2C2E);       // Карточки (чуть светлее для объема)

//   // 2. ГЛАВНЫЙ АКЦЕНТ: Спокойный приглушенный зеленый (Оливковый/Шалфей)
//   static const Color primary = Color(0xFF5B8266);
//   static const Color primaryDark = Color(0xFF45664E);

//   // 3. СМЫСЛОВЫЕ ЦВЕТА (Типы контента)
//   static const Color system = Color(0xFF547A9B);     // Стальной синий (для системных планов и каталога)
//   static const Color personal = Color(0xFFB0B0B0);   // Благородный светло-серый (для своих программ)

//   // 4. ТЕКСТ
//   static const Color textPrimary = Color(0xFFEBEBEB); // Мягкий белый (не бьет по глазам)
//   static const Color textSecondary = Color(0xFF8E8E93); // Спокойный серый для описаний

//   // 5. ОШИБКИ И УДАЛЕНИЕ
//   static const Color error = Color(0xFFB35A5A);       // Приглушенный красный (кирпичный)
// }

// class AppTheme {
//   static ThemeData get dark {
//     return ThemeData(
//       useMaterial3: true,
//       brightness: Brightness.dark,
//       scaffoldBackgroundColor: AppColors.background,

//       // Базовая цветовая схема
//       colorScheme: const ColorScheme.dark(
//         primary: AppColors.primary,
//         secondary: AppColors.primaryDark,
//         surface: AppColors.surface,
//         error: AppColors.error,
//         background: AppColors.background,
//       ),

//       // Шрифты: Poppins остается, но благодаря новым цветам будет выглядеть строже
//       textTheme: GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme).copyWith(
//         bodyLarge: const TextStyle(color: AppColors.textPrimary),
//         bodyMedium: const TextStyle(color: AppColors.textSecondary),
//         titleLarge: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
//       ),

//       // Настройка верхней панели (AppBar)
//       appBarTheme: AppBarTheme(
//         backgroundColor: AppColors.background,
//         elevation: 0,
//         centerTitle: true,
//         iconTheme: const IconThemeData(color: AppColors.textPrimary),
//         titleTextStyle: GoogleFonts.poppins(
//           color: AppColors.textPrimary,
//           fontSize: 20,
//           fontWeight: FontWeight.w500, // Сделали чуть тоньше (w500 вместо w600) для строгости
//         ),
//       ),

//       // Настройка карточек (Тень стала мягче, углы чуть строже)
//       cardTheme: CardThemeData(
//         color: AppColors.card,
//         elevation: 4, // Уменьшили тень для более "плоского" и современного дизайна
//         shadowColor: Colors.black.withOpacity(0.3),
//         shape: RoundedRectangleBorder(
//           borderRadius: BorderRadius.circular(16), // Чуть менее круглые углы (было 20)
//         ),
//       ),

//       // Настройка главных кнопок
//       elevatedButtonTheme: ElevatedButtonThemeData(
//         style: ElevatedButton.styleFrom(
//           backgroundColor: AppColors.primary,
//           // Текст теперь белый (на приглушенном зеленом черный читается плохо и выглядит грязно)
//           foregroundColor: Colors.white,
//           elevation: 0,
//           padding: const EdgeInsets.symmetric(vertical: 16),
//           shape: RoundedRectangleBorder(
//             borderRadius: BorderRadius.circular(12), // Строгие кнопки
//           ),
//           textStyle: GoogleFonts.poppins(
//             fontWeight: FontWeight.w600,
//             fontSize: 16,
//             letterSpacing: 0.5, // Немного разрядили буквы для премиальности
//           ),
//         ),
//       ),

//       // Текстовые кнопки
//       textButtonTheme: TextButtonThemeData(
//         style: TextButton.styleFrom(
//           foregroundColor: AppColors.primary,
//           textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w500),
//         ),
//       ),

//       // Настройка полей ввода (Логин/Регистрация/Чат)
//       inputDecorationTheme: InputDecorationTheme(
//         filled: true,
//         fillColor: AppColors.surface, // Поля чуть темнее карточек, но светлее фона
//         hintStyle: const TextStyle(color: AppColors.textSecondary),
//         labelStyle: const TextStyle(color: AppColors.textSecondary),
//         contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
//         border: OutlineInputBorder(
//           borderRadius: BorderRadius.circular(12),
//           borderSide: BorderSide.none,
//         ),
//         focusedBorder: OutlineInputBorder(
//           borderRadius: BorderRadius.circular(12),
//           borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
//         ),
//         prefixIconColor: AppColors.textSecondary,
//         suffixIconColor: AppColors.textSecondary,
//       ),

//       // Нижнее навигационное меню
//       bottomNavigationBarTheme: const BottomNavigationBarThemeData(
//         backgroundColor: AppColors.surface,
//         selectedItemColor: AppColors.primary,
//         unselectedItemColor: AppColors.textSecondary,
//         type: BottomNavigationBarType.fixed,
//         elevation: 0,
//         showUnselectedLabels: true,
//         selectedLabelStyle: TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
//         unselectedLabelStyle: TextStyle(fontWeight: FontWeight.w400, fontSize: 12),
//       ),
//     );
//   }
// }

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  // Backgrounds
  static const Color background = Color(0xFF0F1115);
  static const Color surface = Color(0xFF16181D);
  static const Color card = Color(0xFF1B1E24);

  // Accent
  static const Color primary = Color(0xFF8BAE5A);
  static const Color primaryDark = Color(0xFF6E8F46);

  // Secondary accents
  static const Color system = Color(0xFF6CA6FF);
  static const Color personal = Color(0xFFAEB6C2);

  // Text
  static const Color textPrimary = Color(0xFFF5F7FA);
  static const Color textSecondary = Color(0xFF8B93A1);

  // States
  static const Color error = Color(0xFFFF6B6B);

  // Borders
  static const Color border = Color(0xFF2A2E36);
}

class AppTheme {
  static ThemeData get dark {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,

      scaffoldBackgroundColor: AppColors.background,

      colorScheme: const ColorScheme.dark(
        primary: AppColors.primary,
        surface: AppColors.surface,
        error: AppColors.error,
      ),

      textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme)
          .copyWith(
            bodyLarge: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 15,
            ),

            bodyMedium: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),

            titleLarge: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 20,
              letterSpacing: -0.3,
            ),
          ),

      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: true,

        titleTextStyle: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),

      cardTheme: CardThemeData(
        color: AppColors.card,
        elevation: 0,

        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),

          side: const BorderSide(color: AppColors.border, width: 1),
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,

          elevation: 0,

          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),

          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),

          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),
    );
  }
}
