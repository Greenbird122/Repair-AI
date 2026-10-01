import 'package:flutter/material.dart';

import 'core/routes.dart';
import 'core/theme.dart';

void main() {
  runApp(const RepairAiApp());
}

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
