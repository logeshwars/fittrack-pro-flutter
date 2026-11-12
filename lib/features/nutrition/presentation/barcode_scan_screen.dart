import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../core/data/service_providers.dart';

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
        content: const Text('No nutrition data found for this barcode'),
        action: SnackBarAction(
          label: 'Enter manually',
          onPressed: () => router.pushReplacement('/nutrition/log'),
        ),
      ),
    );
    // Allow the same code to be retried after a short pause.
    Timer(const Duration(seconds: 3), () => _lastCode = null);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error, child) => _PermissionError(
              message: error.errorCode == MobileScannerErrorCode.permissionDenied
                  ? 'Grant camera permission to scan product barcodes.'
                  : 'The camera is unavailable.',
              onManual: () => context.pushReplacement('/nutrition/log'),
            ),
          ),
          const Center(child: _ScannerFrame()),
          Align(
            alignment: Alignment.center,
            child: Padding(
              padding: const EdgeInsets.only(top: 260),
              child: Text(
                _busy ? 'LOOKING UP PRODUCT…' : 'POINT AT A PRODUCT BARCODE',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: .5,
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Back',
                    onPressed: () => context.pop(),
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Torch',
                    onPressed: () async {
                      await _controller.toggleTorch();
                      if (mounted) {
                        setState(() => _torch = !_torch);
                      }
                    },
                    icon: Icon(
                      _torch ? Icons.flash_on : Icons.flash_off,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: OutlinedButton.icon(
                  onPressed: () => context.pushReplacement('/nutrition/log'),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Enter manually'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white54),
                  ),
                ),
              ),
            ),
          ),
          if (_busy)
            const Positioned.fill(
              child: ColoredBox(
                color: Color(0xB3000000),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
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
      color: Colors.black,
      padding: const EdgeInsets.all(32),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Camera Access Required',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 24),
          OutlinedButton(
            onPressed: onManual,
            style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
            child: const Text('Enter manually'),
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
    const side = BorderSide(color: Colors.white, width: 3);
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
              child: Divider(color: Colors.white70, thickness: 2),
            ),
          ),
        ],
      ),
    );
  }
}
