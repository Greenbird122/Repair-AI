import 'dart:ui' show PathMetric, PathMetrics;

import 'package:flutter/material.dart';

import '../core/theme.dart';

/// The ECG trace from the original SVG, in its native 1200x200 space:
/// flat baseline, small P wave, sharp QRS spike, rounded T wave, flat line.
Path _buildEcgPath() => Path()
  ..moveTo(0, 100)
  ..lineTo(420, 100)
  ..cubicTo(440, 100, 445, 78, 465, 78)
  ..cubicTo(485, 78, 490, 100, 510, 100)
  ..lineTo(545, 100)
  ..lineTo(560, 112)
  ..lineTo(585, 6)
  ..lineTo(612, 186)
  ..lineTo(632, 100)
  ..lineTo(680, 100)
  ..cubicTo(710, 100, 715, 62, 750, 62)
  ..cubicTo(785, 62, 790, 100, 820, 100)
  ..lineTo(1200, 100);

/// One bright amber dash that travels across the trace and fades toward the
/// screen edges — the Flutter equivalent of the SVG's `stroke-dasharray`
/// travel animation with its horizontal fade gradient.
class EcgPulsePainter extends CustomPainter {
  EcgPulsePainter({required this.progress});

  /// 0..1 across the whole travel (starts before the path, ends past it).
  final double progress;

  static final Path _path = _buildEcgPath();
  static final PathMetrics _metrics = _path.computeMetrics();
  static final PathMetric _metric = _metrics.first;
  static final double _length = _metric.length;

  @override
  void paint(Canvas canvas, Size size) {
    // Trace is designed for a 6:1 box; scale uniformly from the width.
    final double scale = size.width / 1200;
    canvas.scale(scale);

    // Normalized dash: 30% of the path length, moving from before the start
    // to beyond the end (matches dasharray 0.3 / dashoffset 0.3 -> -1).
    final double dash = 0.3 * _length;
    final double start = (progress * 1.3 - 0.3) * _length;
    final double from = start.clamp(0.0, _length);
    final double to = (start + dash).clamp(0.0, _length);
    if (to <= from) return;

    final Path segment = _metric.extractPath(from, to);

    // Screen-space fade gradient: transparent at the far edges, solid amber
    // through the middle (mirrors the SVG `#fade` linearGradient).
    final Paint base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..shader = const LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        stops: [0.0, 0.2, 0.8, 1.0],
        colors: [
          Color(0x00F5A012),
          Color(0xFFF5A012),
          Color(0xFFF5A012),
          Color(0x00F5A012),
        ],
      ).createShader(Offset.zero & size);

    // Soft glow pass under the crisp pass (drop-shadow in the original).
    final Paint glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = RepairColors.amber.withValues(alpha: 0.55)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

    canvas.drawPath(segment, glow);
    canvas.drawPath(segment, base);
  }

  @override
  bool shouldRepaint(EcgPulsePainter oldDelegate) =>
      oldDelegate.progress != progress;
}

/// Full-width ECG pulse line with a 6:1 aspect ratio, animated by [animation].
class EcgPulse extends StatelessWidget {
  const EcgPulse({super.key, required this.animation});

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 6,
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, _) => CustomPaint(
          painter: EcgPulsePainter(progress: animation.value),
          size: Size.infinite,
        ),
      ),
    );
  }
}
