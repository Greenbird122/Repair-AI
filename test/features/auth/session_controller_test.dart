import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:repairai/features/auth/logic/session_controller.dart';
import 'package:repairai/features/network/data/api_client.dart';
import 'package:repairai/features/network/data/api_exception.dart';
import 'package:repairai/features/network/data/result.dart';
import 'package:repairai/features/network/data/token_storage.dart';
import 'package:repairai/features/network/logic/network_providers.dart';

String _loginJson({bool mustChange = false}) => '{"access":"at","refresh":"rt",'
    '"user_id":103,"role":"patient",'
    '"must_change_password":${mustChange ? 'true' : 'false'},'
    '"full_name":"Test User","phone":"+254700000000"}';

String _profileJson({bool mustChange = false}) =>
    '{"id":103,"username":"254700000000","name":"Test User","email":"",'
    '"phone":"+254700000000","role":"patient","country":"KE",'
    '"facility_name":null,"must_change_password":'
    '${mustChange ? 'true' : 'false'},"is_verified":true,'
    '"profile_picture_url":null}';

class _BrokenStore implements TokenStorage {
  @override
  Future<String?> get accessToken async => throw StateError('boom');

  @override
  Future<String?> get refreshToken async => throw StateError('boom');

  @override
  Future<void> save({
    required String accessToken,
    required String refreshToken,
  }) async =>
      throw StateError('boom');

  @override
  Future<void> clear() async => throw StateError('boom');
}

