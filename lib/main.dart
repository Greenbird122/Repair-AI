import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/routes.dart';
import 'core/theme.dart';

void main() {
  runApp(buildApp());
}

/// The exact tree [main] mounts. Kept as a function so tests pump the
/// production root — ProviderScope included — instead of a hand-rolled
/// copy that would keep passing if the real one lost its scope.
Widget buildApp() => const ProviderScope(child: RepairAiApp());

class RepairAiApp extends StatelessWidget {
  const RepairAiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'RepairAI',
      debugShowCheckedModeBanner: false,
      theme: RepairTheme.light,
      routerConfig: createRouter(),
    );
  }
}
