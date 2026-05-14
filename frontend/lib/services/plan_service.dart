import 'dart:convert';
import 'api_client.dart';

class PlanService {
  final ApiClient _client = ApiClient();

  // --- 1. СОЗДАТЬ ПЛАН ТРЕНИРОВОК ---
  Future<bool> createPlan(Map<String, dynamic> planData) async {
    try {
      final response = await _client.post('/plan', planData);
      return response.statusCode == 201 || response.statusCode == 200;
    } catch (e) {
      print('--- [HTTP] Ошибка при создании плана: $e ---');
      return false;
    }
  }

  // --- 2. ПОЛУЧИТЬ ВСЕ ПЛАНЫ ПОЛЬЗОВАТЕЛЯ ---
  Future<List<dynamic>> getAllPlans() async {
    try {
      final response = await _client.get('/plan/all');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['data'] ?? [];
      }
      return [];
    } catch (e) {
      print('--- [HTTP] Ошибка при получении планов: $e ---');
      return [];
    }
  }

   Future<List<dynamic>> getAllSystemPlans() async {
    try {
      final response = await _client.get('/plan/system');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['data'] ?? [];
      }
      return [];
    } catch (e) {
      print('--- [HTTP] Ошибка при получении планов: $e ---');
      return [];
    }
  }

  // --- 3. ПОЛУЧИТЬ ПЛАН ПО ID ---
  Future<Map<String, dynamic>?> getPlanById(String id) async {
    try {
      final response = await _client.get('/plan/$id');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['data'];
      }
      return null;
    } catch (e) {
      print('--- [HTTP] Ошибка при получении плана по ID: $e ---');
      return null;
    }
  }

  // --- 4. ОБНОВИТЬ ПЛАН (PATCH) ---
  Future<bool> updatePlan(String id, Map<String, dynamic> updateData) async {
    try {
      final response = await _client.patch('/plan/$id', updateData);
      return response.statusCode == 200;
    } catch (e) {
      print('--- [HTTP] Ошибка при обновлении плана: $e ---');
      return false;
    }
  }

  // --- 5. УДАЛИТЬ ПЛАН ---
  Future<bool> deletePlan(String id, {bool hard = false}) async {
    try {
      final endpoint = hard ? '/plan/$id?hard=true' : '/plan/$id';
      final response = await _client.delete(endpoint);

      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      print('Сетевая ошибка deletePlan: $e');
      return false;
    }
  }
}