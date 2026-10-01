import 'package:flutter/material.dart';

import 'core/theme.dart';
import 'pages/home_page.dart';
import 'pages/splash_page.dart';

void main() {
  runApp(const RepairAiApp());
}

class RepairAiApp extends StatelessWidget {
  const RepairAiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RepairAI',
      debugShowCheckedModeBanner: false,
      theme: RepairTheme.light,
      home: const SplashGate(),
    );
  }
}

/// Shows the animated splash once, then swaps to the home page.
class SplashGate extends StatefulWidget {
  const SplashGate({super.key});

  @override
  State<SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<SplashGate> {
  bool _showSplash = true;

  @override
  Widget build(BuildContext context) {
    return _showSplash
        ? SplashPage(onFinished: () => setState(() => _showSplash = false))
        : const HomePage();
  }
}
