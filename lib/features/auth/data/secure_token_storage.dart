import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../network/data/token_storage.dart';

/// Kept behind an interface so the platform channel can be faked in tests.
abstract interface class SecureStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

final class FlutterSecureStore implements SecureStore {
  FlutterSecureStore([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

/// Encrypted-at-rest JWT storage (Android EncryptedSharedPreferences).
/// The app-wide default: `tokenStorageProvider` hands it out
/// (`network_providers.dart`), so persistence is a data-layer guarantee,
/// not entry-point wiring. Unit tests fake [SecureStore]; UI tests stub
/// the plugin channel itself (`test/flutter_secure_channel.dart`) —
/// 11.x speaks `BasicMessageChannel`, so a missing handler makes reads
/// hang forever and hydration never completes.
final class SecureTokenStorage implements TokenStorage {
  SecureTokenStorage({SecureStore? store}) : _store = store ?? FlutterSecureStore();

  static const _accessKey = 'access_token';
  static const _refreshKey = 'refresh_token';

  final SecureStore _store;

  @override
  Future<String?> get accessToken => _store.read(_accessKey);

  @override
  Future<String?> get refreshToken => _store.read(_refreshKey);

  @override
  Future<void> save({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _store.write(_accessKey, accessToken);
    await _store.write(_refreshKey, refreshToken);
  }

  @override
  Future<void> clear() async {
    await _store.delete(_accessKey);
    await _store.delete(_refreshKey);
  }
}
