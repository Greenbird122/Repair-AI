import 'package:flutter_test/flutter_test.dart';

import 'package:repairai/features/network/data/app_version.dart';

void main() {
  test('decodes the payload proven live on 2026-10-06', () {
    final version = AppVersion.fromJson(const {
      'status': 'ok',
      'latest_version': '1.0.0',
      'backend_version': '1.0.0',
      'release_url': 'https://github.com/Greenbird122/EPL_APP/releases/latest',
    });

    expect(version.status, 'ok');
    expect(version.latestVersion, '1.0.0');
    expect(version.backendVersion, '1.0.0');
    expect(version.releaseUrl, endsWith('/releases/latest'));
  });

  test('optional fields may be absent', () {
    final version = AppVersion.fromJson(const {'status': 'ok'});

    expect(version.status, 'ok');
    expect(version.latestVersion, isNull);
    expect(version.backendVersion, isNull);
    expect(version.releaseUrl, isNull);
  });

  test('rejects a payload with no status', () {
    expect(
      () => AppVersion.fromJson(const {'latest_version': '1.0.0'}),
      throwsA(isA<TypeError>()),
    );
  });

  test('rejects a non-object payload', () {
    expect(
      () => AppVersion.fromJson('ok'),
      throwsA(isA<TypeError>()),
    );
  });
}
