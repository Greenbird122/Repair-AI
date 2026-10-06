import 'package:flutter_test/flutter_test.dart';

import 'package:repairai/features/network/data/result.dart';

String label(Result<int> result) => switch (result) {
      Data<int>(:final value) => 'data:$value',
      Error<int>(:final error) => 'error:$error',
      Offline<int>() => 'offline',
    };

void main() {
  test('all three variants are distinct and exhaustively matchable', () {
    expect(label(const Data<int>(7)), 'data:7');
    expect(label(const Error<int>('boom')), 'error:boom');
    expect(label(const Offline<int>()), 'offline');
  });
}
