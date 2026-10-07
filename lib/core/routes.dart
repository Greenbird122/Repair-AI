import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/logic/session_controller.dart';
import '../pages/change_password_page.dart';
import '../pages/home_page.dart';
import '../pages/login_page.dart';
import '../pages/register_page.dart';
import '../pages/splash_gate.dart';

/// Central route table. One GoRoute per page; add pages here as the app
/// grows. Paths are kebab-case, names are camelCase.
///
/// Scale plan (30-40 pages):
///  - Tabbed sections become ShellRoute branches (e.g. /learn/*, /care/*).
///  - Sub-pages nest under their section: /learn/article/:id.
///  - Onboarding guards join the redirect callback below.
const Set<String> publicPaths = {'/', '/login', '/register'};

/// The auth guard, kept pure so tests can table-drive it:
///  - hydrating: never redirect (guards must not race token reads);
///  - signedOut: everything except [publicPaths] goes to '/login';
///  - must change password: everything goes to '/change-password';
///  - signed in: the login/register screens are unreachable.
String? authRedirect(SessionState session, String location) {
  if (session.status == SessionStatus.hydrating) return null;
  if (session.status == SessionStatus.signedOut) {
    return publicPaths.contains(location) ? null : '/login';
  }
  if (session.mustChangePassword) {
    return location == '/change-password' ? null : '/change-password';
  }
  return (location == '/login' || location == '/register') ? '/home' : null;
}

/// Build the GoRouter table. Pass [session] + [refreshListenable] to
/// arm the guard — [routerProvider] does; bare calls (tests, snapshots)
/// fall back to a hydrating session, i.e. no redirects.
GoRouter createRouter({
  String initialLocation = '/',
  Listenable? refreshListenable,
  SessionState Function()? session,
}) =>
    GoRouter(
      initialLocation: initialLocation,
      refreshListenable: refreshListenable,
      redirect: (_, state) =>
          authRedirect(session?.call() ?? const SessionState(), state.uri.path),
      routes: [
        GoRoute(
          path: '/',
          name: 'splash',
          builder: (_, _) => const SplashGate(),
        ),
        GoRoute(
          path: '/login',
          name: 'login',
          builder: (_, _) => const LoginPage(),
        ),
        GoRoute(
          path: '/register',
          name: 'register',
          builder: (_, _) => const RegisterPage(),
        ),
        GoRoute(
          path: '/change-password',
          name: 'changePassword',
          builder: (_, _) => const ChangePasswordPage(),
        ),
        GoRoute(
          path: '/home',
          name: 'home',
          builder: (_, _) => const HomePage(),
        ),
      ],
    );

/// Notifies GoRouter that the session moved, so redirects re-run
/// without rebuilding the router (rebuilds reset navigation).
class _SessionRefresh extends ChangeNotifier {
  void ping() => notifyListeners();
}

/// The one router the app uses: reads the live session, pings on every
/// state change, and starts session hydration by listening to it.
final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _SessionRefresh();
  ref.listen(sessionProvider, (_, _) => refresh.ping());
  final router = createRouter(
    session: () => ref.read(sessionProvider),
    refreshListenable: refresh,
  );
  ref.onDispose(router.dispose);
  ref.onDispose(refresh.dispose);
  return router;
});
