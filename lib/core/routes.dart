import 'package:go_router/go_router.dart';

import '../pages/home_page.dart';
import '../pages/splash_gate.dart';

/// Central route table. One GoRoute per page; add pages here as the app
/// grows. Paths are kebab-case, names are camelCase.
///
/// Scale plan (30-40 pages):
///  - Tabbed sections become ShellRoute branches (e.g. /learn/*, /care/*).
///  - Sub-pages nest under their section: /learn/article/:id.
///  - Guards (auth/onboarding) go in redirect callbacks here, not in pages.
GoRouter createRouter({String initialLocation = '/'}) => GoRouter(
      initialLocation: initialLocation,
      routes: [
        GoRoute(
          path: '/',
          name: 'splash',
          builder: (_, _) => const SplashGate(),
        ),
        GoRoute(
          path: '/home',
          name: 'home',
          builder: (_, _) => const HomePage(),
        ),
      ],
    );
