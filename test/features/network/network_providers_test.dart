import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:repairai/features/network/data/api_client.dart';
import 'package:repairai/features/network/data/auth_authenticator.dart';
import 'package:repairai/features/network/data/token_storage.dart';
import 'package:repairai/features/network/logic/network_providers.dart';

void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer();
    addTearDown(container.dispose);
  });

  test('exposes one token store per container', () {
    expect(container.read(tokenStorageProvider), isA<TokenStorage>());
    expect(
      identical(
        container.read(tokenStorageProvider),
        container.read(tokenStorageProvider),
      ),
      isTrue,
    );
  });

  test('authenticator reads tokens from that same store', () async {
    await container
        .read(tokenStorageProvider)
        .save(accessToken: 'abc', refreshToken: 'r');

    expect(container.read(authenticatorProvider).accessToken, 'abc');
  });

  test('authenticator targets the configured base url', () {
    final authenticator =
        container.read(authenticatorProvider) as JwtAuthenticator;

    expect(authenticator.baseUrl, apiBaseUrl);
  });

  test('api client carries the authenticator and base url', () {
    final client = container.read(apiClientProvider);

    expect(client.authenticator, isNotNull);
    expect(client.baseUrl, apiBaseUrl);
    expect(client.timeout, const Duration(seconds: 5));
  });

  test('containers get distinct client instances', () {
    final other = ProviderContainer();
    addTearDown(other.dispose);

    expect(
      identical(
        container.read(apiClientProvider),
        other.read(apiClientProvider),
      ),
      isFalse,
    );
  });
}
