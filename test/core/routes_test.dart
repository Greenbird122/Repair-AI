import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:repairai/core/routes.dart';
import 'package:repairai/features/auth/logic/session_controller.dart';

const _signedOut = SessionState(status: SessionStatus.signedOut);
const _signedIn = SessionState(status: SessionStatus.signedIn);
const _forcedChange =
    SessionState(status: SessionStatus.signedIn, mustChangePassword: true);
const _hydrating = SessionState();

class _AlwaysSignedIn extends SessionController {
  @override
  SessionState build() => _signedIn;
}

void main() {
  test('route table registers splash, auth and home', () {
    final GoRouter router = createRouter();

    final List<String> paths = router.configuration.routes
        .whereType<GoRoute>()
        .map((GoRoute r) => r.path)
        .toList();

    expect(
      paths,
      containsAll(<String>[
        '/',
        '/home',
        '/login',
        '/register',
        '/change-password',
      ]),
    );
  });

  test('router starts at the splash route', () {
    final GoRouter router = createRouter();

    expect(router.routeInformationProvider.value.uri.path, '/');
  });

  group('authRedirect', () {
    test('a hydrating session redirects nothing', () {
      for (final path in ['/', '/login', '/register', '/home']) {
        expect(authRedirect(_hydrating, path), isNull, reason: path);
      }
    });

    test('signed out keeps public paths and gates the rest', () {
      expect(authRedirect(_signedOut, '/'), isNull);
      expect(authRedirect(_signedOut, '/login'), isNull);
      expect(authRedirect(_signedOut, '/register'), isNull);
      expect(authRedirect(_signedOut, '/home'), '/login');
      expect(authRedirect(_signedOut, '/change-password'), '/login');
    });

    test('signed in leaves the auth screens behind', () {
      expect(authRedirect(_signedIn, '/login'), '/home');
      expect(authRedirect(_signedIn, '/register'), '/home');
      expect(authRedirect(_signedIn, '/home'), isNull);
      expect(authRedirect(_signedIn, '/change-password'), isNull);
      expect(authRedirect(_signedIn, '/'), isNull);
    });

    test('a forced password change traps every other path', () {
      expect(authRedirect(_forcedChange, '/change-password'), isNull);
      expect(authRedirect(_forcedChange, '/home'), '/change-password');
      expect(authRedirect(_forcedChange, '/login'), '/change-password');
      expect(authRedirect(_forcedChange, '/register'), '/change-password');
      expect(authRedirect(_forcedChange, '/'), '/change-password');
    });
  });

  testWidgets('a session change re-runs the guard without a rebuild',
      (tester) async {
    var session = _signedOut;
    final ping = ValueNotifier<int>(0);
    final router = createRouter(
      initialLocation: '/home',
      refreshListenable: ping,
      session: () => session,
    );
    addTearDown(router.dispose);
    addTearDown(ping.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sessionProvider.overrideWith(_AlwaysSignedIn.new)],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/login');

    session = _signedIn;
    ping.value++;
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/home');
  });
}
