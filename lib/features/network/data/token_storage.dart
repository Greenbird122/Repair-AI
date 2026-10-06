/// Where JWTs live between requests. Reads are async because the secure
/// backend is — an in-memory cache with startup hydration would silently
/// drop the session if hydration were ever skipped.
abstract interface class TokenStorage {
  Future<String?> get accessToken;
  Future<String?> get refreshToken;

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
  Future<String?> get accessToken async => _accessToken;

  @override
  Future<String?> get refreshToken async => _refreshToken;

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
