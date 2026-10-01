import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Placeholder landing page after the splash — the app itself starts here.
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('RepairAI'),
        backgroundColor: RepairColors.bgCenter,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/branding/emblem.png',
              width: 120,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 24),
            Text.rich(
              TextSpan(
                text: 'Repair',
                children: [
                  TextSpan(
                    text: 'AI',
                    style: RepairText.wordmark(40)
                        .copyWith(color: RepairColors.amber),
                  ),
                ],
              ),
              style: RepairText.wordmark(40),
            ),
            const SizedBox(height: 8),
            Text(
              'Heal · Support · Hope',
              style: RepairText.tagline(14),
            ),
            const SizedBox(height: 48),
            FilledButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Next stop: onboarding ✨'),
                  ),
                );
              },
              child: const Text('Get Started'),
            ),
          ],
        ),
      ),
    );
  }
}
