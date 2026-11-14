import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/auth/auth_providers.dart';
import '../../../core/auth/auth_repository.dart';
import '../../../core/config/app_config.dart';
import '../../../core/l10n/language_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/fittrack_tokens.dart';
import '../../../core/widgets/fittrack_components.dart';
import '../../../core/widgets/fittrack_icons.dart';

enum _AuthTab { login, signup }

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  _AuthTab _tab = _AuthTab.login;
  bool _busy = false;
  bool _showPassword = false;
  String? _error;
  String? _notice;
  String? _emailError;
  String? _passwordError;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final emailInvalid = context.t('common:emailError');
    final passwordInvalid = context.t('common:passwordError');
    final checkInbox = context.t('common:signupCheckInbox');
    final signInFailed = context.t('common:signInFailed');
    final emailBad = !_email.text.contains('@');
    final passwordBad = _password.text.length < 6;
    setState(() {
      _error = null;
      _notice = null;
      _emailError = emailBad ? emailInvalid : null;
      _passwordError = passwordBad ? passwordInvalid : null;
    });
    if (emailBad || passwordBad) return;

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
            _notice = checkInbox;
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
          _error = signInFailed;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _google() async {
    final googleFailed = context.t('common:googleFailed');
    final repository = ref.read(authRepositoryProvider);
    if (repository == null) return;
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      final outcome = await repository.signInWithGoogle();
      if (!mounted) return;
      if (outcome.status == GoogleSignInStatus.cancelled) return;
      context.go(outcome.isNewUser ? '/onboarding' : '/today');
    } on AuthFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = googleFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _switchTab(_AuthTab tab) => setState(() {
        _tab = tab;
        _error = null;
        _notice = null;
        _emailError = null;
        _passwordError = null;
      });

  @override
  Widget build(BuildContext context) {
    ref.watch(authStateProvider);
    final repository = ref.watch(authRepositoryProvider);
    final signedIn = repository?.currentUser != null;
    final colors = AppPalette.of(context);

    if (signedIn) {
      return Scaffold(
        backgroundColor: colors.surface,
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              FitTrackSpacing.xs,
              FitTrackSpacing.sm,
              FitTrackSpacing.xxl,
              FitTrackSpacing.xxl,
            ),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: FitTrackIconButton(
                  icon: FitIcons.back,
                  semanticLabel: context.t('settings:backLabel'),
                  onPressed: () =>
                      context.canPop() ? context.pop() : context.go('/today'),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(
                  left: FitTrackSpacing.xxl - FitTrackSpacing.xs,
                  top: FitTrackSpacing.xxl,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _BrandMark(),
                    const SizedBox(height: FitTrackSpacing.xl),
                    FitTrackCard(
                      padding: const EdgeInsets.all(FitTrackSpacing.xl),
                      child: Column(
                        children: [
                          Icon(
                            FitIcons.secure,
                            size: 38,
                            color: colors.accent,
                          ),
                          const SizedBox(height: FitTrackSpacing.md),
                          Text(
                            context.t('common:signedInTitle'),
                            style: FitTrackText.titleLg.copyWith(
                              color: colors.ink,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            repository!.currentUser!.email ??
                                context.t('common:accountFallback'),
                            style: FitTrackText.label
                                .copyWith(color: colors.muted),
                          ),
                          const SizedBox(height: FitTrackSpacing.xl),
                          FitTrackButton(
                            label: context.t('common:signOut'),
                            size: FitTrackButtonSize.lg,
                            fullWidth: true,
                            loading: _busy,
                            loadingLabel: context.t('common:signingOut'),
                            onPressed: _busy
                                ? null
                                : () async {
                                    setState(() => _busy = true);
                                    try {
                                      await repository.signOut();
                                    } finally {
                                      if (mounted) {
                                        setState(() => _busy = false);
                                      }
                                    }
                                  },
                          ),
                        ],
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

    final signup = _tab == _AuthTab.signup;
    return Scaffold(
      backgroundColor: colors.surface,
      body: SafeArea(
        child: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(
            FitTrackSpacing.xxl,
            FitTrackSpacing.xxl * 2,
            FitTrackSpacing.xxl,
            FitTrackSpacing.xxl,
          ),
          children: [
            const Align(
              alignment: Alignment.centerLeft,
              child: _BrandMark(),
            ),
            const SizedBox(height: FitTrackSpacing.xl),
            Text(
              context.t(signup ? 'common:signupTitle' : 'common:loginTitle'),
              style: FitTrackText.display.copyWith(
                color: colors.ink,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.52,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              context.t('common:loginSubtitle'),
              style: FitTrackText.body.copyWith(color: colors.muted),
            ),
            const SizedBox(height: 28),
            if (signup) ...[
              FitTrackTextField(
                label: context.t('common:nameFieldLabel'),
                controller: _name,
                hint: context.t('common:yourName'),
                textInputAction: TextInputAction.next,
                enabled: !_busy,
              ),
              const SizedBox(height: 14),
            ],
            FitTrackTextField(
              label: context.t('common:emailFieldLabel'),
              controller: _email,
              hint: context.t('common:emailPlaceholder'),
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              enabled: !_busy,
              errorText: _emailError,
            ),
            const SizedBox(height: 14),
            FitTrackTextField(
              label: context.t('common:passwordFieldLabel'),
              controller: _password,
              hint: context.t('common:minPasswordPlaceholder'),
              obscureText: !_showPassword,
              textInputAction: TextInputAction.done,
              enabled: !_busy,
              errorText: _passwordError,
              onSubmitted: (_) {
                if (!_busy && AppConfig.hasSupabase) {
                  unawaited(_submit());
                }
              },
              suffix: IconButton(
                tooltip: context.t(
                  _showPassword
                      ? 'common:hidePassword'
                      : 'common:showPassword',
                ),
                onPressed: () =>
                    setState(() => _showPassword = !_showPassword),
                icon: Icon(
                  _showPassword
                      ? FitIcons.eyeOff
                      : FitIcons.eye,
                  size: 18,
                  color: colors.muted,
                ),
              ),
            ),
            if (!signup)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  style: TextButton.styleFrom(
                    minimumSize: const Size(0, FitTrackSpacing.touchMin),
                    foregroundColor: colors.accent,
                  ),
                  onPressed: () => context.push('/auth/forgot-password'),
                  child: Text(
                    context.t('common:forgotPassword'),
                    style: FitTrackText.body.copyWith(
                      color: colors.accent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              )
            else
              const SizedBox(height: FitTrackSpacing.md),
            if (_error != null)
              _Banner(text: _error!, bg: colors.badSoft, fg: colors.textBad),
            if (_notice != null)
              _Banner(text: _notice!, bg: colors.okSoft, fg: colors.ok),
            const SizedBox(height: FitTrackSpacing.xs),
            FitTrackButton(
              label: context.t(
                signup ? 'common:createAccount' : 'common:signInButton',
              ),
              size: FitTrackButtonSize.lg,
              fullWidth: true,
              loading: _busy,
              onPressed: _busy || !AppConfig.hasSupabase ? null : _submit,
            ),
            Padding(
              padding:
                  const EdgeInsets.symmetric(vertical: FitTrackSpacing.xl),
              child: Row(
                children: [
                  Expanded(child: Divider(height: 1, color: colors.line)),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: FitTrackSpacing.md,
                    ),
                    child: Text(
                      context.t('common:or'),
                      style: FitTrackText.caption.copyWith(
                        color: colors.muted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Expanded(child: Divider(height: 1, color: colors.line)),
                ],
              ),
            ),
            FitTrackButton(
              label: context.t('common:continueGoogle'),
              icon: FitIcons.google,
              variant: FitTrackButtonVariant.secondary,
              size: FitTrackButtonSize.lg,
              fullWidth: true,
              onPressed: _busy ? null : _google,
            ),
            const SizedBox(height: FitTrackSpacing.lg),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    context.t(signup ? 'common:haveAccount' : 'common:newHere'),
                    style: FitTrackText.body.copyWith(color: colors.muted),
                  ),
                ),
                TextButton(
                  style: TextButton.styleFrom(
                    minimumSize: const Size(0, FitTrackSpacing.touchMin),
                    foregroundColor: colors.accent,
                  ),
                  onPressed: _busy
                      ? null
                      : () => _switchTab(
                            signup ? _AuthTab.login : _AuthTab.signup,
                          ),
                  child: Text(
                    context.t(
                      signup ? 'common:signInLink' : 'common:createAccountLink',
                    ),
                    style: FitTrackText.body.copyWith(
                      color: colors.accent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: FitTrackSpacing.lg),
            Text(
              context.t('common:legalText'),
              textAlign: TextAlign.center,
              style: FitTrackText.overline.copyWith(
                color: colors.muted,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    return Semantics(
      label: 'FitTrack Pro',
      child: ExcludeSemantics(
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: colors.accent,
            borderRadius: BorderRadius.circular(FitTrackRadius.md),
          ),
          alignment: Alignment.center,
          child: Text(
            'FT',
            style: FitTrackText.titleLg.copyWith(
              color: colors.accentText,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.text, required this.bg, required this.fg});
  final String text;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(top: FitTrackSpacing.sm),
        padding: const EdgeInsets.all(FitTrackSpacing.md),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(FitTrackRadius.sm),
        ),
        child: Text(
          text,
          style: FitTrackText.label.copyWith(color: fg, height: 1.45),
        ),
      ),
    );
  }
}
