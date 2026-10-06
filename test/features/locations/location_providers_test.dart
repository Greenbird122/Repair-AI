import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:repairai/features/locations/data/location_api.dart';
import 'package:repairai/features/locations/logic/location_providers.dart';
import 'package:repairai/features/network/data/api_client.dart';
import 'package:repairai/features/network/data/api_exception.dart';
import 'package:repairai/features/network/data/result.dart';
import 'package:repairai/features/network/logic/network_providers.dart';

void main() {
  ProviderContainer build(MockClientHandler handler) {
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

  test('countries resolves the list through the shared client', () async {
    final container = build(
      (_) async => http.Response('[{"id":26,"name":"Kenya"}]', 200),
    );

    final result = await container.read(countriesProvider.future);

    expect((result as Data<List<Place>>).value.single.name, 'Kenya');
  });

  test('counties cache one fetch per country name', () async {
    var fetches = 0;
    final container = build((request) async {
      fetches++;
      return http.Response('[{"id":13,"name":"Baringo"}]', 200);
    });

    final first = await container.read(countiesProvider('Kenya').future);
    final again = await container.read(countiesProvider('Kenya').future);
    await container.read(countiesProvider('Uganda').future);

    expect((first as Data<List<Place>>).value.single.name, 'Baringo');
    expect(identical(first, again), isTrue);
    expect(fetches, 2);
  });

  test('subCounties watch the shared api provider', () async {
    final container = build(
      (_) async => http.Response('[{"id":275,"name":"Westlands"}]', 200),
    );

    final result = await container.read(subCountiesProvider('Nairobi').future);

    expect((result as Data<List<Place>>).value.single.name, 'Westlands');
  });

  test('a server failure lands as an Error result, not a broken future',
      () async {
    final container = build(
      (_) async => http.Response('{"detail":"boom"}', 500),
    );

    final result = await container.read(countiesProvider('Kenya').future);

    expect(result, isA<Error<List<Place>>>());
    final error = (result as Error<List<Place>>).error as ApiException;
    expect(error.statusCode, 500);
  });

  test('an unreachable host lands as Offline', () async {
    final container = build(
      (_) async => throw http.ClientException('down'),
    );

    final result = await container.read(countriesProvider.future);

    expect(result, isA<Offline<List<Place>>>());
  });
}
