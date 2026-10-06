import 'package:flutter_test/flutter_test.dart';

import 'package:repairai/features/network/data/result.dart';

String label(Result<int> result) => switch (result) {
      Loading<int>() => 'loading',
      Data<int>(:final value) => 'data:$value',
      Error<int>(:final error) => 'error:$error',
      Offline<int>() => 'offline',
    };

void main() {
  test('all four variants are distinct and exhaustively matchable', () {
    expect(label(const Loading<int>()), 'loading');
    expect(label(const Data<int>(7)), 'data:7');
    expect(label(const Error<int>('boom')), 'error:boom');
    expect(label(const Offline<int>()), 'offline');
  });
}
