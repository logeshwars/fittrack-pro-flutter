import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/auth_providers.dart';
import '../../../core/config/app_config.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final repository = ref.read(authRepositoryProvider);
    if (repository == null) return;
    setState(() { _busy = true; _error = null; });
    try {
      await repository.signInWithEmail(_email.text, _password.text);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Signed in successfully')),
      );
    } catch (_) {
      if (mounted) setState(() => _error = 'Sign-in failed. Check your credentials and try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Rebuild on Supabase session changes, including sign-in and sign-out.
    ref.watch(authStateProvider);
    final repository = ref.watch(authRepositoryProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Account')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text('FitTrack Pro', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 12),
            if (!AppConfig.hasSupabase)
              const Text('Supabase is not configured. Supply build-time dart-defines to enable login.')
            else if (repository?.currentUser != null) ...[
              Text('Signed in as ${repository!.currentUser!.email ?? 'user'}'),
              const SizedBox(height: 16),
              FilledButton(onPressed: _busy ? null : () async {
                setState(() => _busy = true);
                try { await repository.signOut(); }
                finally { if (mounted) setState(() => _busy = false); }
              }, child: const Text('Sign out')),
            ] else
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(labelText: 'Email'),
                      validator: (value) => value == null || !value.contains('@') ? 'Enter a valid email' : null,
                    ),
                    TextFormField(
                      controller: _password,
                      obscureText: true,
                      decoration: const InputDecoration(labelText: 'Password'),
                      validator: (value) => value == null || value.isEmpty ? 'Enter a password' : null,
                    ),
                    if (_error != null) Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                    ),
                    const SizedBox(height: 20),
                    FilledButton(onPressed: _busy ? null : _submit, child: Text(_busy ? 'Signing in…' : 'Sign in')),
                    const SizedBox(height: 12),
                    const Text('Google sign-in will be enabled after identity compatibility checks.'),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
