import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/routes.dart';
import 'core/theme.dart';

void main() {
  runApp(const RepairAiApp());
}

/// App root. [ProviderScope] lives *inside* it, so any bare pump of this
/// widget — production or test — reaches the providers, and nothing can
/// silently lose the scope by forgetting to wrap.
class RepairAiApp extends StatelessWidget {
  const RepairAiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      child: MaterialApp.router(
        title: 'RepairAI',
        debugShowCheckedModeBanner: false,
        theme: RepairTheme.light,
        routerConfig: createRouter(),
      ),
    );
  }
}
