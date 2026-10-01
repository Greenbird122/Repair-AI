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
  bool _precacheDone = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Decode the emblem now so its first appearance on the splash never
    // janks the 0.1s fade-in (decode happens off the animation clock).
    // didChangeDependencies is the safe place — context is fully usable.
    if (!_precacheDone) {
      _precacheDone = true;
      precacheImage(
        const AssetImage('assets/branding/emblem.png'),
        context,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return _showSplash
        ? SplashPage(onFinished: () => setState(() => _showSplash = false))
        : const HomePage();
  }
}
