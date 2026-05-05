import 'dart:convert';
import 'api_client.dart';

class ExerciseService {
  final ApiClient _client = ApiClient();

  // --- 1. ПОЛУЧИТЬ ВСЕ УПРАЖНЕНИЯ ---
  Future<List<dynamic>> getAllExercises() async {
    try {
      final response = await _client.get('/exercise/all');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['data'] ?? data; // В зависимости от того, как обернут ответ на бэке
      }
      return [];
    } catch (e) {
      print('Сетевая ошибка getAllExercises: $e');
      return [];
    }
  }

  // --- 2. ПОЛУЧИТЬ УПРАЖНЕНИЯ ПО ГРУППЕ МЫШЦ ---
  // Пример: getExercisesByMuscleGroup('Грудь')
  Future<List<dynamic>> getExercisesByMuscleGroup(String muscleGroup) async {
    try {
      final response = await _client.get('/exercise?muscle_group=$muscleGroup');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['data'] ?? data;
      }
      return [];
    } catch (e) {
      print('Сетевая ошибка getExercisesByMuscleGroup: $e');
      return [];
    }
  }

  // --- 3. ПОЛУЧИТЬ ОДНО УПРАЖНЕНИЕ ПО ID ---
  Future<Map<String, dynamic>?> getExerciseById(String id) async {
    try {
      final response = await _client.get('/exercise/$id');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['data'];
      }
      return null;
    } catch (e) {
      print('Сетевая ошибка getExerciseById: $e');
      return null;
    }
  }

  // --- 4. СОЗДАТЬ НОВОЕ УПРАЖНЕНИЕ ---
  Future<bool> createExercise(Map<String, dynamic> exerciseData) async {
    try {
      // exerciseData должна содержать name, muscle_group, description и т.д.
      final response = await _client.post('/exercise', exerciseData);
      return response.statusCode == 201 || response.statusCode == 200;
    } catch (e) {
      print('Сетевая ошибка createExercise: $e');
      return false;
    }
  }

  // --- 5. ОБНОВИТЬ УПРАЖНЕНИЕ ---
  Future<bool> updateExercise(String id, Map<String, dynamic> updateData) async {
    try {
      final response = await _client.put('/exercise/$id', updateData);
      return response.statusCode == 200;
    } catch (e) {
      print('Сетевая ошибка updateExercise: $e');
      return false;
    }
  }

  // --- 6. УДАЛИТЬ УПРАЖНЕНИЕ ---
  Future<bool> deleteExercise(String id) async {
    try {
      final response = await _client.delete('/exercise/$id');
      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      print('Сетевая ошибка deleteExercise: $e');
      return false;
    }
  }
}