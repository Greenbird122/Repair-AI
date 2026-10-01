import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../widgets/ecg_pulse.dart';

/// Splash screen recreating the RepairAI web intro, beat for beat:
///
/// 0.1s  emblem fades/scales in
/// 2.2s  heartbeat — emblem pumps, ring blooms, ECG spike hits center
/// 3.5s  ECG sweep finishes crossing the screen
/// 3.4s  "RepairAI" wordmark rises in
/// 4.1s  "Heal · Support · Hope" tagline fades in
class SplashPage extends StatefulWidget {
  const SplashPage({super.key, required this.onFinished});

  /// Called once the intro timeline has fully played out.
  final VoidCallback onFinished;

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  /// Master clock for the whole 5s intro. Every animation is a windowed
  /// phase of this clock, mirroring the CSS animation-delay table.
  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 5),
  )..forward();

  late final Animation<double> _logoIn = _phase(0.1, 1.0, Curves.easeOutCubic);
  late final Animation<double> _pulseTravel = _phase(0.9, 3.5, Curves.linear);
  late final Animation<double> _beat = _phase(2.2, 2.75, Curves.easeOut);
  late final Animation<double> _ring = _phase(2.2, 3.4, Curves.easeOut);
  late final Animation<double> _word = _phase(3.4, 4.4, Curves.easeOut);
  late final Animation<double> _tagline = _phase(4.1, 5.0, Curves.easeOut);

  Timer? _doneTimer;

  /// A 0..1 value over the [start, end] window (seconds) of the master clock.
  Animation<double> _phase(double start, double end, Curve curve) =>
      Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(
          parent: _clock,
          curve: Interval(start / 5, end / 5, curve: curve),
        ),
      );

  @override
  void initState() {
    super.initState();
    _doneTimer = Timer(const Duration(milliseconds: 5400), widget.onFinished);
  }

  @override
  void dispose() {
    _doneTimer?.cancel();
    _clock.dispose();
    super.dispose();
  }

  /// 1 -> 1.04 -> 1 heartbeat pump for the emblem (CSS `beat` keyframe).
  double _beatScale(double t) {
    if (t <= 0 || t >= 1) return 1.0;
    if (t < 0.35) return 1.0 + 0.04 * Curves.easeOut.transform(t / 0.35);
    return 1.0 + 0.04 * (1 - Curves.easeIn.transform((t - 0.35) / 0.65));
  }

  @override
  Widget build(BuildContext context) {
    final Size screen = MediaQuery.sizeOf(context);

    // Emblem sizing from the CSS: min(60vw, 42dvh, 300px), aspect 563/720.
    final double emblemW =
        math.min(math.min(0.6 * screen.width, 0.42 * screen.height), 300);
    final double emblemH = emblemW * 720 / 563;

    // The ECG line and bloom ring both cross at 68% of the emblem height
    // ("baby height" in the original design).
    final double beatY = emblemH * 0.68;
    final double pulseH = screen.width / 6; // ECG box keeps its 6:1 ratio

    // Wordmark / tagline sizes: clamp(38px, 11vw, 60px) and clamp(14px, 3.8vw, 18px).
    final double wordSize =
        math.min(math.max(0.11 * screen.width, 38), 60);
    final double taglineSize =
        math.min(math.max(0.038 * screen.width, 14), 18);

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.16), // circle at 50% 42%
            radius: 1.2,
            colors: [RepairColors.bgCenter, RepairColors.bgEdge],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // --- emblem + full-width ECG sweep + bloom ring ---
                SizedBox(
                  width: emblemW,
                  height: emblemH,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // ECG line spans the whole screen width, passing behind
                      // the emblem at baby height.
                      Positioned(
                        left: (emblemW - screen.width) / 2,
                        top: beatY - pulseH / 2,
                        width: screen.width,
                        height: pulseH,
                        child: EcgPulse(animation: _pulseTravel),
                      ),
                      // Ring blooms outward from the beat point as it hits.
                      AnimatedBuilder(
                        animation: _ring,
                        builder: (context, _) {
                          final double t = _ring.value;
                          if (t <= 0 || t >= 1) return const SizedBox.shrink();
                          final double d =
                              emblemW * 1.2 * (0.5 + 0.65 * t);
                          return Positioned(
                            left: emblemW / 2 - d / 2,
                            top: beatY - d / 2,
                            child: Container(
                              width: d,
                              height: d,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: RepairColors.amber
                                      .withValues(alpha: 0.55 * (1 - t)),
                                  width: 2,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      // The emblem, fading in and pumping on the beat.
                      AnimatedBuilder(
                        animation: Listenable.merge([_logoIn, _beat]),
                        builder: (context, child) => Opacity(
                          opacity: _logoIn.value,
                          child: Transform.scale(
                            scale: _beatScale(_beat.value),
                            origin: Offset(emblemW / 2, emblemH * 0.6),
                            child: child,
                          ),
                        ),
                        child: Image.asset(
                          'assets/branding/emblem.png',
                          width: emblemW,
                          height: emblemH,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: math.min(0.035 * screen.height, 32)),
                // --- wordmark: "Repair" purple + "AI" amber ---
                AnimatedBuilder(
                  animation: _word,
                  builder: (context, child) => Opacity(
                    opacity: _word.value,
                    child: Transform.translate(
                      offset: Offset(0, 6 * (1 - _word.value)),
                      child: child,
                    ),
                  ),
                  child: Text.rich(
                    TextSpan(
                      text: 'Repair',
                      children: [
                        TextSpan(
                          text: 'AI',
                          style: RepairText.wordmark(wordSize)
                              .copyWith(color: RepairColors.amber),
                        ),
                      ],
                    ),
                    style: RepairText.wordmark(wordSize),
                  ),
                ),
                SizedBox(height: 14),
                // --- tagline ---
                AnimatedBuilder(
                  animation: _tagline,
                  builder: (context, child) =>
                      Opacity(opacity: _tagline.value, child: child),
                  child: Text(
                    'Heal · Support · Hope',
                    style: RepairText.tagline(taglineSize),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
