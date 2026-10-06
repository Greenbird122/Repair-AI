import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:repairai/features/network/data/api_client.dart';
import 'package:repairai/features/network/data/api_exception.dart';
import 'package:repairai/features/network/data/auth_authenticator.dart';
import 'package:repairai/features/network/data/result.dart';
import 'package:repairai/features/network/data/token_storage.dart';

String _status(Object? json) =>
    (json! as Map<String, dynamic>)['status'] as String;

void main() {
  ApiClient clientWith(
    MockClientHandler handler, {
    Duration timeout = const Duration(seconds: 5),
  }) =>
      ApiClient(
        baseUrl: 'https://test',
        httpClient: MockClient(handler),
        timeout: timeout,
      );

  test('decodes a successful body into Data', () async {
    final client = clientWith(
      (_) async => http.Response('{"status":"ok"}', 200),
    );

    final result = await client.get('/api/app-version/', decode: _status);

    expect(result, isA<Data<String>>());
    expect((result as Data<String>).value, 'ok');
  });

  test('carries status and server message on a http failure', () async {
    final client = clientWith(
      (_) async => http.Response('{"detail":"nope"}', 500),
    );

    final result = await client.get('/x/', decode: _status);

    expect(result, isA<Error<String>>());
    final error = (result as Error<String>).error as ApiException;
    expect(error.kind, ApiFailureKind.http);
    expect(error.statusCode, 500);
    expect(error.message, 'nope');
  });

  test('reports a non-JSON success body as malformed', () async {
    final client = clientWith(
      (_) async => http.Response('<html>oops</html>', 200),
    );

    final result = await client.get('/x/', decode: _status);

    expect(result, isA<Error<String>>());
    final error = (result as Error<String>).error as ApiException;
    expect(error.kind, ApiFailureKind.malformed);
  });

  test('reports a decoder failure as malformed', () async {
    final client = clientWith(
      (_) async => http.Response('{"wrong":"shape"}', 200),
    );

    final result = await client.get('/x/', decode: _status);

    expect(result, isA<Error<String>>());
    expect(
      (result as Error<String>).error as ApiException,
      isA<ApiException>(),
    );
  });

  test('an unreachable host reads as Offline', () async {
    final client = clientWith(
      (_) async => throw const SocketException('down'),
    );

    final result = await client.get('/x/', decode: _status);

    expect(result, isA<Offline<String>>());
  });

  test('a blocked request reads as Offline', () async {
    final client = clientWith(
      (_) async => throw http.ClientException('blocked'),
    );

    final result = await client.get('/x/', decode: _status);

    expect(result, isA<Offline<String>>());
  });

  test('a stalled request times out into Offline', () async {
    final client = clientWith(
      (_) async => Completer<http.Response>().future,
      timeout: const Duration(milliseconds: 30),
    );

    final result = await client.get('/x/', decode: _status);

    expect(result, isA<Offline<String>>());
  });

  test('sends the stored bearer token', () async {
    final storage = InMemoryTokenStorage();
    await storage.save(accessToken: 'abc', refreshToken: 'r');
    String? seen;
    final mock = MockClient((request) async {
      seen = request.headers['Authorization'];
      return http.Response('{"status":"ok"}', 200);
    });
    final client = ApiClient(
      baseUrl: 'https://test',
      httpClient: mock,
      authenticator: JwtAuthenticator(
        baseUrl: 'https://test',
        storage: storage,
        httpClient: mock,
      ),
    );

    await client.get('/x/', decode: _status);

    expect(seen, 'Bearer abc');
  });

  test('a 401 refreshes once and retries with the new token', () async {
    final storage = InMemoryTokenStorage();
    await storage.save(accessToken: 'stale', refreshToken: 'r1');
    final attempts = <http.Request>[];
    var refreshes = 0;

    final mock = MockClient((request) async {
      if (request.url.path == '/api/auth/refresh/') {
        refreshes++;
        return http.Response('{"access":"fresh"}', 200);
      }
      attempts.add(request);
      if (attempts.length == 1) {
        return http.Response('{"detail":"expired"}', 401);
      }
      return http.Response('{"status":"ok"}', 200);
    });
    final client = ApiClient(
      baseUrl: 'https://test',
      httpClient: mock,
      authenticator: JwtAuthenticator(
        baseUrl: 'https://test',
        storage: storage,
        httpClient: mock,
      ),
    );

    final result = await client.get('/api/thing/', decode: _status);

    expect(refreshes, 1);
    expect(attempts.length, 2);
    expect(attempts.first.headers['Authorization'], 'Bearer stale');
    expect(attempts.last.headers['Authorization'], 'Bearer fresh');
    expect((result as Data<String>).value, 'ok');
  });

  test('a 401 with a failed refresh surfaces the original error', () async {
    final storage = InMemoryTokenStorage();
    await storage.save(accessToken: 'stale', refreshToken: 'r1');
    var refreshes = 0;

    final mock = MockClient((request) async {
      if (request.url.path == '/api/auth/refresh/') {
        refreshes++;
        return http.Response('{"detail":"bad refresh"}', 400);
      }
      return http.Response('{"detail":"expired"}', 401);
    });
    final client = ApiClient(
      baseUrl: 'https://test',
      httpClient: mock,
      authenticator: JwtAuthenticator(
        baseUrl: 'https://test',
        storage: storage,
        httpClient: mock,
      ),
    );

    final result = await client.get('/api/thing/', decode: _status);

    expect(refreshes, 1);
    final error = (result as Error<String>).error as ApiException;
    expect(error.statusCode, 401);
  });

  test('POST JSON-encodes the body', () async {
    Object? seen;
    final client = clientWith((request) async {
      seen = request.body;
      return http.Response('{"status":"ok"}', 200);
    });

    await client.post('/x/', body: {'a': 1}, decode: _status);

    expect(seen, '{"a":1}');
  });
}
