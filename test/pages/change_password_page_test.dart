import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:repairai/features/auth/logic/session_controller.dart';
import 'package:repairai/features/network/data/api_exception.dart';
import 'package:repairai/features/network/data/result.dart';
import 'package:repairai/pages/change_password_page.dart';

class _Stub extends StatelessWidget {
  const _Stub(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Text(label);
}

class _FakeSession extends SessionController {
  Result<void>? changeResult;
  int changeCalls = 0;
  int logoutCalls = 0;

  @override
  SessionState build() => const SessionState(
        status: SessionStatus.signedIn,
        mustChangePassword: true,
      );

  @override
  Future<Result<void>> changePassword({
    required String oldPassword,
    required String newPassword,
    required String newPasswordConfirm,
  }) async {
    changeCalls++;
    final result = changeResult ?? const Data(null);
    if (result is Data<void>) {
      state = const SessionState(status: SessionStatus.signedIn);
    }
    return result;
  }

  @override
  Future<Result<void>> logout() async {
    logoutCalls++;
    state = const SessionState(status: SessionStatus.signedOut);
    return const Data(null);
  }
}

void main() {
  Future<_FakeSession> pumpChange(
    WidgetTester tester, {
    Result<void>? changeResult,
    String location = '/change-password',
  }) async {
    final fake = _FakeSession()..changeResult = changeResult;
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final router = GoRouter(
      initialLocation: location,
      routes: [
        GoRoute(
          path: '/change-password',
          builder: (_, _) => const ChangePasswordPage(),
        ),
        GoRoute(path: '/home', builder: (_, _) => const _Stub('home page')),
        GoRoute(path: '/login', builder: (_, _) => const _Stub('login page')),
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

  Future<void> fillAndSubmit(
    WidgetTester tester, {
    String current = 'TestUser2026!',
    String fresh = 'brandnew123',
    String confirm = 'brandnew123',
  }) async {
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), current);
    await tester.enterText(fields.at(1), fresh);
    await tester.enterText(fields.at(2), confirm);
    await tester.tap(find.widgetWithText(FilledButton, 'Save password'));
    await tester.pump();
  }

  testWidgets('shows the three password fields and the escape hatch',
      (tester) async {
    await pumpChange(tester);

    expect(find.byType(TextField), findsNWidgets(3));
    expect(find.text('Set a new password'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Save password'), findsOneWidget);
    expect(find.text('Sign out instead'), findsOneWidget);
  });

  testWidgets('an empty current password is guided, not sent',
      (tester) async {
    final fake = await pumpChange(tester);

    await tester.tap(find.widgetWithText(FilledButton, 'Save password'));
    await tester.pump();

    expect(find.text('Enter your current password.'), findsOneWidget);
    expect(fake.changeCalls, 0);
  });

  testWidgets('a short new password is caught client-side', (tester) async {
    final fake = await pumpChange(tester);

    await fillAndSubmit(tester, fresh: 'short1', confirm: 'short1');

    expect(
      find.text('New password must be at least 8 characters.'),
      findsOneWidget,
    );
    expect(fake.changeCalls, 0);
  });

  testWidgets('mismatched passwords are caught client-side', (tester) async {
    final fake = await pumpChange(tester);

    await fillAndSubmit(tester, confirm: 'different1');

    expect(find.text('Passwords don\'t match.'), findsOneWidget);
    expect(fake.changeCalls, 0);
  });

  testWidgets('the server rejection is shown verbatim', (tester) async {
    final fake = await pumpChange(
      tester,
      changeResult: const Error<void>(
        ApiException(
          ApiFailureKind.http,
          statusCode: 400,
          message: 'old_password: This password is incorrect.',
        ),
      ),
    );

    await fillAndSubmit(tester);

    expect(find.text('old_password: This password is incorrect.'),
        findsOneWidget);
    expect(find.byType(ChangePasswordPage), findsOneWidget);
    expect(fake.changeCalls, 1);
  });

  testWidgets('offline explains itself', (tester) async {
    final fake =
        await pumpChange(tester, changeResult: const Offline<void>());

    await fillAndSubmit(tester);

    expect(
      find.text('You are offline. Check your connection and try again.'),
      findsOneWidget,
    );
    expect(fake.changeCalls, 1);
  });

  testWidgets('a successful change hands off to home', (tester) async {
    final fake = await pumpChange(tester);

    await fillAndSubmit(tester);
    await tester.pumpAndSettle();

    expect(find.text('home page'), findsOneWidget);
    expect(fake.changeCalls, 1);
  });

  testWidgets('sign out leaves for login without saving', (tester) async {
    final fake = await pumpChange(tester);

    await tester.tap(find.text('Sign out instead'));
    await tester.pumpAndSettle();

    expect(find.text('login page'), findsOneWidget);
    expect(fake.logoutCalls, 1);
    expect(fake.changeCalls, 0);
  });
}
