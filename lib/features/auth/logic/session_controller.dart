import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../network/data/result.dart';
import '../../network/data/token_storage.dart';
import '../../network/logic/network_providers.dart';
import '../data/auth_api.dart';

/// The one [AuthApi] the session drives. Shares the app's ApiClient, so
/// it inherits bearer auth, refresh and timeouts.
final authApiProvider = Provider<AuthApi>(
  (ref) => AuthApi(ref.watch(apiClientProvider)),
);

enum SessionStatus {
  /// Stored tokens not read yet — routers must not redirect yet.
  hydrating,

  /// No session, or the store was unreadable.
  signedOut,

  /// Tokens present (profile may still be loading).
  signedIn,
}

/// What every guard and authed page needs to know: are we signed in,
/// and does the server demand a password change first.
@immutable
class SessionState {
  const SessionState({
    this.status = SessionStatus.hydrating,
    this.mustChangePassword = false,
    this.profile,
  });

  final SessionStatus status;
  final bool mustChangePassword;
  final AuthProfile? profile;

  bool get signedIn => status == SessionStatus.signedIn;

  /// Transitions rebuild from the current state so no flag is dropped by
  /// hand. ([profile] can be carried forward but not nulled here.)
  SessionState copyWith({
    SessionStatus? status,
    bool? mustChangePassword,
    AuthProfile? profile,
  }) =>
      SessionState(
        status: status ?? this.status,
        mustChangePassword: mustChangePassword ?? this.mustChangePassword,
        profile: profile ?? this.profile,
      );
}

/// Owns the auth lifecycle: hydrate from storage on startup, login,
/// register, change password, logout, profile fetch.
///
/// Storage failures are tolerated on both write paths — a store that
/// cannot save tokens still yields a working session for this run, and a
/// store that cannot clear them still signs out locally. Login/register/
/// changePassword surface the server's [Result] untouched so pages can
/// render its message.
final sessionProvider =
    NotifierProvider<SessionController, SessionState>(SessionController.new);

class SessionController extends Notifier<SessionState> {
  late final AuthApi _api;
  late final TokenStorage _storage;

  @override
  SessionState build() {
    _api = ref.watch(authApiProvider);
    _storage = ref.watch(tokenStorageProvider);
    unawaited(_hydrate());
    return const SessionState();
  }

  Future<void> _hydrate() async {
    String? refresh;
    try {
      refresh = await _storage.refreshToken;
    } catch (_) {
      refresh = null; // Unreadable store reads as no session.
    }
    if (!ref.mounted) return;
    if (refresh == null) {
      state = const SessionState(status: SessionStatus.signedOut);
      return;
    }
    state = const SessionState(status: SessionStatus.signedIn);
    unawaited(loadProfile());
  }

  /// Sign in and persist the token pair. On success the state flips to
  /// signedIn (with the server's forced-password flag) and the profile
  /// loads in the background.
  Future<Result<void>> login({
    required String phone,
    required String password,
  }) async {
    final result = await _api.login(phone: phone, password: password);
    switch (result) {
      case Data(:final value):
        try {
          await _storage.save(
            accessToken: value.accessToken,
            refreshToken: value.refreshToken,
          );
        } catch (_) {
          // Store unavailable: session works for this run only.
        }
        if (ref.mounted) {
          state = SessionState(
            status: SessionStatus.signedIn,
            mustChangePassword: value.mustChangePassword,
          );
          unawaited(loadProfile());
        }
        return const Data(null);
      case Error(:final error):
        return Error(error);
      case Offline():
        return const Offline<void>();
    }
  }

  /// Create the account, checking the phone first (the check-phone call
  /// gives a clean "already in use" before the register round-trip).
  /// Tokens are not part of register — the page sends the user to login.
  Future<Result<void>> register({
    required String country,
    required String county,
    required String subCounty,
    required String phone,
    required String firstName,
    required String lastName,
    required String password,
    required String passwordConfirm,
  }) async {
    final available = await _api.checkPhone(phone);
    switch (available) {
      case Data():
        break;
      case Error(:final error):
        return Error(error);
      case Offline():
        return const Offline<void>();
    }

    final result = await _api.register(
      country: country,
      county: county,
      subCounty: subCounty,
      phone: phone,
      firstName: firstName,
      lastName: lastName,
      password: password,
      passwordConfirm: passwordConfirm,
    );
    return switch (result) {
      Data() => const Data(null),
      Error(:final error) => Error(error),
      Offline() => const Offline<void>(),
    };
  }

  /// Clear the forced-password flag after a successful change.
  Future<Result<void>> changePassword({
    required String oldPassword,
    required String newPassword,
    required String newPasswordConfirm,
  }) async {
    final result = await _api.changePassword(
      oldPassword: oldPassword,
      newPassword: newPassword,
      newPasswordConfirm: newPasswordConfirm,
    );
    if (result case Data()) {
      if (ref.mounted && state.signedIn) {
        state = state.copyWith(
          status: SessionStatus.signedIn,
          mustChangePassword: false,
        );
      }
      return const Data(null);
    }
    return switch (result) {
      Error(:final error) => Error(error),
      Offline() => const Offline<void>(),
      Data() => const Data(null), // Unreachable; keeps the switch exhaustive.
    };
  }

  /// Sign out. Server revocation is best-effort — the local session
  /// clears even offline, so stored tokens cannot resurrect it later.
  Future<Result<void>> logout() async {
    await _api.logout();
    try {
      await _storage.clear();
    } catch (_) {
      // Store unreachable — local sign-out proceeds regardless.
    }
    if (ref.mounted) {
      state = const SessionState(status: SessionStatus.signedOut);
    }
    return const Data(null);
  }

  /// Fetch the profile into the state. Never downgrades an already
  /// signed-out state if a fetch was in flight during logout, and never
  /// tears down an optimistic offline session on failure.
  Future<void> loadProfile() async {
    if (!ref.mounted || !state.signedIn) return;
    final result = await _api.fetchProfile();
    if (!ref.mounted || !state.signedIn) return;
    if (result case Data(:final value)) {
      state = SessionState(
        status: SessionStatus.signedIn,
        mustChangePassword: value.mustChangePassword,
        profile: value,
      );
    }
  }
}
