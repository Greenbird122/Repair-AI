import 'dart:async';

import 'package:flutter_secure_storage/test/test_flutter_secure_storage_platform.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';

/// Runs before every test file. The token-store provider default is the
/// encrypted-at-rest `SecureTokenStorage`; under the flutter_test binding
/// its real platform channel can never answer, which used to leave session
/// hydration stuck on `hydrating` and parked bare `RepairAiApp` pumps on
/// `/home`. The plugin's official in-memory platform answers instantly and
/// starts empty, so hydration sees "no stored session" — exactly like a
/// fresh device. Tests that need stored tokens or call recording still
/// override `tokenStorageProvider` with their own fakes.
Future<void> testExecutable(FutureOr<void> Function() body) async {
  FlutterSecureStoragePlatform.instance = TestFlutterSecureStoragePlatform({});
  await body();
}
