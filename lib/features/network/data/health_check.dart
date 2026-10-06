import 'api_client.dart';
import 'app_version.dart';
import 'result.dart';

/// Health and update probe. Endpoint proven live on 2026-10-06: 200 without
/// auth, ~1.8s cold, so it also doubles as the online/offline signal.
Future<Result<AppVersion>> fetchAppVersion(ApiClient client) => client.get(
      '/api/app-version/',
      decode: AppVersion.fromJson,
    );
