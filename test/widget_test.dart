import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:repairai/core/theme.dart';
import 'package:repairai/main.dart';
import 'package:repairai/pages/splash_gate.dart';
import 'package:repairai/pages/splash_page.dart';

void main() {
  testWidgets('splash plays, then lands on home', (tester) async {
    await tester.pumpWidget(const RepairAiApp());
    await tester.pump(const Duration(seconds: 2));

    // Mid-intro: wordmark is mounted (fading in), tagline is mounted but
    // still transparent — the splash tree is present either way.
    expect(find.text('RepairAI'), findsOneWidget);
    expect(find.textContaining('Heal'), findsOneWidget);

    // Past the 5s timeline: home page has replaced the splash.
    await tester.pump(const Duration(seconds: 4));
    expect(find.text('Get Started'), findsOneWidget);
    expect(find.textContaining('Heal'), findsOneWidget);
  });

  testWidgets('splash renders the dark logo stage', (tester) async {
    await tester.pumpWidget(const RepairAiApp());
    await tester.pump(const Duration(milliseconds: 600));

    // Page background is the near-black logo backdrop, not lavender.
    final Scaffold scaffold = tester.widget<Scaffold>(
      find.descendant(
        of: find.byType(SplashGate),
        matching: find.byType(Scaffold).first,
      ),
    );
    expect(scaffold.backgroundColor, isNull); // falls through to DecoratedBox
    final DecoratedBox box = tester.widget<DecoratedBox>(
      find.descendant(
        of: find.byType(SplashPage),
        matching: find.byType(DecoratedBox),
      ),
    );
    final BoxDecoration decoration = box.decoration as BoxDecoration;
    expect(decoration.gradient, isA<RadialGradient>());
    final RadialGradient gradient = decoration.gradient! as RadialGradient;
    expect(gradient.colors.first, RepairColors.splashBgCenter);
    expect(gradient.colors.last, RepairColors.splashBg);

    // Wordmark: "Repair" in the light on-dark tone, "AI" in brand amber.
    final RichText rich = tester.widget<RichText>(
      find.descendant(
        of: find.text('RepairAI'),
        matching: find.byType(RichText),
      ),
    );
    // Text.rich wraps our span: root -> "Repair" -> "AI".
    final TextSpan root = rich.text as TextSpan;
    final TextSpan repair = root.children!.single as TextSpan;
    final TextSpan ai = repair.children!.single as TextSpan;
    expect(root.style!.color, RepairColors.onDark);
    expect(ai.style!.color, RepairColors.amber);

    // Home stays in the light world after the splash hands over
    // (0.6s + 5s crosses the 5.4s auto-advance Timer).
    await tester.pump(const Duration(seconds: 5));
    final BuildContext homeCtx = tester.element(find.text('Get Started'));
    expect(Theme.of(homeCtx).scaffoldBackgroundColor, RepairColors.bgCenter);
  });

  testWidgets('emblem is precached, not decode-blocked on first paint',
      (tester) async {
    await tester.pumpWidget(const RepairAiApp());
    await tester.pump(); // run initState -> precacheImage kicks off
    await tester.runAsync(() async {
      // Let the real async decode finish, like the engine would off-frame.
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    final ImageCache cache = PaintingBinding.instance.imageCache;
    // Either still decoding (pending) or done (live) — never missing.
    expect(cache.pendingImageCount + cache.liveImageCount, greaterThan(0));
  });
}
