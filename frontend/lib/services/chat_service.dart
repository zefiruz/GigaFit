import 'dart:convert';
import 'api_client.dart';

class ChatService {
  final ApiClient _client = ApiClient();

  // --- 1. ОТПРАВИТЬ СООБЩЕНИЕ ---
  Future<Map<String, dynamic>?> sendMessage(String text) async {
    try {
      final response = await _client.post(
        '/chat/message',
        {'text': text}, // Убедись, что ключ ('text' или 'message') совпадает с тем, что ждет бэкенд
        timeout: const Duration(seconds: 30), // Ждем ответа от ИИ
      );
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return data['data'] ?? data;
      } else {
        print('--- [HTTP] Ошибка сервера при отправке сообщения: ${response.body} ---');
        return null;
      }
    } catch (e) {
      print('--- [HTTP] Ошибка sendMessage: $e ---');
      return null;
    }
  }

  // --- 2. ПОЛУЧИТЬ ИСТОРИЮ ЧАТА ---
  Future<List<dynamic>> getHistory() async {
    try {
      final response = await _client.get('/chat/history');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['data'] ?? [];
      }
      return [];
    } catch (e) {
      print('--- [HTTP] Ошибка getHistory: $e ---');
      return [];
    }
  }
}