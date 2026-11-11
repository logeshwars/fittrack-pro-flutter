import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class BarcodeScanScreen extends StatelessWidget {
  const BarcodeScanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 1.2,
                    colors: [
                      Color(0xFF252525),
                      Color(0xFF060606),
                      Colors.black,
                    ],
                  ),
                ),
              ),
            ),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const _ScannerFrame(),
                  const SizedBox(height: 20),
                  const Text(
                    'POINT AT A PRODUCT BARCODE',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: .5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Camera scanning will activate after the Flutter camera integration is added.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: .58),
                      fontSize: 11,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 20),
                  OutlinedButton.icon(
                    onPressed: () => context.replace('/nutrition/draft'),
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Enter manually'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(
                        color: Colors.white.withValues(alpha: .3),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              left: 16,
              top: 12,
              child: InkWell(
                onTap: () => context.pop(),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: .6),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: .2),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.arrow_back,
                    size: 18,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScannerFrame extends StatelessWidget {
  const _ScannerFrame();

  @override
  Widget build(BuildContext context) {
    const size = Size(256, 176);
    return SizedBox(
      width: size.width,
      height: size.height,
      child: CustomPaint(
        painter: _ScannerPainter(),
      ),
    );
  }
}

class _ScannerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final bracket = Paint()
      ..color = Colors.white
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.square;
    const arm = 28.0;

    canvas.drawLine(const Offset(0, arm), Offset.zero, bracket);
    canvas.drawLine(Offset.zero, const Offset(arm, 0), bracket);
    canvas.drawLine(
      Offset(size.width - arm, 0),
      Offset(size.width, 0),
      bracket,
    );
    canvas.drawLine(
      Offset(size.width, 0),
      Offset(size.width, arm),
      bracket,
    );
    canvas.drawLine(
      Offset(0, size.height - arm),
      Offset(0, size.height),
      bracket,
    );
    canvas.drawLine(
      Offset(0, size.height),
      Offset(arm, size.height),
      bracket,
    );
    canvas.drawLine(
      Offset(size.width - arm, size.height),
      Offset(size.width, size.height),
      bracket,
    );
    canvas.drawLine(
      Offset(size.width, size.height),
      Offset(size.width, size.height - arm),
      bracket,
    );

    final line = Paint()
      ..color = Colors.white.withValues(alpha: .8)
      ..strokeWidth = 2;
    canvas.drawLine(
      Offset(8, size.height / 2),
      Offset(size.width - 8, size.height / 2),
      line,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
