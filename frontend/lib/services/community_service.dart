import 'dart:convert';
import 'api_client.dart';

class CommunityService {
  final ApiClient _client = ApiClient();

  // --- 1. ПОЛУЧИТЬ ЛЕНТУ (FEED) ---
  Future<List<dynamic>> getFeed() async {
    try {
      final response = await _client.get('/community/feed');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['data'] ?? []; // Возвращаем список постов ленты
      }
      return [];
    } catch (e) {
      print('--- [HTTP] Ошибка getFeed: $e ---');
      return [];
    }
  }

  // --- 2. ОПУБЛИКОВАТЬ ТРЕНИРОВКУ В ЛЕНТУ ---
  Future<bool> publishWorkout(String workoutId) async {
    try {
      final response = await _client.post('/community/publish/$workoutId', {});
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      print('--- [HTTP] Ошибка publishWorkout: $e ---');
      return false;
    }
  }

  // --- 3. ПОСТАВИТЬ ИЛИ УБРАТЬ ЛАЙК ---
  Future<bool> toggleLike(String workoutId) async {
    try {
      final response = await _client.post('/community/like/$workoutId', {});
      return response.statusCode == 200;
    } catch (e) {
      print('--- [HTTP] Ошибка toggleLike: $e ---');
      return false;
    }
  }

  // --- 4. СОХРАНИТЬ ЧУЖУЮ ТРЕНИРОВКУ К СЕБЕ ---
  Future<bool> saveWorkout(String workoutId) async {
    try {
      final response = await _client.post('/community/save/$workoutId', {});
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      print('--- [HTTP] Ошибка saveWorkout: $e ---');
      return false;
    }
  }
}