import 'dart:convert';
import 'api_client.dart';

class LogService {
  final ApiClient _client = ApiClient();

  // --- 1. ЗАПИСАТЬ РЕЗУЛЬТАТ ТРЕНИРОВКИ ---
  Future<bool> createLog(Map<String, dynamic> logData) async {
    try {
      // logData содержит id тренировки, потраченное время, калории, веса и т.д.
      final response = await _client.post('/log', logData);
      return response.statusCode == 201 || response.statusCode == 200;
    } catch (e) {
      print('--- [HTTP] Ошибка createLog: $e ---');
      return false;
    }
  }

  // --- 2. ПОЛУЧИТЬ ИСТОРИЮ ТРЕНИРОВОК ---
  Future<List<dynamic>> getAllLogs() async {
    try {
      final response = await _client.get('/log/all');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['data'] ?? [];
      }
      return [];
    } catch (e) {
      print('--- [HTTP] Ошибка getAllLogs: $e ---');
      return [];
    }
  }

  // --- 3. ПОЛУЧИТЬ СОВЕТ ОТ ИИ ПО РЕЗУЛЬТАТАМ ТРЕНИРОВКИ ---
  Future<String?> getAIAdvice(Map<String, dynamic> requestData) async {
    try {
      final response = await _client.post(
        '/log/ai-advice',
        requestData, // Передаем логи или вопросы для анализа
        timeout: const Duration(seconds: 30), // Ждем ответа нейросети
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // Предполагаем, что ИИ возвращает текст в поле advice или data
        return data['data'] != null ? data['data']['advice'] ?? data['data'] : null;
      }
      return null;
    } catch (e) {
      print('--- [HTTP] Ошибка getAIAdvice: $e ---');
      return null;
    }
  }
}