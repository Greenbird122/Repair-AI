import 'package:flutter_test/flutter_test.dart';

import 'package:repairai/features/auth/data/secure_token_storage.dart';
import 'package:repairai/features/network/data/token_storage.dart';

class _FakeStore implements SecureStore {
  final Map<String, String> data = {};
  int writes = 0;

  @override
  Future<String?> read(String key) async => data[key];

  @override
  Future<void> write(String key, String value) async {
    writes++;
    data[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    data.remove(key);
  }
}

void main() {
  late _FakeStore store;
  late SecureTokenStorage storage;

  setUp(() {
    store = _FakeStore();
    storage = SecureTokenStorage(store: store);
  });

  test('starts empty', () async {
    expect(await storage.accessToken, isNull);
    expect(await storage.refreshToken, isNull);
  });

  test('saves both tokens under distinct keys', () async {
    await storage.save(accessToken: 'a1', refreshToken: 'r1');

    expect(await storage.accessToken, 'a1');
    expect(await storage.refreshToken, 'r1');
    expect(store.data.keys, ['access_token', 'refresh_token']);
    expect(store.data['access_token'], isNot(store.data['refresh_token']));
  });

  test('overwrites the previous pair', () async {
    await storage.save(accessToken: 'a1', refreshToken: 'r1');
    await storage.save(accessToken: 'a2', refreshToken: 'r2');

    expect(await storage.accessToken, 'a2');
    expect(await storage.refreshToken, 'r2');
    expect(store.writes, 4);
  });

  test('clear removes both keys', () async {
    await storage.save(accessToken: 'a1', refreshToken: 'r1');
    await storage.clear();

    expect(await storage.accessToken, isNull);
    expect(await storage.refreshToken, isNull);
    expect(store.data, isEmpty);
  });

  test('clear on empty storage does not throw', () async {
    await storage.clear();

    expect(store.data, isEmpty);
  });

  test('works through the TokenStorage interface the network layer uses',
      () async {
    final TokenStorage asContract = storage;

    await asContract.save(accessToken: 'x', refreshToken: 'y');

    expect(await asContract.accessToken, 'x');
    expect(await asContract.refreshToken, 'y');
    await asContract.clear();
    expect(await asContract.accessToken, isNull);
  });
}
