import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/theme.dart';
import '../features/auth/logic/session_controller.dart';
import '../features/network/data/api_exception.dart';
import '../features/network/data/result.dart';

/// Phone + password sign-in ('/login'). Register success lands here with
/// the phone pre-filled (`/login?phone=...`). A forced password change
/// reroutes through the guard — this page never branches on that flag.
class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final TextEditingController _phone = TextEditingController();
  final TextEditingController _password = TextEditingController();
  bool _obscure = true;
  bool _busy = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Prefill from `/login?phone=...` (register hand-off). Controller
    // writes stay out of build(); the isEmpty guard keeps a user-cleared
    // field from being re-injected on later dependency changes.
    final prefill = GoRouterState.of(context).uri.queryParameters['phone'];
    if (prefill != null && prefill.isNotEmpty && _phone.text.isEmpty) {
      _phone.text = prefill;
    }
  }

  @override
  void dispose() {
    _phone.dispose();
    _password.dispose();
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

  Future<void> _submit() async {
    if (_busy) return;
    final phone = _phone.text.trim();
    if (phone.isEmpty) {
      _message('Enter your phone number.');
      return;
    }
    if (_password.text.isEmpty) {
      _message('Enter your password.');
      return;
    }
    setState(() => _busy = true);
    final result = await ref
        .read(sessionProvider.notifier)
        .login(phone: phone, password: _password.text);
    if (!mounted) return;
    setState(() => _busy = false);
    switch (result) {
      case Data():
        context.go('/home');
      case Error(:final error):
        _message(_failureText(error));
      case Offline():
        _message('You are offline. Check your connection and try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
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
                'Welcome back',
                textAlign: TextAlign.center,
                style: RepairText.wordmark(30),
              ),
              const SizedBox(height: 8),
              Text(
                'Log in to continue',
                textAlign: TextAlign.center,
                style: RepairText.tagline(14),
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                autofillHints: const [AutofillHints.telephoneNumber],
                decoration: const InputDecoration(
                  labelText: 'Phone number',
                  hintText: '+254 7XX XXX XXX',
                  prefixIcon: Icon(Icons.phone_outlined),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _password,
                obscureText: _obscure,
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock_outline),
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscure ? Icons.visibility_off : Icons.visibility,
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
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
                    : const Text('Log in'),
              ),
              TextButton(
                onPressed: _busy ? null : () => context.go('/register'),
                child: const Text('Create an account'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
