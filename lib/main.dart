import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/routes.dart';
import 'core/theme.dart';
import 'features/auth/data/secure_token_storage.dart';
import 'features/network/data/api_client.dart';
import 'features/network/data/token_storage.dart';
import 'features/network/logic/network_providers.dart';

void main() {
  runApp(const RepairAiApp());
}

/// The production token store: encrypted at rest (Android
/// EncryptedSharedPreferences). A single stable instance so rebuilds
/// never recompute the provider chain.
final TokenStorage _productionStorage = SecureTokenStorage();

/// App root. [ProviderScope] lives *inside* it, so any bare pump of this
/// widget — production or test — reaches the providers, and nothing can
/// silently lose the scope by forgetting to wrap. The router comes from
/// [routerProvider], which re-runs auth redirects on session changes.
class RepairAiApp extends StatelessWidget {
  const RepairAiApp({super.key, this.tokenStorage, this.apiClient});

  /// Test seams; `null` each means production wiring (encrypted store,
  /// shared client). Riverpod 3 keeps the override type unnameable, so
  /// the seams travel as the values they wrap.
  final TokenStorage? tokenStorage;
  final ApiClient? apiClient;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        tokenStorageProvider.overrideWithValue(tokenStorage ?? _productionStorage),
        if (apiClient != null) apiClientProvider.overrideWithValue(apiClient!),
      ],
      child: Consumer(
        builder: (context, ref, _) => MaterialApp.router(
          title: 'RepairAI',
          debugShowCheckedModeBanner: false,
          theme: RepairTheme.light,
          routerConfig: ref.watch(routerProvider),
        ),
      ),
    );
  }
}
