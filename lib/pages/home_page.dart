import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme.dart';
import '../features/auth/logic/session_controller.dart';

/// Signed-in landing after '/'. Phase 1 shows who you are and how to
/// leave; the pregnancy dashboard is Phase 2. Navigation on sign-out is
/// the guard's job, not this page's.
class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final name = session.profile?.fullName;
    final greeting = (name == null || name.isEmpty)
        ? 'You are signed in'
        : 'Signed in as $name';

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
            const SizedBox(height: 32),
            Text(greeting, style: RepairText.tagline(15)),
            const SizedBox(height: 24),
            OutlinedButton(
              onPressed: () =>
                  ref.read(sessionProvider.notifier).logout(),
              child: const Text('Sign out'),
            ),
          ],
        ),
      ),
    );
  }
}
