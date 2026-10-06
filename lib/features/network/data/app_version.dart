/// Payload of `GET /api/app-version/` — the app's health and update probe.
class AppVersion {
  const AppVersion({
    required this.status,
    this.latestVersion,
    this.backendVersion,
    this.releaseUrl,
  });

  factory AppVersion.fromJson(Object? json) {
    final map = json! as Map<String, dynamic>;
    return AppVersion(
      status: map['status'] as String,
      latestVersion: map['latest_version'] as String?,
      backendVersion: map['backend_version'] as String?,
      releaseUrl: map['release_url'] as String?,
    );
  }

  final String status;
  final String? latestVersion;
  final String? backendVersion;
  final String? releaseUrl;
}
