import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';

class ApiService {
  // Используем твой локальный IPv4 адрес для работы через брандмауэр по Wi-Fi
  final String baseUrl = 'http://192.168.31.69:8080/api/v1';

  // --- АВТОРИЗАЦИЯ ---

  Future<String?> login(String email, String password) async {
    try {
      print('--- [HTTP] Отправка запроса на ВХОД для: $email ---');

      final response = await http
          .post(
            Uri.parse('$baseUrl/auth/login'),
            body: jsonEncode({'email': email, 'password': password}),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw Exception('Превышено время ожидания (Таймаут)');
            },
          );

      print('--- [HTTP] Ответ от сервера (ВХОД): ${response.statusCode} ---');
      print('--- [HTTP] Тело ответа: ${response.body} ---');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // В твоем бэкенде токен лежит в data['data']['token'], обрабатываем этот момент
        final token = data['data'] != null
            ? data['data']['token']
            : data['token'];

        if (token != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('jwt_token', token);
          return token;
        }
      }
      return null;
    } catch (e) {
      print('--- [HTTP] Сетевая ошибка при логине: $e ---');
      return null;
    }
  }

  Future<String?> register(
    String username,
    String email,
    String password,
  ) async {
    try {
      print('--- [HTTP] Отправка запроса на РЕГИСТРАЦИЮ для: $email ---');

      final response = await http
          .post(
            Uri.parse('$baseUrl/auth/register'),
            body: jsonEncode({
              'username': username,
              'email': email,
              'password': password,
            }),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw Exception('Превышено время ожидания (Таймаут)');
            },
          );

      print(
        '--- [HTTP] Ответ от сервера (РЕГИСТРАЦИЯ): ${response.statusCode} ---',
      );
      print('--- [HTTP] Тело ответа: ${response.body} ---');

      // Если всё отлично, возвращаем null (ошибок нет)
      if (response.statusCode == 201 || response.statusCode == 200) {
        return null;
      } else {
        // Если пришла ошибка, достаем её текст из JSON
        final data = jsonDecode(response.body);
        return data['message'] ?? 'Неизвестная ошибка сервера';
      }
    } catch (e) {
      print('--- [HTTP] Сетевая ошибка при регистрации: $e ---');
      return 'Сетевая ошибка: проверьте подключение';
    }
  }

  // --- ТРЕНИРОВКИ ---

  Future<List<Workout>> getWorkouts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');

      final response = await http
          .get(
            Uri.parse('$baseUrl/workout/all'),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => Workout.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      print('--- [HTTP] Ошибка при получении тренировок: $e ---');
      return [];
    }
  }

  // Запрос к GigaChat через твой бэкенд
  Future<Workout?> generateAIWorkout(String prompt) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');

      final response = await http
          .post(
            Uri.parse('$baseUrl/workout/ai'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({'prompt': prompt}),
          )
          .timeout(
            const Duration(seconds: 30),
          ); // ИИ может думать дольше, ставим 30 сек

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return Workout.fromJson(data);
      }
      return null;
    } catch (e) {
      print('--- [HTTP] Ошибка при обращении к ИИ: $e ---');
      return null;
    }
  }

  // --- УПРАЖНЕНИЯ ---

  Future<List<Exercise>> getExercises() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');

      final response = await http
          .get(
            Uri.parse('$baseUrl/exercise/all'),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> list =
            data; // Проверь, как бэк отдает массив (data или data['data'])
        return list.map((json) => Exercise.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      print('--- [HTTP] Ошибка при получении упражнений: $e ---');
      return [];
    }
  }
}
