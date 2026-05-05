import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiClient {
  final String baseUrl = 'http://192.168.31.69:8080/api/v1';

  // Метод для получения токена из памяти
  Future<Map<String, String>> _getHeaders({bool useAuth = true}) async {
    final headers = {'Content-Type': 'application/json'};
    if (useAuth) {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
    }
    return headers;
  }

  // Универсальный GET запрос
  Future<http.Response> get(String endpoint, {bool useAuth = true}) async {
    final headers = await _getHeaders(useAuth: useAuth);
    print('--- [HTTP GET] $endpoint ---');
    return await http
        .get(Uri.parse('$baseUrl$endpoint'), headers: headers)
        .timeout(const Duration(seconds: 10));
  }

  // Обновленный POST запрос (добавили параметр timeout)
  Future<http.Response> post(String endpoint, Map<String, dynamic> body, {bool useAuth = true, Duration timeout = const Duration(seconds: 10)}) async {
    final headers = await _getHeaders(useAuth: useAuth);
    print('--- [HTTP POST] $endpoint ---');
    return await http
        .post(Uri.parse('$baseUrl$endpoint'), headers: headers, body: jsonEncode(body))
        .timeout(timeout); // Используем переданный таймаут
  }

  // НОВЫЙ МЕТОД: PATCH запрос
  Future<http.Response> patch(String endpoint, Map<String, dynamic> body, {bool useAuth = true}) async {
    final headers = await _getHeaders(useAuth: useAuth);
    print('--- [HTTP PATCH] $endpoint ---');
    return await http
        .patch(Uri.parse('$baseUrl$endpoint'), headers: headers, body: jsonEncode(body))
        .timeout(const Duration(seconds: 10));
  }

  // НОВЫЙ МЕТОД: DELETE запрос
  Future<http.Response> delete(String endpoint, {bool useAuth = true}) async {
    final headers = await _getHeaders(useAuth: useAuth);
    print('--- [HTTP DELETE] $endpoint ---');
    return await http
        .delete(Uri.parse('$baseUrl$endpoint'), headers: headers)
        .timeout(const Duration(seconds: 10));
  }

  // Универсальный PUT запрос
  Future<http.Response> put(String endpoint, Map<String, dynamic> body, {bool useAuth = true}) async {
    final headers = await _getHeaders(useAuth: useAuth);
    print('--- [HTTP PUT] $endpoint ---');
    return await http
        .put(Uri.parse('$baseUrl$endpoint'), headers: headers, body: jsonEncode(body))
        .timeout(const Duration(seconds: 10));
  }
}