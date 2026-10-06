import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:repairai/features/network/data/api_client.dart';
import 'package:repairai/features/network/data/token_storage.dart';
import 'package:repairai/features/network/logic/network_providers.dart';
import 'package:repairai/main.dart';

void main() {
  testWidgets('a bare RepairAiApp pump still reaches the providers',
      (tester) async {
    // Deliberately no ProviderScope here — the app carries its own.
    await tester.pumpWidget(const RepairAiApp());
    // Let the splash hand-off timer fire so the tree settles on home.
    await tester.pump(const Duration(seconds: 6));
    await tester.pump();

    expect(find.byType(MaterialApp), findsOneWidget);

    // Read from a page-level context, where Phase 1 pages will watch.
    final BuildContext page = tester.element(find.text('Get Started'));
    final ProviderContainer container = ProviderScope.containerOf(page);

    expect(container.read(apiClientProvider), isA<ApiClient>());
    expect(container.read(tokenStorageProvider), isA<TokenStorage>());
    expect(container.read(authenticatorProvider), isNotNull);
  });
}
