import 'package:flutter_test/flutter_test.dart';

import 'package:repairai/main.dart';

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
}
