import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:repairai/features/auth/data/auth_api.dart';
import 'package:repairai/features/auth/logic/session_controller.dart';
import 'package:repairai/features/network/data/result.dart';
import 'package:repairai/pages/home_page.dart';

class _FakeSession extends SessionController {
  _FakeSession(this._initial);

  final SessionState _initial;
  int logoutCalls = 0;

  /// [Notifier.state] is protected; tests read it through this window.
  SessionState get currentState => state;

  @override
  SessionState build() => _initial;

  @override
  Future<Result<void>> logout() async {
    logoutCalls++;
    state = const SessionState(status: SessionStatus.signedOut);
    return const Data(null);
  }
}

const _profile = AuthProfile(
  id: 103,
  username: '254700000000',
  fullName: 'Test User',
  email: '',
  phone: '+254700000000',
  role: 'patient',
  country: 'KE',
  facilityName: null,
  mustChangePassword: false,
  isVerified: true,
  profilePictureUrl: null,
);

void main() {
  Future<_FakeSession> pumpHome(WidgetTester tester, SessionState session) async {
    final fake = _FakeSession(session);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sessionProvider.overrideWith(() => fake)],
        child: const MaterialApp(home: HomePage()),
      ),
    );
    await tester.pumpAndSettle();
    return fake;
  }

  testWidgets('greets the signed-in user by name', (tester) async {
    await pumpHome(
      tester,
      const SessionState(status: SessionStatus.signedIn, profile: _profile),
    );

    expect(find.text('Signed in as Test User'), findsOneWidget);
    expect(find.text('Heal · Support · Hope'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Sign out'), findsOneWidget);
  });

  testWidgets('falls back to a generic greeting while the profile loads',
      (tester) async {
    await pumpHome(
      tester,
      const SessionState(status: SessionStatus.signedIn),
    );

    expect(find.text('You are signed in'), findsOneWidget);
  });

  testWidgets('signing out goes through the session controller',
      (tester) async {
    final fake = await pumpHome(
      tester,
      const SessionState(status: SessionStatus.signedIn, profile: _profile),
    );

    await tester.tap(find.widgetWithText(OutlinedButton, 'Sign out'));
    await tester.pump();

    expect(fake.logoutCalls, 1);
    expect(fake.currentState.status, SessionStatus.signedOut);
  });
}
