import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Импорты экранов и темы
import 'screens/auth/login_screen.dart';
import 'screens/home/main_screen.dart'; 
import 'widgets/theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Проверяем токен для авторизации
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('jwt_token');

  // Определяем стартовый экран
  final Widget initialScreen = (token != null && token.isNotEmpty)
      ? const MainScreen()
      : const LoginScreen();

  runApp(MyApp(initialScreen: initialScreen));
}

class MyApp extends StatelessWidget {
  final Widget initialScreen;

  const MyApp({super.key, required this.initialScreen});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GigaFit',
      debugShowCheckedModeBanner: false, 
      theme: AppTheme.dark, 
      home: initialScreen,
    );
  }
}