/// Where JWTs live between requests. Secure on-device persistence arrives
/// with the auth slice; Phase 0 keeps tokens in memory only, so nothing
/// sensitive is ever written to disk before login actually exists.
abstract interface class TokenStorage {
  String? get accessToken;
  String? get refreshToken;

  Future<void> save({
    required String accessToken,
    required String refreshToken,
  });

  Future<void> clear();
}

final class InMemoryTokenStorage implements TokenStorage {
  String? _accessToken;
  String? _refreshToken;

  @override
  String? get accessToken => _accessToken;

  @override
  String? get refreshToken => _refreshToken;

  @override
  Future<void> save({
    required String accessToken,
    required String refreshToken,
  }) async {
    _accessToken = accessToken;
    _refreshToken = refreshToken;
  }

  @override
  Future<void> clear() async {
    _accessToken = null;
    _refreshToken = null;
  }
}
