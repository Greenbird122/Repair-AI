import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/api_client.dart';
import '../data/auth_authenticator.dart';
import '../data/token_storage.dart';

/// Shared token store. In-memory until the auth slice adds persistence.
final tokenStorageProvider = Provider<TokenStorage>(
  (ref) => InMemoryTokenStorage(),
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
