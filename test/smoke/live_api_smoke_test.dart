import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:repairai/features/network/data/api_client.dart';
import 'package:repairai/features/network/data/app_version.dart';
import 'package:repairai/features/network/data/health_check.dart';
import 'package:repairai/features/network/data/result.dart';

/// Live probe of production, gated on `LIVE_SMOKE=1` so CI carries it and
/// local runs stay offline. Proves the backend answers real requests before
/// any page is built against it (`AGENT_SPEC.md` §1.8).
void main() {
  test(
    'production answers the app-version health probe',
    () async {
      final client = ApiClient();
      addTearDown(client.dispose);

      final result = await fetchAppVersion(client);

      expect(
        result,
        isA<Data<AppVersion>>(),
        reason: 'app-version did not return data: $result',
      );
      final version = (result as Data<AppVersion>).value;
      expect(version.status, 'ok');
      expect(version.latestVersion, isNotNull);
      expect(version.releaseUrl, isNotNull);
    },
    timeout: const Timeout(Duration(seconds: 25)),
    skip: Platform.environment['LIVE_SMOKE'] != '1',
  );
}
