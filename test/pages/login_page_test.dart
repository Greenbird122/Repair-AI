import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:repairai/features/auth/logic/session_controller.dart';
import 'package:repairai/features/network/data/api_exception.dart';
import 'package:repairai/features/network/data/result.dart';
import 'package:repairai/pages/login_page.dart';

class _Stub extends StatelessWidget {
  const _Stub(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Text(label);
}

class _FakeSession extends SessionController {
  _FakeSession();

  final SessionState initial =
      const SessionState(status: SessionStatus.signedOut);
  Result<void>? loginResult;
  String? lastPhone;
  String? lastPassword;

  @override
  SessionState build() => initial;

  @override
  Future<Result<void>> login({
    required String phone,
    required String password,
  }) async {
    lastPhone = phone;
    lastPassword = password;
    final result = loginResult ?? const Data(null);
    if (result is Data<void>) {
      state = const SessionState(status: SessionStatus.signedIn);
    }
    return result;
  }
}

void main() {
  Future<_FakeSession> pumpLogin(
    WidgetTester tester, {
    String location = '/login',
    Result<void>? loginResult,
  }) async {
    final fake = _FakeSession()..loginResult = loginResult;
    final router = GoRouter(
      initialLocation: location,
      routes: [
        GoRoute(path: '/login', builder: (_, _) => const LoginPage()),
        GoRoute(path: '/home', builder: (_, _) => const _Stub('home page')),
        GoRoute(
          path: '/register',
          builder: (_, _) => const _Stub('register page'),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sessionProvider.overrideWith(() => fake)],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    return fake;
  }

  Future<void> fillAndSubmit(WidgetTester tester) async {
    await tester.enterText(find.byType(TextField).first, '+254700000000');
    await tester.enterText(find.byType(TextField).last, 'TestUser2026!');
    await tester.tap(find.widgetWithText(FilledButton, 'Log in'));
    await tester.pump();
  }

  testWidgets('shows the phone, password and register entry points',
      (tester) async {
    await pumpLogin(tester);

    expect(find.byType(TextField), findsNWidgets(2));
    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Log in'), findsOneWidget);
    expect(find.text('Create an account'), findsOneWidget);
  });

  testWidgets('an empty phone is guided, not sent', (tester) async {
    final fake = await pumpLogin(tester);

    await tester.tap(find.widgetWithText(FilledButton, 'Log in'));
    await tester.pump();

    expect(find.text('Enter your phone number.'), findsOneWidget);
    expect(fake.lastPhone, isNull);
  });

  testWidgets('an empty password is guided, not sent', (tester) async {
    final fake = await pumpLogin(tester);

    await tester.enterText(find.byType(TextField).first, '+254700000000');
    await tester.tap(find.widgetWithText(FilledButton, 'Log in'));
    await tester.pump();

    expect(find.text('Enter your password.'), findsOneWidget);
    expect(fake.lastPhone, isNull);
  });

  testWidgets('a rejected login shows the server message and stays',
      (tester) async {
    final fake = await pumpLogin(
      tester,
      loginResult: const Error<void>(
        ApiException(
          ApiFailureKind.http,
          statusCode: 401,
          message: 'No active account found',
        ),
      ),
    );

    await fillAndSubmit(tester);

    expect(find.text('No active account found'), findsOneWidget);
    expect(find.byType(LoginPage), findsOneWidget);
    expect(fake.lastPhone, '+254700000000'); // trimmed before sending
  });

  testWidgets('offline explains itself instead of blaming the password',
      (tester) async {
    await pumpLogin(tester, loginResult: const Offline<void>());

    await fillAndSubmit(tester);

    expect(
      find.text('You are offline. Check your connection and try again.'),
      findsOneWidget,
    );
    expect(find.byType(LoginPage), findsOneWidget);
  });

  testWidgets('a successful login hands off to home', (tester) async {
    final fake = await pumpLogin(tester);

    await fillAndSubmit(tester);
    await tester.pumpAndSettle();

    expect(find.text('home page'), findsOneWidget);
    expect(fake.lastPassword, 'TestUser2026!');
  });

  testWidgets('the register link opens registration', (tester) async {
    await pumpLogin(tester);

    await tester.tap(find.text('Create an account'));
    await tester.pumpAndSettle();

    expect(find.text('register page'), findsOneWidget);
  });

  testWidgets('a phone passed via the query lands in the field',
      (tester) async {
    await pumpLogin(tester, location: '/login?phone=%2B254711111111');

    final field = tester.widget<TextField>(find.byType(TextField).first);
    expect(field.controller!.text, '+254711111111');
  });
}
