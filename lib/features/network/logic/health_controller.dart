import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/app_version.dart';
import '../data/health_check.dart';
import '../data/result.dart';
import 'network_providers.dart';

/// Backend health for this device. Watch it and switch over [Result];
/// the AsyncValue layer supplies the initial loading state.
final healthProvider = FutureProvider<Result<AppVersion>>(
  (ref) => fetchAppVersion(ref.watch(apiClientProvider)),
);
