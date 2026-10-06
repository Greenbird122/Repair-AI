import 'package:flutter_test/flutter_test.dart';

import 'package:repairai/features/network/data/api_exception.dart';

void main() {
  test('keeps kind, status and message together', () {
    const error = ApiException(
      ApiFailureKind.http,
      statusCode: 401,
      message: 'expired',
    );
    expect(error.kind, ApiFailureKind.http);
    expect(error.statusCode, 401);
    expect(error.message, 'expired');
  });

  test('status and message are optional', () {
    const error = ApiException(ApiFailureKind.malformed);
    expect(error.statusCode, isNull);
    expect(error.message, isNull);
    expect(
      error.toString(),
      'ApiException(malformed, status: null, message: null)',
    );
  });

  test('is throwable as an exception', () {
    expect(
      () => throw const ApiException(ApiFailureKind.http, statusCode: 500),
      throwsA(isA<ApiException>()),
    );
  });
}
