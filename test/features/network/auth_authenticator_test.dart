import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:repairai/features/network/data/auth_authenticator.dart';
import 'package:repairai/features/network/data/token_storage.dart';

void main() {
  late InMemoryTokenStorage storage;

  JwtAuthenticator authWith(
    MockClientHandler handler, {
    Duration timeout = const Duration(seconds: 5),
  }) =>
      JwtAuthenticator(
        baseUrl: 'https://test',
        storage: storage,
        httpClient: MockClient(handler),
        timeout: timeout,
      );

  setUp(() async {
    storage = InMemoryTokenStorage();
    await storage.save(accessToken: 'old', refreshToken: 'r1');
  });

  test('exposes the stored access token', () async {
    final auth = authWith((_) async => http.Response('{}', 200));

    expect(await auth.accessToken, 'old');
  });

  test('refuses to refresh without a refresh token', () async {
    var calls = 0;
    final auth = JwtAuthenticator(
      baseUrl: 'https://test',
      storage: InMemoryTokenStorage(),
      httpClient: MockClient((_) async {
        calls++;
        return http.Response('{}', 200);
      }),
    );

    expect(await auth.refresh(), isFalse);
    expect(calls, 0);
  });

  test('stores the rotated pair when the server accepts', () async {
    final auth = authWith(
      (_) async => http.Response('{"access":"new","refresh":"r2"}', 200),
    );

    expect(await auth.refresh(), isTrue);
    expect(await storage.accessToken, 'new');
    expect(await storage.refreshToken, 'r2');
  });

  test('keeps the old refresh token when none is rotated', () async {
    final auth = authWith((_) async => http.Response('{"access":"new"}', 200));

    expect(await auth.refresh(), isTrue);
    expect(await storage.refreshToken, 'r1');
  });

  test('clears both tokens when the server rejects the refresh', () async {
    final auth = authWith((_) async => http.Response('{"detail":"bad"}', 400));

    expect(await auth.refresh(), isFalse);
    expect(await storage.accessToken, isNull);
    expect(await storage.refreshToken, isNull);
  });

  test('clears both tokens when the payload is not an object', () async {
    final auth = authWith((_) async => http.Response('"just a string"', 200));

    expect(await auth.refresh(), isFalse);
    expect(await storage.accessToken, isNull);
  });

  test('clears both tokens when the payload has no access token', () async {
    final auth = authWith((_) async => http.Response('{"access":""}', 200));

    expect(await auth.refresh(), isFalse);
    expect(await storage.accessToken, isNull);
  });

  test('concurrent refreshes share a single network call', () async {
    var calls = 0;
    final auth = authWith((_) async {
      calls++;
      await Future<void>.delayed(const Duration(milliseconds: 30));
      return http.Response('{"access":"new"}', 200);
    });

    final results = await Future.wait([
      auth.refresh(),
      auth.refresh(),
      auth.refresh(),
    ]);

    expect(calls, 1);
    expect(results, [true, true, true]);
    expect(await storage.accessToken, 'new');
  });

  test('a stalled refresh fails instead of hanging', () async {
    final auth = authWith(
      (_) async => Completer<http.Response>().future,
      timeout: const Duration(milliseconds: 30),
    );

    expect(await auth.refresh(), isFalse);
  });

  test('a socket failure reads as refresh failure', () async {
    final auth = authWith((_) async => throw const SocketException('down'));

    expect(await auth.refresh(), isFalse);
  });

  test('a client failure reads as refresh failure', () async {
    final auth = authWith((_) async => throw http.ClientException('blocked'));

    expect(await auth.refresh(), isFalse);
  });

  test('an unparseable body reads as refresh failure', () async {
    final auth = authWith((_) async => http.Response('not json', 200));

    expect(await auth.refresh(), isFalse);
    expect(await storage.accessToken, isNull);
  });
}
