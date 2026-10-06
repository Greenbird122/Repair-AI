import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:repairai/features/network/data/api_client.dart';
import 'package:repairai/features/network/data/token_storage.dart';
import 'package:repairai/features/network/logic/network_providers.dart';
import 'package:repairai/main.dart';

void main() {
  testWidgets('production root mounts with providers reachable',
      (tester) async {
    await tester.pumpWidget(buildApp());
    // Clear the splash hand-off timer so the tree settles on home.
    await tester.pump(const Duration(seconds: 6));
    await tester.pump();

    expect(find.byType(MaterialApp), findsOneWidget);

    final ProviderContainer container = ProviderScope.containerOf(
      tester.element(find.byType(RepairAiApp)),
    );

    expect(container.read(apiClientProvider), isA<ApiClient>());
    expect(container.read(tokenStorageProvider), isA<TokenStorage>());
    expect(container.read(authenticatorProvider), isNotNull);
  });

  testWidgets('a provider read inside the tree resolves', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: Builder(
          builder: (context) => Text(
            refReadProbe(context).runtimeType.toString(),
            textDirection: TextDirection.ltr,
          ),
        ),
      ),
    );

    expect(find.textContaining('ApiClient'), findsOneWidget);
  });
}

/// Reads through the ambient scope the way a Phase 1 page will.
ApiClient refReadProbe(BuildContext context) =>
    ProviderScope.containerOf(context).read(apiClientProvider);
