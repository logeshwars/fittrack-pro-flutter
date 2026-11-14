import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../core/data/service_providers.dart';
import '../../../core/l10n/language_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/fittrack_tokens.dart';
import '../../../core/widgets/fittrack_components.dart';
import 'scan_chrome.dart';
import '../../../core/widgets/fittrack_icons.dart';

/// Live barcode scanner. A hit is looked up (OpenFoodFacts world, India
/// mirror, v0, then USDA) and handed to the food log screen.
class BarcodeScanScreen extends ConsumerStatefulWidget {
  const BarcodeScanScreen({super.key});

  @override
  ConsumerState<BarcodeScanScreen> createState() => _BarcodeScanScreenState();
}

class _BarcodeScanScreenState extends ConsumerState<BarcodeScanScreen> {
  final _controller = MobileScannerController(
    formats: const [
      BarcodeFormat.ean13,
      BarcodeFormat.ean8,
      BarcodeFormat.upcA,
      BarcodeFormat.upcE,
      BarcodeFormat.code128,
      BarcodeFormat.code39,
    ],
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  bool _busy = false;
  String? _lastCode;
  bool _torch = false;

  @override
  void dispose() {
    unawaited(_controller.dispose());
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_busy) {
      return;
    }
    String? code;
    for (final b in capture.barcodes) {
      final v = b.rawValue;
      if (v != null && v.isNotEmpty) {
        code = v;
        break;
      }
    }
    if (code == null || code == _lastCode) {
      return;
    }
    _lastCode = code;
    setState(() => _busy = true);
    final router = GoRouter.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final noData = context.t('nutrition:noNutritionData');
    final enterManually = context.t('nutrition:enterManually');
    final food = await ref.read(foodSearchServiceProvider).lookupBarcode(code);
    if (!mounted) {
      return;
    }
    if (food != null) {
      router.pushReplacement('/nutrition/log', extra: food);
      return;
    }
    setState(() => _busy = false);
    messenger.showSnackBar(
      SnackBar(
        content: Text(noData),
        action: SnackBarAction(
          label: enterManually,
          onPressed: () => router.pushReplacement('/nutrition/log'),
        ),
      ),
    );
    // Allow the same code to be retried after a short pause.
    Timer(const Duration(seconds: 3), () => _lastCode = null);
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Scaffold(
      backgroundColor: FitTrackCamera.bg(brightness),
      body: SafeArea(
        child: Column(
          children: [
            const ScanHeader(photoSelected: false),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  FitTrackSpacing.lg,
                  FitTrackSpacing.lg,
                  FitTrackSpacing.lg,
                  0,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(FitTrackRadius.card),
                  child: ColoredBox(
                    color: FitTrackCamera.panel,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        MobileScanner(
                          controller: _controller,
                          onDetect: _onDetect,
                          errorBuilder: (context, error, child) =>
                              _PermissionError(
                            message: context.t(
                              error.errorCode ==
                                      MobileScannerErrorCode.permissionDenied
                                  ? 'nutrition:cameraPermissionDesc'
                                  : 'nutrition:cameraUnavailable',
                            ),
                            onManual: () =>
                                context.pushReplacement('/nutrition/log'),
                          ),
                        ),
                        const Center(child: _ScannerFrame()),
                        Align(
                          alignment: Alignment.bottomCenter,
                          child: Padding(
                            padding: const EdgeInsets.only(
                              bottom: FitTrackSpacing.lg,
                            ),
                            child: Text(
                              context.t(
                                _busy
                                    ? 'nutrition:barcodeLooking'
                                    : 'nutrition:barcodePoint',
                              ),
                              style: FitTrackText.label.copyWith(
                                color: FitTrackCamera.muted,
                              ),
                            ),
                          ),
                        ),
                        Align(
                          alignment: Alignment.topRight,
                          child: IconButton(
                            tooltip: context.t('nutrition:torchLabel'),
                            onPressed: () async {
                              await _controller.toggleTorch();
                              if (mounted) {
                                setState(() => _torch = !_torch);
                              }
                            },
                            icon: Icon(
                              _torch ? FitIcons.flashOn : FitIcons.flashOff,
                              color: FitTrackCamera.ink,
                            ),
                          ),
                        ),
                        if (_busy)
                          const ColoredBox(
                            color: AppTheme.scrim,
                            child: Center(child: CircularProgressIndicator()),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(FitTrackSpacing.lg),
              child: FitTrackButton(
                label: context.t('nutrition:enterManually'),
                icon: FitIcons.edit,
                variant: FitTrackButtonVariant.secondary,
                fullWidth: true,
                onPressed: () => context.pushReplacement('/nutrition/log'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PermissionError extends StatelessWidget {
  const _PermissionError({required this.message, required this.onManual});
  final String message;
  final VoidCallback onManual;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: FitTrackCamera.panel,
      padding: const EdgeInsets.all(FitTrackSpacing.xxl),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            context.t('nutrition:cameraAccessRequired'),
            textAlign: TextAlign.center,
            style: FitTrackText.titleLg.copyWith(
              color: FitTrackCamera.ink,
            ),
          ),
          const SizedBox(height: FitTrackSpacing.md),
          Text(
            message,
            textAlign: TextAlign.center,
            style: FitTrackText.body.copyWith(color: FitTrackCamera.muted),
          ),
          const SizedBox(height: FitTrackSpacing.xxl),
          FitTrackButton(
            label: context.t('nutrition:enterManually'),
            variant: FitTrackButtonVariant.secondary,
            onPressed: onManual,
          ),
        ],
      ),
    );
  }
}

class _ScannerFrame extends StatelessWidget {
  const _ScannerFrame();

  @override
  Widget build(BuildContext context) {
    Widget corner({
      required Alignment alignment,
      required BorderRadius radius,
      required Border border,
    }) =>
        Align(
          alignment: alignment,
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(border: border, borderRadius: radius),
          ),
        );
    const side = BorderSide(color: FitTrackCamera.ink, width: 3);
    return SizedBox(
      width: 256,
      height: 176,
      child: Stack(
        children: [
          corner(
            alignment: Alignment.topLeft,
            radius: const BorderRadius.only(topLeft: Radius.circular(6)),
            border: const Border(top: side, left: side),
          ),
          corner(
            alignment: Alignment.topRight,
            radius: const BorderRadius.only(topRight: Radius.circular(6)),
            border: const Border(top: side, right: side),
          ),
          corner(
            alignment: Alignment.bottomLeft,
            radius: const BorderRadius.only(bottomLeft: Radius.circular(6)),
            border: const Border(bottom: side, left: side),
          ),
          corner(
            alignment: Alignment.bottomRight,
            radius: const BorderRadius.only(bottomRight: Radius.circular(6)),
            border: const Border(bottom: side, right: side),
          ),
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Divider(color: FitTrackCamera.muted, thickness: 2),
            ),
          ),
        ],
      ),
    );
  }
}
