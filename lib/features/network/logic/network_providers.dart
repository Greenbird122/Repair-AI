import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/api_client.dart';
import '../data/auth_authenticator.dart';
import '../data/token_storage.dart';
import '../../auth/data/secure_token_storage.dart';

/// Shared token store: the encrypted-at-rest [SecureTokenStorage], so
/// persistence is a data-layer guarantee, not entry-point wiring (the
/// epl_app lesson — do not leave the real store reachable only through
/// an override). Tests supply memory stores by overriding this provider.
final tokenStorageProvider = Provider<TokenStorage>(
  (ref) => SecureTokenStorage(),
);

/// Refresh policy backed by [tokenStorageProvider].
final authenticatorProvider = Provider<Authenticator>(
  (ref) => JwtAuthenticator(
    baseUrl: apiBaseUrl,
    storage: ref.watch(tokenStorageProvider),
  ),
);

/// The one HTTP client pages talk through. Override in tests.
final apiClientProvider = Provider<ApiClient>((ref) {
  final client = ApiClient(authenticator: ref.watch(authenticatorProvider));
  ref.onDispose(client.dispose);
  return client;
});
