import 'dart:async';
import 'dart:convert';
import 'dart:io' show SocketException;

import 'package:http/http.dart' as http;

import 'api_exception.dart';
import 'auth_authenticator.dart';
import 'result.dart';

/// API root for this build. Override with `--dart-define=API_BASE_URL=...`;
/// the default is production. Read it from here and nowhere else.
const String apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'https://repairai.co.ke',
);

/// JSON GET/POST with bounded timeouts, bearer auth and one transparent
/// refresh retry on 401. Never throws: every outcome arrives as [Result].
class ApiClient {
  ApiClient({
    this.baseUrl = apiBaseUrl,
    http.Client? httpClient,
    this.authenticator,
    this.timeout = const Duration(seconds: 5),
  }) : _http = httpClient ?? http.Client();

  final String baseUrl;
  final Authenticator? authenticator;
  final Duration timeout;
  final http.Client _http;

  Future<Result<T>> get<T>(
    String path, {
    required T Function(Object? json) decode,
  }) =>
      _send('GET', path, decode: decode);

  Future<Result<T>> post<T>(
    String path, {
    Object? body,
    required T Function(Object? json) decode,
  }) =>
      _send('POST', path, body: body, decode: decode);

  void dispose() => _http.close();

  Future<Result<T>> _send<T>(
    String method,
    String path, {
    Object? body,
    required T Function(Object? json) decode,
  }) async {
    try {
      var response = await _attempt(method, path, body);
      if (response.statusCode == 401 && authenticator != null) {
        if (await authenticator!.refresh()) {
          response = await _attempt(method, path, body);
        }
      }
      return _map(response, decode);
    } on TimeoutException {
      return Offline<T>();
    } on SocketException {
      return Offline<T>();
    } on http.ClientException {
      return Offline<T>();
    }
  }

  Future<http.Response> _attempt(
    String method,
    String path,
    Object? body,
  ) async {
    final uri = Uri.parse('$baseUrl$path');
    final headers = <String, String>{'Content-Type': 'application/json'};
    final token = await authenticator?.accessToken;
    if (token != null) headers['Authorization'] = 'Bearer $token';

    final Future<http.Response> request = method == 'POST'
        ? _http.post(
            uri,
            headers: headers,
            body: body == null ? null : jsonEncode(body),
          )
        : _http.get(uri, headers: headers);
    return request.timeout(timeout);
  }

  Result<T> _map<T>(http.Response response, T Function(Object? json) decode) {
    if (response.statusCode >= 400) {
      return Error<T>(
        ApiException(
          ApiFailureKind.http,
          statusCode: response.statusCode,
          message: _serverMessage(response.body),
        ),
      );
    }
    try {
      return Data<T>(decode(jsonDecode(response.body)));
    } catch (error) {
      return Error<T>(
        ApiException(ApiFailureKind.malformed, message: error.toString()),
      );
    }
  }

  String? _serverMessage(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic>) return null;

      final detail = decoded['detail'];
      if (detail is String) return detail;

      // DRF field errors: {"password": ["This field is required."]}.
      final errors = <String>[];
      decoded.forEach((field, value) {
        final text = _firstMessage(value);
        if (text != null) errors.add('$field: $text');
      });
      return errors.isEmpty ? null : errors.join(' ');
    } on FormatException {
      return null;
    }
  }

  String? _firstMessage(Object? value) {
    if (value is String) return value;
    if (value is List && value.isNotEmpty) {
      final first = value.first;
      if (first is String) return first;
    }
    return null;
  }
}
