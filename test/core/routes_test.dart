import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:repairai/core/routes.dart';

void main() {
  test('route table registers splash and home', () {
    final GoRouter router = createRouter();

    final List<String> paths = router.configuration.routes
        .whereType<GoRoute>()
        .map((GoRoute r) => r.path)
        .toList();

    expect(paths, containsAll(<String>['/', '/home']));
  });

  test('router starts at the splash route', () {
    final GoRouter router = createRouter();

    expect(router.routeInformationProvider.value.uri.path, '/');
  });
}
