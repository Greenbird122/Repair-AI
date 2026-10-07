import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:repairai/features/auth/logic/session_controller.dart';
import 'package:repairai/features/locations/data/location_api.dart';
import 'package:repairai/features/network/data/api_client.dart';
import 'package:repairai/features/network/data/api_exception.dart';
import 'package:repairai/features/network/data/result.dart';
import 'package:repairai/features/network/logic/network_providers.dart';
import 'package:repairai/pages/register_page.dart';

class _Stub extends StatelessWidget {
  const _Stub(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Text(label);
}

class _FakeSession extends SessionController {
  Result<void>? registerResult;
  String? lastCountry;
  String? lastCounty;
  String? lastSubCounty;
  String? lastPhone;
  String? lastFirstName;
  String? lastLastName;
  int registerCalls = 0;

  @override
  SessionState build() =>
      const SessionState(status: SessionStatus.signedOut);

  @override
  Future<Result<void>> register({
    required String country,
    required String county,
    required String subCounty,
    required String phone,
    required String firstName,
    required String lastName,
    required String password,
    required String passwordConfirm,
  }) async {
    registerCalls++;
    lastCountry = country;
    lastCounty = county;
    lastSubCounty = subCounty;
    lastPhone = phone;
    lastFirstName = firstName;
    lastLastName = lastName;
    return registerResult ?? const Data(null);
  }
}

Future<http.Response> _locations(http.Request request) async {
  switch (request.url.path) {
    case '/api/patients/locations/countries/':
      return http.Response(
        '[{"id":26,"name":"Kenya"},{"id":49,"name":"Tanzania"}]',
        200,
      );
    case '/api/patients/locations/counties/':
      if (request.url.queryParameters['country'] == 'Kenya') {
        return http.Response(
          '[{"id":1,"name":"Nairobi","country":26},'
          '{"id":2,"name":"Mombasa","country":26}]',
          200,
        );
      }
      return http.Response('[]', 200);
    case '/api/patients/locations/sub-counties/':
      return http.Response(
        '[{"id":10,"name":"Westlands","county":1},'
        '{"id":11,"name":"Kasarani","county":1}]',
        200,
      );
  }
  return http.Response('{"detail":"not found"}', 404);
}

void main() {
  Future<_FakeSession> pumpRegister(
    WidgetTester tester, {
    Result<void>? registerResult,
  }) async {
    final fake = _FakeSession()..registerResult = registerResult;
    // Long form: give it a phone-tall surface so nothing hides off-screen.
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final router = GoRouter(
      initialLocation: '/register',
      routes: [
        GoRoute(path: '/register', builder: (_, _) => const RegisterPage()),
        GoRoute(path: '/login', builder: (_, _) => const _Stub('login page')),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionProvider.overrideWith(() => fake),
          apiClientProvider.overrideWithValue(
            ApiClient(
              baseUrl: 'https://test',
              httpClient: MockClient(_locations),
            ),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    return fake;
  }

  Future<void> selectAt(WidgetTester tester, int index, String label) async {
    // The page ships DropdownButtonFormField<Place>; a bare type finder
    // matches the generic dynamic instantiation and finds nothing.
    await tester.tap(find.byType(DropdownButtonFormField<Place>).at(index));
    await tester.pumpAndSettle();
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  Future<void> fillValidForm(
    WidgetTester tester, {
    String password = 'longenough1',
    String confirm = 'longenough1',
  }) async {
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), '  Amina ');
    await tester.enterText(fields.at(1), 'Juma');
    await tester.enterText(fields.at(2), '+254711111111');
    await selectAt(tester, 0, 'Kenya');
    await selectAt(tester, 1, 'Nairobi');
    await selectAt(tester, 2, 'Westlands');
    await tester.enterText(fields.at(3), password);
    await tester.enterText(fields.at(4), confirm);
  }

  Future<void> submit(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
    await tester.pump();
  }

  testWidgets('shows identity, location and password fields',
      (tester) async {
    await pumpRegister(tester);

    expect(find.byType(TextField), findsNWidgets(5));
    expect(find.byType(DropdownButtonFormField<Place>), findsNWidgets(3));
    expect(find.text('Create your account'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Create account'), findsOneWidget);
  });

  testWidgets('county and sub-county stay shut until the parent is set',
      (tester) async {
    await pumpRegister(tester);

    // No country yet: tapping the county field opens nothing.
    await tester.tap(find.byType(DropdownButtonFormField<Place>).at(1));
    await tester.pumpAndSettle();
    expect(find.text('Mombasa'), findsNothing);

    await selectAt(tester, 0, 'Kenya');

    // Now the same field reaches the county list.
    await tester.tap(find.byType(DropdownButtonFormField<Place>).at(1));
    await tester.pumpAndSettle();
    expect(find.text('Nairobi'), findsOneWidget);
    await tester.tap(find.text('Nairobi'));
    await tester.pumpAndSettle();
    expect(find.text('Nairobi'), findsOneWidget); // closed with selection
  });

  testWidgets('changing country clears county and sub-county',
      (tester) async {
    await pumpRegister(tester);
    await fillValidForm(tester);
    expect(find.text('Nairobi'), findsOneWidget);
    expect(find.text('Westlands'), findsOneWidget);

    await selectAt(tester, 0, 'Tanzania');

    expect(find.text('Nairobi'), findsNothing);
    expect(find.text('Westlands'), findsNothing);
  });

  testWidgets('an empty form is guided, not sent', (tester) async {
    final fake = await pumpRegister(tester);

    await submit(tester);

    expect(find.text('Enter your first name.'), findsOneWidget);
    expect(fake.registerCalls, 0);
  });

  testWidgets('a missing selection blocks submission', (tester) async {
    final fake = await pumpRegister(tester);
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'Amina');
    await tester.enterText(fields.at(1), 'Juma');
    await tester.enterText(fields.at(2), '+254711111111');

    await submit(tester);

    expect(find.text('Select your country.'), findsOneWidget);
    expect(fake.registerCalls, 0);
  });

  testWidgets('a short password is caught client-side', (tester) async {
    final fake = await pumpRegister(tester);
    await fillValidForm(tester, password: 'short1', confirm: 'short1');

    await submit(tester);

    expect(
      find.text('Password must be at least 8 characters.'),
      findsOneWidget,
    );
    expect(fake.registerCalls, 0);
  });

  testWidgets('mismatched passwords are caught client-side', (tester) async {
    final fake = await pumpRegister(tester);
    await fillValidForm(tester, confirm: 'different1');

    await submit(tester);

    expect(find.text('Passwords don\'t match.'), findsOneWidget);
    expect(fake.registerCalls, 0);
  });

  testWidgets('a taken phone shows the server message and stays',
      (tester) async {
    final fake = await pumpRegister(
      tester,
      registerResult: const Error<void>(
        ApiException(
          ApiFailureKind.http,
          statusCode: 400,
          message:
              'phone: An account with this phone number already exists.',
        ),
      ),
    );
    await fillValidForm(tester);

    await submit(tester);

    expect(find.textContaining('already exists'), findsOneWidget);
    expect(find.byType(RegisterPage), findsOneWidget);
    expect(fake.registerCalls, 1);
  });

  testWidgets('offline explains itself instead of retrying forever',
      (tester) async {
    final fake = await pumpRegister(
      tester,
      registerResult: const Offline<void>(),
    );
    await fillValidForm(tester);

    await submit(tester);

    expect(
      find.text('You are offline. Check your connection and try again.'),
      findsOneWidget,
    );
    expect(fake.registerCalls, 1);
  });

  testWidgets('a successful registration hands the phone to login',
      (tester) async {
    final fake = await pumpRegister(tester);
    await fillValidForm(tester);

    await submit(tester);
    await tester.pumpAndSettle();

    expect(find.text('login page'), findsOneWidget);
    expect(fake.registerCalls, 1);
    expect(fake.lastCountry, 'Kenya');
    expect(fake.lastCounty, 'Nairobi');
    expect(fake.lastSubCounty, 'Westlands');
    expect(fake.lastPhone, '+254711111111');
    expect(fake.lastFirstName, 'Amina'); // trimmed
    expect(fake.lastLastName, 'Juma');
  });
}
