import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:repairai/features/locations/data/location_api.dart';
import 'package:repairai/features/network/data/api_client.dart';
import 'package:repairai/features/network/data/api_exception.dart';
import 'package:repairai/features/network/data/result.dart';

void main() {
  late Uri? seenUrl;

  LocationApi apiWith(MockClientHandler handler) {
    seenUrl = null;
    return LocationApi(
      ApiClient(
        baseUrl: 'https://test',
        httpClient: MockClient((request) async {
          seenUrl = request.url;
          return handler(request);
        }),
      ),
    );
  }

  test('countries hits the countries path', () async {
    final api = apiWith(
      (_) async => http.Response('[{"id":26,"name":"Kenya"}]', 200),
    );

    final result = await api.countries();

    expect(seenUrl!.path, LocationApi.countriesPath);
    expect(seenUrl!.query, isEmpty);
    final places = (result as Data<List<Place>>).value;
    expect(places.single.id, 26);
    expect(places.single.name, 'Kenya');
  });

  test('counties filters by country name, url-encoded', () async {
    final api = apiWith(
      (_) async => http.Response('[{"id":13,"name":"Baringo","country":26}]', 200),
    );

    final result = await api.counties(country: 'South Sudan');

    expect(seenUrl!.path, LocationApi.countiesPath);
    expect(seenUrl!.queryParameters, {'country': 'South Sudan'});
    expect(seenUrl!.query, 'country=South+Sudan');
    expect((result as Data<List<Place>>).value.single.name, 'Baringo');
  });

  test('subCounties filters by county name', () async {
    final api = apiWith(
      (_) async => http.Response('[{"id":275,"name":"Westlands","county":1}]', 200),
    );

    final result = await api.subCounties(county: 'Nairobi');

    expect(seenUrl!.path, LocationApi.subCountiesPath);
    expect(seenUrl!.queryParameters, {'county': 'Nairobi'});
    expect((result as Data<List<Place>>).value.single.id, 275);
  });

  test('an empty list decodes to an empty selection', () async {
    final api = apiWith((_) async => http.Response('[]', 200));

    final result = await api.counties(country: 'KE');

    expect((result as Data<List<Place>>).value, isEmpty);
  });

  test('a non-list body reports malformed', () async {
    final api = apiWith((_) async => http.Response('{"oops":1}', 200));

    final result = await api.countries();

    expect(result, isA<Error<List<Place>>>());
    final error = (result as Error<List<Place>>).error as ApiException;
    expect(error.kind, ApiFailureKind.malformed);
  });

  test('a non-object row reports malformed', () async {
    final api = apiWith((_) async => http.Response('[1, 2]', 200));

    final result = await api.countries();

    expect(result, isA<Error<List<Place>>>());
  });

  test('an unreachable host reads as Offline', () async {
    final api = apiWith((_) async => throw http.ClientException('down'));

    final result = await api.countries();

    expect(result, isA<Offline<List<Place>>>());
  });
}
