import 'dart:convert';
import 'api_client.dart';

class ProfileService {
  final ApiClient _client = ApiClient();

  // --- 1. ПОЛУЧИТЬ ДАННЫЕ ПРОФИЛЯ ---
  Future<Map<String, dynamic>?> getProfile() async {
    try {
      final response = await _client.get('/profile');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // Предполагаем стандартную обертку твоего бэкенда { "status": "...", "data": {...} }
        return data['data']; 
      } else {
        print('Ошибка getProfile: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Сетевая ошибка getProfile: $e');
      return null;
    }
  }

  // --- 2. ОБНОВИТЬ ПРОФИЛЬ (например, имя) ---
  Future<bool> updateProfile({required String username}) async {
    try {
      final response = await _client.put(
        '/profile',
        {'username': username},
      );
      
      return response.statusCode == 200;
    } catch (e) {
      print('Сетевая ошибка updateProfile: $e');
      return false;
    }
  }

  // --- 3. ОБНОВИТЬ АНТРОПОМЕТРИЮ ---
  Future<bool> updateAnthropometry({
    required double weight,
    required double height,
    required String goal,
  }) async {
    try {
      final response = await _client.put(
        '/profile/anthropometry',
        {
          'weight': weight,
          'height': height,
          'goal': goal,
        },
      );
      
      return response.statusCode == 200;
    } catch (e) {
      print('Сетевая ошибка updateAnthropometry: $e');
      return false;
    }
  }

  // --- 4. ПОЛУЧИТЬ ПРОГРЕСС (Графики/История веса) ---
  Future<Map<String, dynamic>?> getProgress() async {
    try {
      final response = await _client.get('/profile/progress');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['data'];
      }
      return null;
    } catch (e) {
      print('Сетевая ошибка getProgress: $e');
      return null;
    }
  }

  // --- 5. ПОЛУЧИТЬ СТАТИСТИКУ (Количество тренировок и т.д.) ---
  Future<Map<String, dynamic>?> getStats() async {
    try {
      final response = await _client.get('/profile/stats');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['data'];
      }
      return null;
    } catch (e) {
      print('Сетевая ошибка getStats: $e');
      return null;
    }
  }
}