import 'dart:async';
import 'dart:convert';
import 'dart:io' show SocketException;

import 'package:http/http.dart' as http;

import 'token_storage.dart';

/// Supplies the bearer token and exchanges an expired one for a fresh pair.
abstract interface class Authenticator {
  String? get accessToken;

  /// True once a new pair is stored. Concurrent callers share one in-flight
  /// exchange, so N simultaneous 401s cost exactly one refresh.
  Future<bool> refresh();
}

final class JwtAuthenticator implements Authenticator {
  JwtAuthenticator({
    required this.baseUrl,
    required this.storage,
    http.Client? httpClient,
    this.timeout = const Duration(seconds: 5),
  }) : _http = httpClient ?? http.Client();

  final String baseUrl;
  final TokenStorage storage;
  final Duration timeout;
  final http.Client _http;

  Future<bool>? _inFlight;

  @override
  String? get accessToken => storage.accessToken;

  @override
  Future<bool> refresh() =>
      _inFlight ??= _exchange().whenComplete(() => _inFlight = null);

  Future<bool> _exchange() async {
    final refreshToken = storage.refreshToken;
    if (refreshToken == null || refreshToken.isEmpty) return false;

    try {
      final response = await _http
          .post(
            Uri.parse('$baseUrl/api/auth/refresh/'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({'refresh': refreshToken}),
          )
          .timeout(timeout);

      if (response.statusCode >= 400) {
        await storage.clear();
        return false;
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        await storage.clear();
        return false;
      }

      final access = decoded['access'];
      if (access is! String || access.isEmpty) {
        await storage.clear();
        return false;
      }

      final rotated = decoded['refresh'];
      await storage.save(
        accessToken: access,
        refreshToken: rotated is String && rotated.isNotEmpty
            ? rotated
            : refreshToken,
      );
      return true;
    } on TimeoutException {
      return false;
    } on SocketException {
      return false;
    } on http.ClientException {
      return false;
    } on FormatException {
      await storage.clear();
      return false;
    }
  }
}
