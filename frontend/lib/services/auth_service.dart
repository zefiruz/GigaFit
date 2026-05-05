import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_client.dart'; // Импортируем наше базовое ядро

class AuthService {
  final ApiClient _client = ApiClient();

  // --- ВХОД ---
  Future<String?> login(String email, String password) async {
    try {
      // Используем метод post нашего клиента. 
      // useAuth: false означает, что мы не пытаемся прикрепить токен к этому запросу
      final response = await _client.post(
        '/auth/login',
        {'email': email, 'password': password},
        useAuth: false, 
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Достаем токен
        final token = data['data'] != null ? data['data']['token'] : data['token'];

        if (token != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('jwt_token', token);
          return token;
        }
      }
      print('Ошибка логина: ${response.statusCode} - ${response.body}');
      return null;
    } catch (e) {
      print('Сетевая ошибка при логине: $e');
      return null;
    }
  }

  // --- РЕГИСТРАЦИЯ ---
  // Возвращает null в случае успеха, или текст ошибки, если что-то пошло не так
  Future<String?> register(String username, String email, String password) async {
    try {
      final response = await _client.post(
        '/auth/register',
        {
          'username': username,
          'email': email,
          'password': password,
        },
        useAuth: false,
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        return null; // Нет ошибок
      } else {
        final data = jsonDecode(response.body);
        return data['message'] ?? 'Неизвестная ошибка сервера';
      }
    } catch (e) {
      print('Сетевая ошибка при регистрации: $e');
      return 'Сетевая ошибка: проверьте подключение';
    }
  }

  // --- ВЫХОД ИЗ АККАУНТА ---
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');
  }
}