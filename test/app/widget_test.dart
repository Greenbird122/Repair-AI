import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:repairai/core/theme.dart';
import 'package:repairai/features/network/data/api_client.dart';
import 'package:repairai/features/network/data/token_storage.dart';
import 'package:repairai/main.dart';
import 'package:repairai/pages/login_page.dart';
import 'package:repairai/pages/splash_gate.dart';
import 'package:repairai/pages/splash_page.dart';

const _profileJson = '{"id":103,"username":"254700000000",'
    '"name":"Test User","email":"","phone":"+254700000000",'
    '"role":"patient","country":"KE","facility_name":null,'
    '"must_change_password":false,"is_verified":true,'
    '"profile_picture_url":null}';

void main() {
  testWidgets('splash plays, then the guard lands a signed-out app on login',
      (tester) async {
    await tester.pumpWidget(const RepairAiApp());
    await tester.pump(const Duration(seconds: 2));

    // Mid-intro: wordmark is mounted (fading in), tagline is mounted but
    // still transparent — the splash tree is present either way.
    expect(find.text('RepairAI'), findsOneWidget);
    expect(find.textContaining('Heal'), findsOneWidget);

    // Past the 5s timeline: the hand-off meets the guard and stops at
    // login — no stored session, no home.
    await tester.pump(const Duration(seconds: 4));
    expect(find.byType(LoginPage), findsOneWidget);
    expect(find.text('Welcome back'), findsOneWidget);
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

    // The light world resumes after the splash hands over: login page
    // rides the light theme (0.6s + 5s crosses the 5.4s auto-advance).
    await tester.pump(const Duration(seconds: 5));
    final BuildContext loginCtx = tester.element(find.byType(LoginPage));
    expect(Theme.of(loginCtx).scaffoldBackgroundColor, RepairColors.bgCenter);
  });

  testWidgets('a stored session sails past login and lands on home',
      (tester) async {
    final storage = InMemoryTokenStorage();
    await storage.save(accessToken: 'a', refreshToken: 'r');
    await tester.pumpWidget(
      RepairAiApp(
        tokenStorage: storage,
        apiClient: ApiClient(
          baseUrl: 'https://test',
          httpClient: MockClient(
            (_) async => http.Response(_profileJson, 200),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 6));
    await tester.pump();

    expect(find.byType(LoginPage), findsNothing);
    expect(find.text('Signed in as Test User'), findsOneWidget);
    expect(find.text('Sign out'), findsOneWidget);
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
