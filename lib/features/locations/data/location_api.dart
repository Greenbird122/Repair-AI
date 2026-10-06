import '../../network/data/api_client.dart';
import '../../network/data/result.dart';

/// One selectable place from the locations lookup. Ids exist only to key
/// the lists — the register/profile payloads carry **names**, so [name]
/// is what gets sent back to the server.
class Place {
  const Place({required this.id, required this.name});

  final int id;
  final String name;

  factory Place.fromJson(Map<String, dynamic> json) => Place(
        id: (json['id'] as num?)?.toInt() ?? 0,
        name: json['name'] as String? ?? '',
      );

  @override
  String toString() => name;
}

/// GET /api/patients/locations/{countries,counties,sub-counties}/ —
/// proven live 2026-10-07. Two contract facts the shapes encode:
///  - filters match on **name**, not id (`?country=Kenya` works,
///    `?country=KE` returns `[]`; `?county=13` returns `[]`);
///  - an unfiltered call returns the full list (fine as a fallback,
///    but the register cascade always filters).
class LocationApi {
  LocationApi(this._client);

  static const countriesPath = '/api/patients/locations/countries/';
  static const countiesPath = '/api/patients/locations/counties/';
  static const subCountiesPath = '/api/patients/locations/sub-counties/';

  final ApiClient _client;

  Future<Result<List<Place>>> countries() =>
      _client.get(countriesPath, decode: _places);

  Future<Result<List<Place>>> counties({required String country}) =>
      _client.get('$countiesPath?country=${Uri.encodeQueryComponent(country)}',
          decode: _places);

  Future<Result<List<Place>>> subCounties({required String county}) =>
      _client.get(
          '$subCountiesPath?county=${Uri.encodeQueryComponent(county)}',
          decode: _places);

  static List<Place> _places(Object? json) {
    if (json is! List) {
      throw const FormatException('locations response is not a list');
    }
    return json
        .map((item) => Place.fromJson(item as Map<String, dynamic>))
        .toList();
  }
}
