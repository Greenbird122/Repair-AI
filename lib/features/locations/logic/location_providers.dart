import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../network/data/result.dart';
import '../../network/logic/network_providers.dart';
import '../data/location_api.dart';

/// The one [LocationApi] pages talk through. Backed by the shared
/// [apiClientProvider], so it inherits bearer auth and timeouts.
final locationApiProvider = Provider<LocationApi>(
  (ref) => LocationApi(ref.watch(apiClientProvider)),
);

/// All countries. The register cascade watches this once.
final countriesProvider = FutureProvider<Result<List<Place>>>((ref) =>
    ref.watch(locationApiProvider).countries());

/// Counties for one country **name** (the server matches on name, not
/// id). Families keep every loaded list cached by selection.
final countiesProvider = FutureProvider.family<Result<List<Place>>, String>(
  (ref, country) => ref.watch(locationApiProvider).counties(country: country),
);

/// Sub-counties for one county **name**.
final subCountiesProvider = FutureProvider.family<Result<List<Place>>, String>(
  (ref, county) => ref.watch(locationApiProvider).subCounties(county: county),
);
