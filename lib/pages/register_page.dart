import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/theme.dart';
import '../features/auth/logic/session_controller.dart';
import '../features/locations/data/location_api.dart';
import '../features/locations/logic/location_providers.dart';
import '../features/network/data/api_exception.dart';
import '../features/network/data/result.dart';

/// Patient registration ('/register'). The server takes **names** for
/// country/county/sub_county (ids return empty lists), so the cascade
/// selects feed `Place.name` straight into the payload. Register does
/// not sign anyone in — success lands on '/login' with the phone filled.
class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final TextEditingController _firstName = TextEditingController();
  final TextEditingController _lastName = TextEditingController();
  final TextEditingController _phone = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _passwordConfirm = TextEditingController();
  bool _obscure = true;
  bool _busy = false;

  Place? _country;
  Place? _county;
  Place? _subCounty;

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _phone.dispose();
    _password.dispose();
    _passwordConfirm.dispose();
    super.dispose();
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(text)));
  }

  String _failureText(Object error) {
    if (error is ApiException) {
      return error.message ?? 'Something went wrong. Please try again.';
    }
    return 'Something went wrong. Please try again.';
  }

  String? _validate() {
    if (_firstName.text.trim().isEmpty) return 'Enter your first name.';
    if (_lastName.text.trim().isEmpty) return 'Enter your last name.';
    if (_phone.text.trim().isEmpty) return 'Enter your phone number.';
    if (_country == null) return 'Select your country.';
    if (_county == null) return 'Select your county.';
    if (_subCounty == null) return 'Select your sub-county.';
    if (_password.text.length < 8) {
      return 'Password must be at least 8 characters.';
    }
    if (_password.text != _passwordConfirm.text) {
      return 'Passwords don\'t match.';
    }
    return null;
  }

  Future<void> _submit() async {
    if (_busy) return;
    final problem = _validate();
    if (problem != null) {
      _message(problem);
      return;
    }
    setState(() => _busy = true);
    final phone = _phone.text.trim();
    final result = await ref.read(sessionProvider.notifier).register(
          country: _country!.name,
          county: _county!.name,
          subCounty: _subCounty!.name,
          phone: phone,
          firstName: _firstName.text.trim(),
          lastName: _lastName.text.trim(),
          password: _password.text,
          passwordConfirm: _passwordConfirm.text,
        );
    if (!mounted) return;
    setState(() => _busy = false);
    switch (result) {
      case Data():
        _message('Account created — sign in to continue.');
        context.go('/login?phone=${Uri.encodeQueryComponent(phone)}');
      case Error(:final error):
        _message(_failureText(error));
      case Offline():
        _message('You are offline. Check your connection and try again.');
    }
  }

  /// One cascading picker. `async` is null until the parent choice
  /// exists; load failures and offline replace the field with a retry.
  Widget _placeField({
    required String label,
    required Place? selected,
    required AsyncValue<Result<List<Place>>>? async,
    required void Function(Place?) onChanged,
    required VoidCallback onRetry,
  }) {
    if (async == null) {
      return DropdownButtonFormField<Place>(
        key: ValueKey('$label:none'),
        initialValue: null,
        decoration: InputDecoration(
          labelText: label,
          hintText: 'Choose ${label.toLowerCase()} first',
          border: const OutlineInputBorder(),
        ),
        items: const [],
        disabledHint: Text('Choose one first'),
        onChanged: null,
      );
    }
    return async.when(
      loading: () => DropdownButtonFormField<Place>(
        key: ValueKey('$label:loading'),
        initialValue: null,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        items: const [],
        disabledHint: const Text('Loading…'),
        onChanged: null,
      ),
      error: (error, _) => _placeFieldError(label, onRetry),
      data: (result) => switch (result) {
        Data(:final value) => DropdownButtonFormField<Place>(
              key: ValueKey('$label:${selected?.id ?? 'none'}'),
              initialValue: selected,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: label,
                border: const OutlineInputBorder(),
              ),
              items: [
                for (final place in value)
                  DropdownMenuItem(value: place, child: Text(place.name)),
              ],
              // An empty parent result (no counties for that country)
              // has nothing to pick; the field simply stays shut.
              onChanged: value.isEmpty ? null : onChanged,
            ),
        Error() => _placeFieldError(label, onRetry),
        Offline() => _placeFieldError(
            label,
            onRetry,
            message: 'You are offline. Check your connection and try again.',
          ),
      },
    );
  }

  Widget _placeFieldError(String label, VoidCallback onRetry,
      {String message = 'Couldn\'t load options.'}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
          ),
          child: Text(
            message,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(onPressed: onRetry, child: const Text('Retry')),
        ),
      ],
    );
  }

  TextField _textField({
    required TextEditingController controller,
    required String label,
    TextInputType? keyboardType,
    bool obscure = false,
    IconData? prefixIcon,
    Widget? suffix,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscure,
      autofillHints: keyboardType == TextInputType.phone
          ? const [AutofillHints.telephoneNumber]
          : null,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: prefixIcon == null ? null : Icon(prefixIcon),
        suffixIcon: suffix,
        border: const OutlineInputBorder(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final countries = ref.watch(countriesProvider);
    final counties = _country == null
        ? null
        : ref.watch(countiesProvider(_country!.name));
    final subCounties = _county == null
        ? null
        : ref.watch(subCountiesProvider(_county!.name));

    return Scaffold(
      appBar: AppBar(
        title: const Text('RepairAI'),
        backgroundColor: RepairColors.bgCenter,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Create your account',
                textAlign: TextAlign.center,
                style: RepairText.wordmark(28),
              ),
              const SizedBox(height: 8),
              Text(
                'Heal · Support · Hope',
                textAlign: TextAlign.center,
                style: RepairText.tagline(13),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: _textField(
                      controller: _firstName,
                      label: 'First name',
                      prefixIcon: Icons.person_outline,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _textField(
                      controller: _lastName,
                      label: 'Last name',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _textField(
                controller: _phone,
                label: 'Phone number',
                keyboardType: TextInputType.phone,
                prefixIcon: Icons.phone_outlined,
              ),
              const SizedBox(height: 16),
              _placeField(
                label: 'Country',
                selected: _country,
                async: countries,
                onChanged: (place) => setState(() {
                  _country = place;
                  _county = null;
                  _subCounty = null;
                }),
                onRetry: () => ref.invalidate(countriesProvider),
              ),
              const SizedBox(height: 16),
              _placeField(
                label: 'County',
                selected: _county,
                async: counties,
                onChanged: (place) => setState(() {
                  _county = place;
                  _subCounty = null;
                }),
                onRetry: () {
                  if (_country != null) {
                    ref.invalidate(countiesProvider(_country!.name));
                  }
                },
              ),
              const SizedBox(height: 16),
              _placeField(
                label: 'Sub-county',
                selected: _subCounty,
                async: subCounties,
                onChanged: (place) => setState(() => _subCounty = place),
                onRetry: () {
                  if (_county != null) {
                    ref.invalidate(subCountiesProvider(_county!.name));
                  }
                },
              ),
              const SizedBox(height: 16),
              _textField(
                controller: _password,
                label: 'Password',
                obscure: _obscure,
                prefixIcon: Icons.lock_outline,
                suffix: IconButton(
                  icon: Icon(
                    _obscure ? Icons.visibility_off : Icons.visibility,
                  ),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              Text(
                'At least 8 characters.',
                style: RepairText.tagline(12),
              ),
              const SizedBox(height: 12),
              _textField(
                controller: _passwordConfirm,
                label: 'Confirm password',
                obscure: _obscure,
                prefixIcon: Icons.lock_outline,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _busy ? null : _submit,
                child: _busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Create account'),
              ),
              TextButton(
                onPressed: _busy ? null : () => context.go('/login'),
                child: const Text('Already have an account? Log in'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
