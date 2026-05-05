import 'dart:convert';
import 'api_client.dart';

class ChatService {
  final ApiClient _client = ApiClient();

  // Отправка сообщения
  Future<Map<String, dynamic>?> sendMessage(String message, {String? sessionId}) async {
    try {
      final Map<String, dynamic> body = {'message': message};
      if (sessionId != null) body['session_id'] = sessionId;

      final response = await _client.post('/chat/message', body, timeout: const Duration(seconds: 30));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['data']; // Вернет {session_id, reply}
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Получение истории по конкретной сессии
  Future<List<dynamic>> getHistory(String sessionId) async {
    try {
      final response = await _client.get('/chat/history?session_id=$sessionId');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['data'] ?? [];
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // --- ПОЛУЧИТЬ ПЕРСОНАЛИЗИРОВАННЫЙ СОВЕТ ПОСЛЕ ТРЕНИРОВКИ ---
  Future<String?> getWorkoutAdvice(int duration, String mood, String comment) async {
    try {
      final response = await _client.post(
        '/logs/advice', // <-- Укажи здесь точный маршрут из твоего main.go
        {
          'actual_duration_mins': duration,
          'mood': mood,
          'comment': comment,
        },
        timeout: const Duration(seconds: 30),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['data']['advice'];
      }
      return null;
    } catch (e) {
      print('Ошибка getWorkoutAdvice: $e');
      return null;
    }
  }
}

