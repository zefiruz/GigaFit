import 'dart:convert';
import 'api_client.dart';

class WorkoutService {
  final ApiClient _client = ApiClient();

  // --- 1. ПОЛУЧИТЬ ВСЕ ТРЕНИРОВКИ ---
  Future<List<dynamic>> getAllWorkouts() async {
    try {
      final response = await _client.get('/workout/all');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['data'] ?? []; // Возвращаем список тренировок
      }
      return [];
    } catch (e) {
      print('Сетевая ошибка getAllWorkouts: $e');
      return [];
    }
  }

  // --- 2. ПОЛУЧИТЬ ТРЕНИРОВКУ ПО ID ---
  Future<Map<String, dynamic>?> getWorkoutById(String id) async {
    try {
      final response = await _client.get('/workout/$id');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['data'];
      }
      return null;
    } catch (e) {
      print('Сетевая ошибка getWorkoutById: $e');
      return null;
    }
  }

  // --- 3. СОЗДАТЬ ТРЕНИРОВКУ (РУЧНОЙ ВВОД) ---
  Future<bool> createManualWorkout(Map<String, dynamic> workoutData) async {
    try {
      // workoutData должна содержать название, сложность и т.д. по твоей Go-модели
      final response = await _client.post('/workout', workoutData);
      return response.statusCode == 201 || response.statusCode == 200;
    } catch (e) {
      print('Сетевая ошибка createManualWorkout: $e');
      return false;
    }
  }

  // --- 4. СОЗДАТЬ ТРЕНИРОВКУ ЧЕРЕЗ ИИ (GigaChat) ---
  Future<Map<String, dynamic>?> createAIWorkout(String prompt) async {
    try {
      final response = await _client.post(
        '/workout/ai',
        {'prompt': prompt},
        // ИИ может генерировать ответ долго, даем ему 30 секунд!
        timeout: const Duration(seconds: 30), 
      );
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return data['data'] ?? data; // Возвращаем сгенерированную тренировку
      } else {
        print('Ошибка ИИ: ${response.body}');
        return null;
      }
    } catch (e) {
      print('Сетевая ошибка createAIWorkout: $e');
      return null;
    }
  }

  // --- 5. ОБНОВИТЬ МЕТАДАННЫЕ ТРЕНИРОВКИ (Название, описание) ---
  Future<bool> updateWorkoutMeta(String id, Map<String, dynamic> updateData) async {
    try {
      final response = await _client.patch('/workout/$id', updateData);
      return response.statusCode == 200;
    } catch (e) {
      print('Сетевая ошибка updateWorkoutMeta: $e');
      return false;
    }
  }

  // --- 6. ОБНОВИТЬ СПИСОК УПРАЖНЕНИЙ В ТРЕНИРОВКЕ ---
  Future<bool> updateWorkoutExercises(String id, List<Map<String, dynamic>> exercises) async {
    try {
      // Отправляем новый массив упражнений
      final response = await _client.put(
        '/workout/$id/exercises',
        {'exercises': exercises}, 
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Сетевая ошибка updateWorkoutExercises: $e');
      return false;
    }
  }

  // --- 7. УДАЛИТЬ ТРЕНИРОВКУ ---
  Future<bool> deleteWorkout(String id) async {
    try {
      final response = await _client.delete('/workout/$id');
      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      print('Сетевая ошибка deleteWorkout: $e');
      return false;
    }
  }
}