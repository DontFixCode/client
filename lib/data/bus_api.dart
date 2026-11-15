import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';

import '../config/backend_config.dart';

typedef Json = Map<String, dynamic>;

class ApiException implements Exception {
  const ApiException(this.code, this.message, {this.status = 0, this.details});
  final String code, message;
  final int status;
  final dynamic details;
  @override
  String toString() => message;
}

class BusApi {
  BusApi({http.Client? client, String? baseUrl, required this.accessToken})
    : baseUrl = baseUrl ?? BackendConfig.apiUrl,
      _client = client ?? http.Client();
  final http.Client _client;
  final String baseUrl;
  final Future<String?> Function() accessToken;

  Uri uri(String path, [Map<String, String>? query]) =>
      Uri.parse('${baseUrl.replaceFirst(RegExp(r'/+$'), '')}/api/v1$path')
          .replace(queryParameters: query);

  Future<Json> request(
    String method,
    String path, {
    Json? body,
    Map<String, String>? query,
    String? idempotencyKey,
  }) async {
    final token = await accessToken();
    if (token == null) {
      throw const ApiException('AUTH_REQUIRED', '로그인 후 이용해 주세요.');
    }
    try {
      final req = http.Request(method, uri(path, query));
      req.headers.addAll({
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
        'Idempotency-Key': ?idempotencyKey,
      });
      if (body != null) req.body = jsonEncode(body);
      final response = await http.Response.fromStream(
        await _client.send(req).timeout(const Duration(seconds: 20)),
      ).timeout(const Duration(seconds: 20));
      final dynamic data = response.body.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(response.body);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final error = data is Map ? data['error'] : null;
        throw ApiException(
          error is Map
              ? error['code']?.toString() ?? 'HTTP_ERROR'
              : 'HTTP_ERROR',
          response.statusCode == 401
              ? '로그인이 만료되었어요. 다시 로그인해 주세요.'
              : error is Map
              ? error['message']?.toString() ?? '요청을 처리하지 못했어요.'
              : '서버 요청에 실패했어요.',
          status: response.statusCode,
          details: error is Map ? error['details'] : null,
        );
      }
      if (data is! Map<String, dynamic>) throw const FormatException();
      return data;
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw const ApiException('TIMEOUT', '응답이 늦어지고 있어요. 잠시 후 다시 시도해 주세요.');
    } on FormatException {
      throw const ApiException('INVALID_RESPONSE', '서버 응답 형식을 확인할 수 없어요.');
    } on http.ClientException {
      throw const ApiException(
        'NETWORK_ERROR',
        '서버에 연결할 수 없어요. 네트워크와 서버 주소를 확인해 주세요.',
      );
    }
  }

  WebSocketChannel connect(String journeyId) {
    final url = uri('/journeys/${Uri.encodeComponent(journeyId)}/stream');
    return WebSocketChannel.connect(
      url.replace(scheme: url.scheme == 'https' ? 'wss' : 'ws'),
    );
  }

  static String eventKey() {
    final random = Random.secure();
    return List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }

  void close() => _client.close();
}
