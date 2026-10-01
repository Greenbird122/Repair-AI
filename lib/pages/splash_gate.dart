import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'splash_page.dart';

/// Entry route ('/'): plays the animated splash once, then hands off to
/// '/home' via [GoRouter]. Screens after this live in lib/pages + branches.
class SplashGate extends StatefulWidget {
  const SplashGate({super.key});

  @override
  State<SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<SplashGate> {
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
    return SplashPage(
      onFinished: () => context.pushReplacement('/home'),
    );
  }
}
