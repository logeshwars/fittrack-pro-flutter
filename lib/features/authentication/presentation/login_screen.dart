import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/auth/auth_providers.dart';
import '../../../core/auth/auth_repository.dart';
import '../../../core/config/app_config.dart';
import '../../../core/theme/app_colors.dart';

enum _AuthTab { login, signup }

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  _AuthTab _tab = _AuthTab.login;
  bool _busy = false;
  bool _showPassword = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;

    final repository = ref.read(authRepositoryProvider);
    if (repository == null) return;

    setState(() => _busy = true);
    try {
      if (_tab == _AuthTab.signup) {
        final outcome = await repository.signUpWithEmail(
          email: _email.text,
          password: _password.text,
          name: _name.text,
        );
        if (!mounted) return;
        if (outcome.requiresVerification) {
          setState(() {
            _tab = _AuthTab.login;
            _error =
                'Account created. Check your inbox to verify your email, then log in.';
          });
          return;
        }
        context.go('/onboarding');
        return;
      }
      await repository.signInWithEmail(_email.text, _password.text);
      if (!mounted) return;
      var needsOnboarding = false;
      try {
        final profile = await repository.readOwnProfile();
        if (profile == null) {
          final userId = repository.currentUser?.id;
          final prefs = await SharedPreferences.getInstance();
          final completed = userId == null
              ? false
              : prefs.getBool('fittrack_onboarding_complete_$userId') ?? false;
          needsOnboarding = !completed;
        }
      } catch (_) {
        // A profile-read failure must not block a valid sign-in.
      }
      if (!mounted) return;
      context.go(needsOnboarding ? '/onboarding' : '/today');
    } on AuthFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Sign-in failed. Check your credentials and try again.';
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _google() async {
    final repository = ref.read(authRepositoryProvider);
    if (repository == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final outcome = await repository.signInWithGoogle();
      if (!mounted) return;
      if (outcome.status == GoogleSignInStatus.cancelled) return;
      context.go(outcome.isNewUser ? '/onboarding' : '/today');
    } on AuthFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Google sign-in failed. Try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(authStateProvider);
    final repository = ref.watch(authRepositoryProvider);
    final signedIn = repository?.currentUser != null;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final colors = AppPalette.of(context);
    final bg = dark ? const Color(0xFF080E00) : const Color(0xFFF5F5EE);
    final cardBg = dark ? const Color(0xFF0F1A00) : Colors.white;
    final inputBg = dark ? const Color(0xFF161F00) : const Color(0xFFF8F8F3);
    final inputBorder =
        dark ? const Color(0xFF2A3800) : const Color(0xFFE0E0D8);
    final placeholder =
        dark ? const Color(0xFF4A5A30) : const Color(0xFFAAAAAA);

    if (signedIn) {
      return Scaffold(
        backgroundColor: bg,
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () =>
                        context.canPop() ? context.pop() : context.go('/today'),
                    icon: Icon(Icons.arrow_back, color: colors.text),
                  ),
                  const Spacer(),
                ],
              ),
              const SizedBox(height: 48),
              _Brand(colors: colors),
              const SizedBox(height: 28),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: dark
                        ? const Color(0xFF1E2C00)
                        : const Color(0xFFE8E8E0),
                  ),
                ),
                child: Column(
                  children: [
                    Icon(Icons.verified_user, size: 38, color: colors.accent),
                    const SizedBox(height: 12),
                    Text(
                      'Signed in',
                      style: TextStyle(
                        color: colors.text,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      repository!.currentUser!.email ?? 'FitTrack Pro account',
                      style: TextStyle(color: colors.muted, fontSize: 13),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _busy
                            ? null
                            : () async {
                                setState(() => _busy = true);
                                try {
                                  await repository.signOut();
                                } finally {
                                  if (mounted) setState(() => _busy = false);
                                }
                              },
                        style: FilledButton.styleFrom(
                          backgroundColor: colors.accent,
                          foregroundColor: colors.accentText,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(_busy ? 'Signing out…' : 'Sign out'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(20, 52, 20, 40),
          children: [
            _Brand(colors: colors),
            const SizedBox(height: 28),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color:
                      dark ? const Color(0xFF1E2C00) : const Color(0xFFE8E8E0),
                ),
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: dark
                            ? const Color(0xFF0C1200)
                            : const Color(0xFFEFEFEA),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: _TabButton(
                              label: 'Login',
                              active: _tab == _AuthTab.login,
                              onTap: () => setState(() {
                                _tab = _AuthTab.login;
                                _error = null;
                              }),
                            ),
                          ),
                          Expanded(
                            child: _TabButton(
                              label: 'Sign Up',
                              active: _tab == _AuthTab.signup,
                              onTap: () => setState(() {
                                _tab = _AuthTab.signup;
                                _error = null;
                              }),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    if (_tab == _AuthTab.signup) ...[
                      _FieldLabel(text: 'FULL NAME', dark: dark),
                      const SizedBox(height: 6),
                      _InputShell(
                        background: inputBg,
                        border: inputBorder,
                        child: TextFormField(
                          controller: _name,
                          style: TextStyle(color: colors.text),
                          decoration: InputDecoration(
                            isDense: true,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            filled: false,
                            hintText: 'Your name',
                            hintStyle: TextStyle(color: placeholder),
                            prefixIcon: Icon(Icons.person_outline,
                                size: 18, color: placeholder),
                            prefixIconConstraints:
                                const BoxConstraints(minWidth: 34),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],
                    _FieldLabel(text: 'EMAIL', dark: dark),
                    const SizedBox(height: 6),
                    _InputShell(
                      background: inputBg,
                      border: inputBorder,
                      child: TextFormField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        autocorrect: false,
                        style: TextStyle(color: colors.text),
                        decoration: InputDecoration(
                          isDense: true,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          filled: false,
                          hintText: 'you@example.com',
                          hintStyle: TextStyle(color: placeholder),
                          prefixIcon: Icon(Icons.mail_outline,
                              size: 18, color: placeholder),
                          prefixIconConstraints:
                              const BoxConstraints(minWidth: 34),
                        ),
                        validator: (value) =>
                            value == null || !value.contains('@')
                                ? 'Enter a valid email'
                                : null,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _FieldLabel(text: 'PASSWORD', dark: dark),
                    const SizedBox(height: 6),
                    _InputShell(
                      background: inputBg,
                      border: inputBorder,
                      child: TextFormField(
                        controller: _password,
                        obscureText: !_showPassword,
                        style: TextStyle(color: colors.text),
                        decoration: InputDecoration(
                          isDense: true,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          filled: false,
                          hintText: 'Minimum 6 characters',
                          hintStyle: TextStyle(color: placeholder),
                          prefixIcon: Icon(Icons.lock_outline,
                              size: 18, color: placeholder),
                          prefixIconConstraints:
                              const BoxConstraints(minWidth: 34),
                          suffixIcon: IconButton(
                            onPressed: () =>
                                setState(() => _showPassword = !_showPassword),
                            icon: Icon(
                              _showPassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              size: 18,
                              color: placeholder,
                            ),
                          ),
                        ),
                        validator: (value) => value == null || value.length < 6
                            ? 'Password must be at least 6 characters'
                            : null,
                      ),
                    ),
                    if (_tab == _AuthTab.login)
                      Align(
                        alignment: Alignment.centerRight,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: InkWell(
                            onTap: () => context.push('/auth/forgot-password'),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Text(
                                'Forgot password?',
                                style: TextStyle(
                                  color: colors.accent,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (_error != null)
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(top: 14),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE24B4A).withValues(alpha: .10),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color:
                                const Color(0xFFE24B4A).withValues(alpha: .25),
                          ),
                        ),
                        child: Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFFE24B4A),
                            fontSize: 13,
                          ),
                        ),
                      ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed:
                            _busy || !AppConfig.hasSupabase ? null : _submit,
                        style: FilledButton.styleFrom(
                          backgroundColor: colors.accent,
                          foregroundColor: colors.accentText,
                          disabledBackgroundColor:
                              colors.accent.withValues(alpha: .35),
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _busy
                            ? SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: colors.accentText,
                                ),
                              )
                            : Text(
                                _tab == _AuthTab.login
                                    ? 'Login'
                                    : 'Create Account',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                            child: Divider(
                                color: dark
                                    ? const Color(0xFF1E2C00)
                                    : const Color(0xFFE0E0D8))),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            'OR',
                            style: TextStyle(
                              color: dark
                                  ? const Color(0xFF3A4A20)
                                  : const Color(0xFFAAAAAA),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Expanded(
                            child: Divider(
                                color: dark
                                    ? const Color(0xFF1E2C00)
                                    : const Color(0xFFE0E0D8))),
                      ],
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: _busy ? null : _google,
                      icon: const Icon(Icons.g_mobiledata, size: 28),
                      label: const Text('Continue with Google'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                        side: BorderSide(color: inputBorder),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'By continuing, you agree to FitTrack Pro terms and privacy policy.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                height: 1.5,
                color: dark ? const Color(0xFF2E3D18) : const Color(0xFFBBBBBB),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand({required this.colors});
  final AppPalette colors;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: const Color(0xFF0C1200),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: .18)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.white.withValues(alpha: .10),
                    blurRadius: 16,
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.fitness_center,
                  size: 28, color: Colors.white),
            ),
            Positioned(
              right: -4,
              bottom: -4,
              child: Container(
                width: 20,
                height: 20,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child:
                    const Icon(Icons.bolt, size: 12, color: Color(0xFF0C1200)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              'FitTrack',
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w900,
                letterSpacing: -.5,
                color: colors.text,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              margin: const EdgeInsets.only(bottom: 3),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: colors.accent,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'PRO',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: colors.accentText,
                  letterSpacing: 1,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Train smarter. Progress further.',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            letterSpacing: .3,
            color: colors.muted,
          ),
        ),
      ],
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: active ? colors.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: active ? colors.accentText : colors.muted,
          ),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.text, required this.dark});
  final String text;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        style: TextStyle(
          color: dark ? const Color(0xFF5A6E3A) : const Color(0xFF888880),
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _InputShell extends StatelessWidget {
  const _InputShell({
    required this.background,
    required this.border,
    required this.child,
  });

  final Color background;
  final Color border;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border),
      ),
      child: child,
    );
  }
}
