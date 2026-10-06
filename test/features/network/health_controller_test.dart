import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:repairai/features/network/data/api_client.dart';
import 'package:repairai/features/network/data/app_version.dart';
import 'package:repairai/features/network/data/result.dart';
import 'package:repairai/features/network/logic/health_controller.dart';
import 'package:repairai/features/network/logic/network_providers.dart';

void main() {
  ProviderContainer containerWith(MockClientHandler handler) {
    final container = ProviderContainer(
      overrides: [
        apiClientProvider.overrideWithValue(
          ApiClient(baseUrl: 'https://test', httpClient: MockClient(handler)),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('yields Data when the backend answers', () async {
    final container = containerWith(
      (_) async => http.Response('{"status":"ok","latest_version":"1.0.0"}', 200),
    );

    final result = await container.read(healthProvider.future);

    expect(result, isA<Data<AppVersion>>());
    expect((result as Data<AppVersion>).value.status, 'ok');
  });

  test('yields Offline when the backend is unreachable', () async {
    final container = containerWith(
      (_) async => throw const SocketException('down'),
    );

    expect(
      await container.read(healthProvider.future),
      isA<Offline<AppVersion>>(),
    );
  });

  test('yields Error when the backend fails', () async {
    final container = containerWith(
      (_) async => http.Response('{"detail":"boom"}', 503),
    );

    expect(
      await container.read(healthProvider.future),
      isA<Error<AppVersion>>(),
    );
  });
}
