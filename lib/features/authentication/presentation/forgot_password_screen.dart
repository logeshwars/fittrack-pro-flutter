import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/auth/auth_providers.dart';
import '../../../core/l10n/language_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/fittrack_tokens.dart';
import '../../../core/widgets/fittrack_components.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _email = TextEditingController();
  bool _loading = false;
  bool _sent = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final email = _email.text.trim();
    final invalid = context.t('common:emailError');
    final notConfigured = context.t('common:resetNotConfigured');
    final failed = context.t('common:resetFailed');
    setState(() => _error = null);
    if (!email.contains('@') || !email.contains('.')) {
      setState(() => _error = invalid);
      return;
    }

    final repository = ref.read(authRepositoryProvider);
    if (repository == null) {
      setState(() => _error = notConfigured);
      return;
    }

    setState(() => _loading = true);
    try {
      await repository.resetPassword(email);
      if (!mounted) return;
      setState(() => _sent = true);
    } catch (_) {
      if (mounted) {
        setState(() => _error = failed);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            FitTrackSpacing.xs,
            FitTrackSpacing.sm,
            FitTrackSpacing.sm,
            FitTrackSpacing.xxl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FitTrackIconButton(
                icon: Icons.arrow_back,
                semanticLabel: context.t('common:backToLogin'),
                onPressed: () => context.pop(),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  FitTrackSpacing.xxl - FitTrackSpacing.xs,
                  FitTrackSpacing.xxl,
                  FitTrackSpacing.xxl - FitTrackSpacing.sm,
                  0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      context.t('common:resetTitle'),
                      style: FitTrackText.screenTitle.copyWith(
                        color: colors.ink,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: FitTrackSpacing.sm - 2),
                    Text(
                      context.t('common:resetSubtitle'),
                      style: FitTrackText.body.copyWith(
                        color: colors.muted,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: FitTrackSpacing.xxl),
                    FitTrackTextField(
                      label: context.t('common:emailFieldLabel'),
                      controller: _email,
                      hint: context.t('common:emailPlaceholder'),
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.done,
                      enabled: !_loading,
                      errorText: _error,
                      onSubmitted: (_) {
                        if (!_loading) {
                          unawaited(_send());
                        }
                      },
                    ),
                    const SizedBox(height: FitTrackSpacing.lg),
                    FitTrackButton(
                      label: context.t('common:sendResetLink'),
                      size: FitTrackButtonSize.lg,
                      fullWidth: true,
                      loading: _loading,
                      onPressed: _loading ? null : _send,
                    ),
                    if (_sent) ...[
                      const SizedBox(height: FitTrackSpacing.lg),
                      Semantics(
                        liveRegion: true,
                        child: Container(
                          padding: const EdgeInsets.all(FitTrackSpacing.md),
                          decoration: BoxDecoration(
                            color: colors.okSoft,
                            borderRadius:
                                BorderRadius.circular(FitTrackRadius.sm),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                context.t('common:resetBanner'),
                                style: FitTrackText.label.copyWith(
                                  color: colors.ok,
                                  height: 1.45,
                                ),
                              ),
                              const SizedBox(height: FitTrackSpacing.xs),
                              Text(
                                '${context.t('common:resetLinkSentDesc')} '
                                '${_email.text.trim()}',
                                style: FitTrackText.label.copyWith(
                                  color: colors.ok,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: FitTrackSpacing.lg),
                      FitTrackButton(
                        label: context.t('common:backToLogin'),
                        variant: FitTrackButtonVariant.secondary,
                        size: FitTrackButtonSize.lg,
                        fullWidth: true,
                        onPressed: () => context.pop(),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
