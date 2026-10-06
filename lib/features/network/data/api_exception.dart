/// Why a call failed: the server rejected it, or the payload was unusable.
enum ApiFailureKind { http, malformed }

class ApiException implements Exception {
  const ApiException(this.kind, {this.statusCode, this.message});

  final ApiFailureKind kind;
  final int? statusCode;
  final String? message;

  @override
  String toString() =>
      'ApiException(${kind.name}, status: $statusCode, message: $message)';
}
