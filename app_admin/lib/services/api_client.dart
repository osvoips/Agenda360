import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config.dart';

/// Erro vindo da API — `message` já é o texto de `detail` (pt-BR) quando o
/// backend manda um, então pode ser exibido direto na UI.
class ApiException implements Exception {
  ApiException(this.statusCode, this.message);

  final int statusCode;
  final String message;

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient({http.Client? httpClient}) : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;

  /// Definido pelo AuthController depois do login; limpo no logout. Rotas
  /// autenticadas do backend ignoram X-Tenant-Slug (o tenant vem do
  /// token), mas mandamos o header sempre mesmo assim, por uniformidade.
  String? authToken;

  Uri _uri(String path, [Map<String, String>? query]) {
    return Uri.parse('${AppConfig.apiBaseUrl}$path').replace(queryParameters: query);
  }

  Map<String, String> get _headers {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'X-Tenant-Slug': AppConfig.tenantSlug,
    };
    final token = authToken;
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  Future<dynamic> get(String path, {Map<String, String>? query}) async {
    final response = await _httpClient.get(_uri(path, query), headers: _headers);
    return _decode(response);
  }

  Future<dynamic> post(String path, [Map<String, dynamic>? body]) async {
    final response = await _httpClient.post(
      _uri(path),
      headers: _headers,
      body: body == null ? null : jsonEncode(body),
    );
    return _decode(response);
  }

  Future<dynamic> put(String path, Map<String, dynamic> body) async {
    final response = await _httpClient.put(
      _uri(path),
      headers: _headers,
      body: jsonEncode(body),
    );
    return _decode(response);
  }

  Future<void> delete(String path) async {
    final response = await _httpClient.delete(_uri(path), headers: _headers);
    _decode(response);
  }

  dynamic _decode(http.Response response) {
    final isSuccess = response.statusCode >= 200 && response.statusCode < 300;

    dynamic decoded;
    if (response.body.isNotEmpty) {
      try {
        decoded = jsonDecode(utf8.decode(response.bodyBytes));
      } catch (_) {
        decoded = null;
      }
    }

    if (!isSuccess) {
      final detail = decoded is Map<String, dynamic> ? decoded['detail'] as String? : null;
      throw ApiException(
        response.statusCode,
        detail ?? 'Não foi possível completar a ação (${response.statusCode}).',
      );
    }

    return decoded;
  }
}
