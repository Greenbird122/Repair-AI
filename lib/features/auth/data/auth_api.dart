import '../../network/data/api_client.dart';
import '../../network/data/result.dart';

/// 201 body of POST /api/auth/register/: the account exists now and the
/// user signs in separately (register does not return tokens).
class Registration {
  const Registration({
    required this.userId,
    required this.username,
    required this.role,
  });

  final int userId;
  final String username;
  final String role;

  factory Registration.fromJson(Map<String, dynamic> json) => Registration(
        userId: (json['user_id'] as num?)?.toInt() ?? 0,
        username: json['username'] as String? ?? '',
        role: json['role'] as String? ?? 'patient',
      );
}

/// The parts of the 200 body of POST /api/auth/login/ the session needs:
/// the token pair plus who signed in. The other 13 keys are profile
/// detail the profile fetch already covers.
class LoginSession {
  const LoginSession({
    required this.accessToken,
    required this.refreshToken,
    required this.userId,
    required this.role,
    required this.mustChangePassword,
    required this.fullName,
    required this.phone,
  });

  final String accessToken;
  final String refreshToken;
  final int userId;
  final String role;
  final bool mustChangePassword;
  final String fullName;
  final String phone;

  factory LoginSession.fromJson(Map<String, dynamic> json) {
    final access = json['access'];
    final refresh = json['refresh'];
    if (access is! String || access.isEmpty || refresh is! String) {
      throw const FormatException('login response is missing tokens');
    }
    return LoginSession(
      accessToken: access,
      refreshToken: refresh,
      userId: (json['user_id'] as num?)?.toInt() ??
          (json['id'] as num?)?.toInt() ??
          0,
      role: json['role'] as String? ?? 'patient',
      mustChangePassword: json['must_change_password'] == true,
      fullName: (json['full_name'] ?? json['name'] ?? '') as String,
      phone: json['phone'] as String? ?? '',
    );
  }
}

/// GET /api/auth/profile/ — the signed-in user's account record. Only the
/// fields Phase 1 renders are decoded; the rest of the 36-key payload is
/// deliberately ignored (profile editing is Phase 2).
class AuthProfile {
  const AuthProfile({
    required this.id,
    required this.username,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.role,
    required this.country,
    required this.facilityName,
    required this.mustChangePassword,
    required this.isVerified,
    required this.profilePictureUrl,
  });

  final int id;
  final String username;
  final String fullName;
  final String email;
  final String phone;
  final String role;
  final String country;
  final String? facilityName;
  final bool mustChangePassword;
  final bool isVerified;
  final String? profilePictureUrl;

  factory AuthProfile.fromJson(Map<String, dynamic> json) => AuthProfile(
        id: (json['id'] as num?)?.toInt() ?? 0,
        username: json['username'] as String? ?? '',
        fullName: json['name'] as String? ?? '',
        email: json['email'] as String? ?? '',
        phone: json['phone'] as String? ?? '',
        role: json['role'] as String? ?? 'patient',
        country: json['country'] as String? ?? '',
        facilityName: json['facility_name'] as String?,
        mustChangePassword: json['must_change_password'] == true,
        isVerified: json['is_verified'] == true,
        profilePictureUrl: json['profile_picture_url'] as String?,
      );
}

/// The auth endpoints of §1, every shape proven live on 2026-10-07:
///
///  - check-phone: 200 `{"detail":"...available."}` /
///    400 `{"detail":"...already exists."}` → [Data] / [Error] (400).
///  - register: 201 `{detail, user_id, username, role}`; required fields
///    are country, county, sub_county, password, password_confirm — all
///    names, never ids. phone/first_name/last_name are optional at the
///    API level but required by our form (login is phone-based).
///  - login: 200 token pair + profile keys.
///  - change-password: fields old_password / new_password /
///    new_password_confirm; the 200 body was never observed (probing it
///    would change the test account's password), so the decoder accepts
///    a detail message or anything else.
///  - logout: 200 `{"detail":"Logout successful. ..."}`.
class AuthApi {
  AuthApi(this._client);

  static const checkPhonePath = '/api/auth/check-phone/';
  static const registerPath = '/api/auth/register/';
  static const loginPath = '/api/auth/login/';
  static const logoutPath = '/api/auth/logout/';
  static const changePasswordPath = '/api/auth/change-password/';
  static const profilePath = '/api/auth/profile/';

  final ApiClient _client;

  /// [Data] means the phone is free; [Error] with status 400 means an
  /// account already uses it; [Offline] means we could not ask.
  Future<Result<bool>> checkPhone(String phone) => _client.post(
        checkPhonePath,
        body: {'phone': phone},
        decode: (_) => true,
      );

  Future<Result<Registration>> register({
    required String country,
    required String county,
    required String subCounty,
    required String phone,
    required String firstName,
    required String lastName,
    required String password,
    required String passwordConfirm,
  }) =>
      _client.post(
        registerPath,
        body: {
          'country': country,
          'county': county,
          'sub_county': subCounty,
          'phone': phone,
          'first_name': firstName,
          'last_name': lastName,
          'password': password,
          'password_confirm': passwordConfirm,
        },
        decode: (json) =>
            Registration.fromJson(json as Map<String, dynamic>),
      );

  Future<Result<LoginSession>> login({
    required String phone,
    required String password,
  }) =>
      _client.post(
        loginPath,
        body: {'phone': phone, 'password': password},
        decode: (json) => LoginSession.fromJson(json as Map<String, dynamic>),
      );

  Future<Result<String>> logout() => _client.post(
        logoutPath,
        decode: (json) =>
            (json as Map<String, dynamic>)['detail'] as String? ?? '',
      );

  Future<Result<String>> changePassword({
    required String oldPassword,
    required String newPassword,
    required String newPasswordConfirm,
  }) =>
      _client.post(
        changePasswordPath,
        body: {
          'old_password': oldPassword,
          'new_password': newPassword,
          'new_password_confirm': newPasswordConfirm,
        },
        decode: (json) {
          if (json is Map<String, dynamic> && json['detail'] is String) {
            return json['detail'] as String;
          }
          return 'Password changed.';
        },
      );

  Future<Result<AuthProfile>> fetchProfile() => _client.get(
        profilePath,
        decode: (json) => AuthProfile.fromJson(json as Map<String, dynamic>),
      );
}
