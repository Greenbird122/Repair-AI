import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:repairai/features/auth/data/auth_api.dart';
import 'package:repairai/features/network/data/api_client.dart';
import 'package:repairai/features/network/data/api_exception.dart';
import 'package:repairai/features/network/data/result.dart';

void main() {
  late http.Request? seen;

  AuthApi apiWith(MockClientHandler handler) {
    seen = null;
    return AuthApi(
      ApiClient(
        baseUrl: 'https://test',
        httpClient: MockClient((request) async {
          seen = request;
          return handler(request);
        }),
      ),
    );
  }

  group('checkPhone', () {
    test('posts the phone and reads 200 as available', () async {
      final api = apiWith(
        (_) async => http.Response('{"detail":"Phone number is available."}', 200),
      );

      final result = await api.checkPhone('+254700000000');

      expect(seen!.url.path, AuthApi.checkPhonePath);
      expect(seen!.method, 'POST');
      expect(seen!.body, '{"phone":"+254700000000"}');
      expect(result, isA<Data<bool>>());
      expect((result as Data<bool>).value, isTrue);
    });

    test('reads 400 as taken with the server message', () async {
      final api = apiWith(
        (_) async => http.Response(
          '{"detail":"An account with this phone number already exists."}',
          400,
        ),
      );

      final result = await api.checkPhone('+254700000000');

      final error = (result as Error<bool>).error as ApiException;
      expect(error.statusCode, 400);
      expect(error.message, contains('already exists'));
    });
  });

  group('register', () {
    test('sends the proven payload with sub_county snake_cased', () async {
      final api = apiWith(
        (_) async => http.Response(
          '{"detail":"Registration successful.","user_id":104,'
          '"username":"user_1","role":"patient"}',
          201,
        ),
      );

      final result = await api.register(
        country: 'Kenya',
        county: 'Nairobi',
        subCounty: 'Westlands',
        phone: '+254711111111',
        firstName: 'A',
        lastName: 'B',
        password: 'longenough1',
        passwordConfirm: 'longenough1',
      );

      expect(seen!.url.path, AuthApi.registerPath);
      final body = seen!.body;
      expect(body, contains('"sub_county":"Westlands"'));
      expect(body, contains('"country":"Kenya"'));
      expect(body, contains('"password_confirm":"longenough1"'));
      expect(body, isNot(contains('subCounty')));
      final registration = (result as Data<Registration>).value;
      expect(registration.userId, 104);
      expect(registration.username, 'user_1');
      expect(registration.role, 'patient');
    });

    test('surfaces DRF field errors as readable text', () async {
      final api = apiWith(
        (_) async => http.Response(
          '{"country":["This field is required."],'
          '"password":["This password is too short."]}',
          400,
        ),
      );

      final result = await api.register(
        country: '',
        county: '',
        subCounty: '',
        phone: '',
        firstName: '',
        lastName: '',
        password: '',
        passwordConfirm: '',
      );

      final error = (result as Error<Registration>).error as ApiException;
      expect(error.statusCode, 400);
      expect(error.message, 'country: This field is required. '
          'password: This password is too short.');
    });
  });

  group('login', () {
    const body = '{"access":"at","refresh":"rt","user_id":7,'
        '"role":"patient","must_change_password":true,'
        '"full_name":"Test User","phone":"+254700000000"}';

    test('posts phone/password and decodes the session', () async {
      final api = apiWith((_) async => http.Response(body, 200));

      final result = await api.login(
        phone: '+254700000000',
        password: 'TestUser2026!',
      );

      expect(seen!.url.path, AuthApi.loginPath);
      expect(seen!.body,
          '{"phone":"+254700000000","password":"TestUser2026!"}');
      final session = (result as Data<LoginSession>).value;
      expect(session.accessToken, 'at');
      expect(session.refreshToken, 'rt');
      expect(session.userId, 7);
      expect(session.mustChangePassword, isTrue);
      expect(session.fullName, 'Test User');
    });

    test('a token-less success body reports malformed', () async {
      final api = apiWith((_) async => http.Response('{"detail":"nope"}', 200));

      final result = await api.login(phone: 'p', password: 'w');

      expect(result, isA<Error<LoginSession>>());
      final error = (result as Error<LoginSession>).error as ApiException;
      expect(error.kind, ApiFailureKind.malformed);
    });

    test('wrong password keeps the server message', () async {
      final api = apiWith(
        (_) async => http.Response('{"detail":"No active account found."}', 401),
      );

      final result = await api.login(phone: 'p', password: 'w');

      final error = (result as Error<LoginSession>).error as ApiException;
      expect(error.statusCode, 401);
      expect(error.message, contains('No active account'));
    });
  });

  group('changePassword', () {
    test('uses old_password / new_password / new_password_confirm', () async {
      final api = apiWith(
        (_) async => http.Response('{"detail":"Password updated."}', 200),
      );

      final result = await api.changePassword(
        oldPassword: 'old',
        newPassword: 'newenough1',
        newPasswordConfirm: 'newenough1',
      );

      expect(seen!.url.path, AuthApi.changePasswordPath);
      expect(
        seen!.body,
        '{"old_password":"old","new_password":"newenough1",'
        '"new_password_confirm":"newenough1"}',
      );
      expect((result as Data<String>).value, 'Password updated.');
    });

    test('field-shaped 400 lists every failing field', () async {
      final api = apiWith(
        (_) async => http.Response(
          '{"old_password":["This field is required."],'
          '"new_password":["This password is too common."],'
          '"new_password_confirm":["This field is required."]}',
          400,
        ),
      );

      final result = await api.changePassword(
        oldPassword: '',
        newPassword: 'password',
        newPasswordConfirm: '',
      );

      final error = (result as Error<String>).error as ApiException;
      expect(error.statusCode, 400);
      expect(error.message, contains('old_password: This field is required.'));
      expect(error.message, contains('new_password: This password is too common.'));
    });

    test('an unobserved 200 shape still reads as success', () async {
      final api = apiWith((_) async => http.Response('{"ok":true}', 200));

      final result = await api.changePassword(
        oldPassword: 'a',
        newPassword: 'b',
        newPasswordConfirm: 'b',
      );

      expect((result as Data<String>).value, 'Password changed.');
    });
  });

  group('logout', () {
    test('decodes the detail message', () async {
      final api = apiWith(
        (_) async => http.Response(
          '{"detail":"Logout successful. Please discard your token."}',
          200,
        ),
      );

      final result = await api.logout();

      expect(seen!.url.path, AuthApi.logoutPath);
      expect((result as Data<String>).value, startsWith('Logout successful'));
    });
  });

  group('fetchProfile', () {
    test('decodes the fields the session renders', () async {
      final api = apiWith(
        (_) async => http.Response(
          '{"id":103,"username":"254700000000","name":"Test User",'
          '"email":"","phone":"+254700000000","role":"patient",'
          '"country":"KE","facility_name":null,'
          '"must_change_password":false,"is_verified":true,'
          '"profile_picture_url":null,"extra_key":"ignored"}',
          200,
        ),
      );

      final result = await api.fetchProfile();

      expect(seen!.url.path, AuthApi.profilePath);
      final profile = (result as Data<AuthProfile>).value;
      expect(profile.id, 103);
      expect(profile.fullName, 'Test User');
      expect(profile.role, 'patient');
      expect(profile.isVerified, isTrue);
      expect(profile.mustChangePassword, isFalse);
      expect(profile.facilityName, isNull);
    });

    test('a non-object body reports malformed', () async {
      final api = apiWith((_) async => http.Response('<html>oops</html>', 200));

      final result = await api.fetchProfile();

      expect(result, isA<Error<AuthProfile>>());
    });
  });

  test('an unreachable host reads as Offline', () async {
    final api = apiWith((_) async => throw http.ClientException('down'));

    final result = await api.login(phone: 'p', password: 'w');

    expect(result, isA<Offline<LoginSession>>());
  });
}
