import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:repairai/features/network/data/api_client.dart';
import 'package:repairai/features/network/data/app_version.dart';
import 'package:repairai/features/network/data/health_check.dart';
import 'package:repairai/features/network/data/result.dart';

void main() {
  test('returns Data for the live app-version shape', () async {
    final client = ApiClient(
      baseUrl: 'https://test',
      httpClient: MockClient(
        (_) async => http.Response(
          '{"status":"ok","latest_version":"1.0.0",'
          '"backend_version":"1.0.0","release_url":"https://x/y"}',
          200,
        ),
      ),
    );

    final result = await fetchAppVersion(client);

    expect(result, isA<Data<AppVersion>>());
    final version = (result as Data<AppVersion>).value;
    expect(version.status, 'ok');
    expect(version.latestVersion, '1.0.0');
  });

  test('returns Offline when the host is unreachable', () async {
    final client = ApiClient(
      baseUrl: 'https://test',
      httpClient: MockClient((_) async => throw const SocketException('down')),
    );

    expect(await fetchAppVersion(client), isA<Offline<AppVersion>>());
  });
}