void main() {
  ProviderContainer build({
    required MockClientHandler handler,
    TokenStorage? storage,
  }) {
    final container = ProviderContainer(
      overrides: [
        apiClientProvider.overrideWithValue(
          ApiClient(baseUrl: 'https://test', httpClient: MockClient(handler)),
        ),
        tokenStorageProvider.overrideWithValue(
          storage ?? InMemoryTokenStorage(),
        ),
      ],
    );
    addTearDown(container.dispose);
    // Providers are lazy: read the session now so hydration starts at
    // container creation, the way routerProvider's listener does in prod.
    container.read(sessionProvider);
    return container;
  }

  MockClientHandler route(Map<String, MockClientHandler> table,
          {Object? fallback}) =>
      (request) async {
        final handler = table[request.url.path];
        if (handler != null) return handler(request);
        if (fallback != null && fallback is Exception) throw fallback;
        return http.Response('{"detail":"not found"}', 404);
      };

  group('hydration', () {
    test('empty store resolves to signedOut', () async {
      final container = build(handler: route({}));

      expect(
        container.read(sessionProvider).status,
        SessionStatus.hydrating,
      );
      await pumpEventQueue();

      expect(container.read(sessionProvider).status, SessionStatus.signedOut);
    });

    test('stored tokens resolve to signedIn and load the profile', () async {
      final storage = InMemoryTokenStorage();
      await storage.save(accessToken: 'a', refreshToken: 'r');
      String? profileHits;
      final container = build(
        storage: storage,
        handler: route({
          '/api/auth/profile/': (request) async {
            profileHits = request.url.path;
            return http.Response(_profileJson(), 200);
          },
        }),
      );
      await pumpEventQueue();

      final state = container.read(sessionProvider);
      expect(state.status, SessionStatus.signedIn);
      expect(profileHits, '/api/auth/profile/');
      expect(state.profile?.fullName, 'Test User');
      expect(state.mustChangePassword, isFalse);
    });

    test('a forced password change arrives via the profile', () async {
      final storage = InMemoryTokenStorage();
      await storage.save(accessToken: 'a', refreshToken: 'r');
      final container = build(
        storage: storage,
        handler: route({
          '/api/auth/profile/': (_) async =>
              http.Response(_profileJson(mustChange: true), 200),
        }),
      );
      await pumpEventQueue();

      expect(container.read(sessionProvider).mustChangePassword, isTrue);
    });

    test('an unreadable store reads as signedOut, not a crash', () async {
      final container = build(
        handler: route({}),
        storage: _BrokenStore(),
      );
      await pumpEventQueue();

      expect(container.read(sessionProvider).status, SessionStatus.signedOut);
    });

    test('a failed profile fetch keeps the offline session signedIn',
        () async {
      final storage = InMemoryTokenStorage();
      await storage.save(accessToken: 'a', refreshToken: 'r');
      final container = build(
        storage: storage,
        handler: route({
          '/api/auth/profile/': (_) async =>
              throw http.ClientException('down'),
        }),
      );
      await pumpEventQueue();

      final state = container.read(sessionProvider);
      expect(state.status, SessionStatus.signedIn);
      expect(state.profile, isNull);
    });
  });

  group('login', () {
    test('persists the token pair and flips signedIn', () async {
      final container = build(
        handler: route({
          '/api/auth/login/': (_) async => http.Response(_loginJson(), 200),
          '/api/auth/profile/': (_) async => http.Response(_profileJson(), 200),
        }),
      );
      await pumpEventQueue();

      final result = await container
          .read(sessionProvider.notifier)
          .login(phone: '+254700000000', password: 'TestUser2026!');

      expect(result, isA<Data<void>>());
      final storage = container.read(tokenStorageProvider);
      expect(await storage.accessToken, 'at');
      expect(await storage.refreshToken, 'rt');
      expect(container.read(sessionProvider).status, SessionStatus.signedIn);
    });

    test('a rejected password surfaces the server message untouched',
        () async {
      final container = build(
        handler: route({
          '/api/auth/login/': (_) async => http.Response(
            '{"detail":"No active account found with the given credentials"}',
            401,
          ),
        }),
      );
      await pumpEventQueue();

      final result = await container
          .read(sessionProvider.notifier)
          .login(phone: '+254700000000', password: 'wrong');

      final error = (result as Error<void>).error as ApiException;
      expect(error.statusCode, 401);
      expect(error.message, contains('No active account'));
      expect(container.read(sessionProvider).status, SessionStatus.signedOut);
      expect(await container.read(tokenStorageProvider).accessToken, isNull);
    });

    test('offline login never signs anyone in', () async {
      final container = build(
        handler: route({}, fallback: http.ClientException('down')),
      );
      await pumpEventQueue();

      final result = await container
          .read(sessionProvider.notifier)
          .login(phone: 'p', password: 'w');

      expect(result, isA<Offline<void>>());
      expect(container.read(sessionProvider).status, SessionStatus.signedOut);
    });

    test('must_change_password arms the forced-change flag immediately',
        () async {
      final container = build(
        handler: route({
          '/api/auth/login/': (_) async =>
              http.Response(_loginJson(mustChange: true), 200),
          '/api/auth/profile/': (_) async =>
              http.Response(_profileJson(mustChange: true), 200),
        }),
      );
      await pumpEventQueue();

      await container
          .read(sessionProvider.notifier)
          .login(phone: 'p', password: 'w');

      expect(container.read(sessionProvider).mustChangePassword, isTrue);
    });
  });

  group('register', () {
    test('checks the phone, then sends the payload', () async {
      final hits = <String>[];
      final container = build(
        handler: route({
          '/api/auth/check-phone/': (request) async {
            hits.add(request.url.path);
            return http.Response('{"detail":"Phone number is available."}', 200);
          },
          '/api/auth/register/': (request) async {
            hits.add(request.url.path);
            return http.Response(
              '{"detail":"Registration successful.","user_id":104,'
              '"username":"user_1","role":"patient"}',
              201,
            );
          },
        }),
      );
      await pumpEventQueue();

      final result = await container.read(sessionProvider.notifier).register(
            country: 'Kenya',
            county: 'Nairobi',
            subCounty: 'Westlands',
            phone: '+254711111111',
            firstName: 'A',
            lastName: 'B',
            password: 'longenough1',
            passwordConfirm: 'longenough1',
          );

      expect(result, isA<Data<void>>());
      expect(hits, [
        '/api/auth/check-phone/',
        '/api/auth/register/',
      ]);
      expect(container.read(sessionProvider).status, SessionStatus.signedOut);
    });

    test('a taken phone aborts before register is ever called', () async {
      var registerCalls = 0;
      final container = build(
        handler: route({
          '/api/auth/check-phone/': (_) async => http.Response(
            '{"detail":"An account with this phone number already exists."}',
            400,
          ),
          '/api/auth/register/': (_) async {
            registerCalls++;
            return http.Response('{}', 201);
          },
        }),
      );
      await pumpEventQueue();

      final result = await container.read(sessionProvider.notifier).register(
            country: 'Kenya',
            county: 'Nairobi',
            subCounty: 'Westlands',
            phone: '+254711111111',
            firstName: 'A',
            lastName: 'B',
            password: 'longenough1',
            passwordConfirm: 'longenough1',
          );

      final error = (result as Error<void>).error as ApiException;
      expect(error.statusCode, 400);
      expect(error.message, contains('already exists'));
      expect(registerCalls, 0);
    });

    test('offline at check-phone never reaches register', () async {
      final hits = <String>[];
      final container = build(
        handler: (request) async {
          hits.add(request.url.path);
          throw http.ClientException('down');
        },
      );
      final notifier = container.read(sessionProvider.notifier);
      await pumpEventQueue();

      final result = await notifier.register(
        country: 'Kenya',
        county: 'Nairobi',
        subCounty: 'Westlands',
        phone: '+254711111111',
        firstName: 'A',
        lastName: 'B',
        password: 'longenough1',
        passwordConfirm: 'longenough1',
      );

      expect(result, isA<Offline<void>>());
      expect(hits, ['/api/auth/check-phone/']);
    });
  });

  group('changePassword', () {
    test('success clears the forced-change flag', () async {
      final storage = InMemoryTokenStorage();
      await storage.save(accessToken: 'a', refreshToken: 'r');
      final container = build(
        storage: storage,
        handler: route({
          '/api/auth/profile/': (_) async =>
              http.Response(_profileJson(mustChange: true), 200),
          '/api/auth/change-password/': (_) async =>
              http.Response('{"detail":"Password updated."}', 200),
        }),
      );
      await pumpEventQueue();
      expect(container.read(sessionProvider).mustChangePassword, isTrue);

      final result = await container.read(sessionProvider.notifier).changePassword(
            oldPassword: 'old',
            newPassword: 'newenough1',
            newPasswordConfirm: 'newenough1',
          );

      expect(result, isA<Data<void>>());
      expect(container.read(sessionProvider).mustChangePassword, isFalse);
      expect(container.read(sessionProvider).status, SessionStatus.signedIn);
    });

    test('failure keeps the flag set', () async {
      final storage = InMemoryTokenStorage();
      await storage.save(accessToken: 'a', refreshToken: 'r');
      final container = build(
        storage: storage,
        handler: route({
          '/api/auth/profile/': (_) async =>
              http.Response(_profileJson(mustChange: true), 200),
          '/api/auth/change-password/': (_) async => http.Response(
            '{"new_password":["This password is too common."]}',
            400,
          ),
        }),
      );
      await pumpEventQueue();

      final result = await container.read(sessionProvider.notifier).changePassword(
            oldPassword: 'old',
            newPassword: 'password',
            newPasswordConfirm: 'password',
          );

      expect(result, isA<Error<void>>());
      expect(container.read(sessionProvider).mustChangePassword, isTrue);
    });
  });

  group('logout', () {
    test('clears tokens and signs out even when revocation is offline',
        () async {
      final storage = InMemoryTokenStorage();
      await storage.save(accessToken: 'a', refreshToken: 'r');
      final container = build(
        storage: storage,
        handler: route({
          '/api/auth/profile/': (_) async => http.Response(_profileJson(), 200),
          '/api/auth/logout/': (_) async =>
              throw http.ClientException('down'),
        }),
      );
      await pumpEventQueue();
      expect(container.read(sessionProvider).status, SessionStatus.signedIn);

      final result = await container.read(sessionProvider.notifier).logout();

      expect(result, isA<Data<void>>());
      expect(await storage.accessToken, isNull);
      expect(await storage.refreshToken, isNull);
      expect(container.read(sessionProvider).status, SessionStatus.signedOut);
    });

    test('a profile fetch landing after logout cannot resurrect the session',
        () async {
      final storage = InMemoryTokenStorage();
      await storage.save(accessToken: 'a', refreshToken: 'r');
      final profile = Completer<http.Response>();
      final container = build(
        storage: storage,
        handler: route({
          '/api/auth/profile/': (_) async => profile.future,
        }),
      );
      await pumpEventQueue();
      expect(container.read(sessionProvider).status, SessionStatus.signedIn);

      await container.read(sessionProvider.notifier).logout();
      profile.complete(http.Response(_profileJson(), 200));
      await pumpEventQueue();

      expect(container.read(sessionProvider).status, SessionStatus.signedOut);
      expect(container.read(sessionProvider).profile, isNull);
    });
  });
}
