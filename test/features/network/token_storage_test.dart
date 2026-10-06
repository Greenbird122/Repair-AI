import 'package:flutter_test/flutter_test.dart';

import 'package:repairai/features/network/data/token_storage.dart';

void main() {
  test('starts empty', () async {
    final storage = InMemoryTokenStorage();
    expect(await storage.accessToken, isNull);
    expect(await storage.refreshToken, isNull);
  });

  test('save keeps both tokens together', () async {
    final storage = InMemoryTokenStorage();
    await storage.save(accessToken: 'a1', refreshToken: 'r1');
    expect(await storage.accessToken, 'a1');
    expect(await storage.refreshToken, 'r1');
  });

  test('save overwrites the previous pair', () async {
    final storage = InMemoryTokenStorage();
    await storage.save(accessToken: 'a1', refreshToken: 'r1');
    await storage.save(accessToken: 'a2', refreshToken: 'r2');
    expect(await storage.accessToken, 'a2');
    expect(await storage.refreshToken, 'r2');
  });

  test('clear drops both tokens', () async {
    final storage = InMemoryTokenStorage();
    await storage.save(accessToken: 'a1', refreshToken: 'r1');
    await storage.clear();
    expect(await storage.accessToken, isNull);
    expect(await storage.refreshToken, isNull);
  });
}
