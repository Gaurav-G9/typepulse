import 'dart:math';

import 'package:flutter/cupertino.dart';
import '../theme/app_colors.dart';

class ActivityRings extends StatelessWidget {
  final double tests;
  final double speed;
  final double accuracy;
  final double size;

  const ActivityRings({
    super.key,
    required this.tests,
    required this.speed,
    required this.accuracy,
    this.size = 148,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RingsPainter(
          tests: tests.clamp(0, 1.15),
          speed: speed.clamp(0, 1.15),
          accuracy: accuracy.clamp(0, 1.15),
        ),
      ),
    );
  }
}

class _RingsPainter extends CustomPainter {
  final double tests, speed, accuracy;
  _RingsPainter({required this.tests, required this.speed, required this.accuracy});

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final stroke = size.width * 0.105;
    final gap = stroke * 0.28;
    _ring(canvas, c, size.width / 2 - stroke / 2, stroke, tests, AppColors.ringMove, const Color(0x22FA4D67));
    _ring(canvas, c, size.width / 2 - stroke * 1.5 - gap, stroke, speed, AppColors.ringExerciseDark, const Color(0x229BFF37));
    _ring(canvas, c, size.width / 2 - stroke * 2.5 - gap * 2, stroke, accuracy, const Color(0xFF32ADE6), const Color(0x225CE5FF));
  }

  void _ring(Canvas canvas, Offset c, double r, double stroke, double p, Color color, Color track) {
    final rect = Rect.fromCircle(center: c, radius: r);
    canvas.drawArc(rect, 0, 3.14159 * 2, false, Paint()..color = track..style = PaintingStyle.stroke..strokeWidth = stroke..strokeCap = StrokeCap.round);
    canvas.drawArc(rect, -1.5708, 3.14159 * 2 * p.clamp(0, 1), false, Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = stroke..strokeCap = StrokeCap.round);
  }

  @override
  bool shouldRepaint(covariant _RingsPainter old) => old.tests != tests || old.speed != speed || old.accuracy != accuracy;
}

class HeroMetric extends StatelessWidget {
  final String value;
  final String unit;
  final String label;
  final Color dot;
  const HeroMetric({super.key, required this.value, required this.unit, required this.label, required this.dot});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Column(
        children: [
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(children: [
              TextSpan(text: value, style: const TextStyle(fontFamily: 'Georgia', fontSize: 56, height: 1, color: AppColors.label, letterSpacing: -1.2)),
              TextSpan(text: unit.isEmpty ? '' : ' $unit', style: const TextStyle(fontFamily: 'Georgia', fontSize: 34, color: AppColors.label)),
            ]),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 15, color: AppColors.secondaryLabel)),
          const SizedBox(height: 18),
          Container(width: 8, height: 8, decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
        ],
      ),
    );
  }
}

class DashRow extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  const DashRow({super.key, required this.title, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: Color(0x14000000))),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 13, color: AppColors.secondaryLabel)),
                const SizedBox(height: 4),
                Text(value, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700, letterSpacing: -0.6)),
              ],
            ),
          ),
          Icon(icon, color: AppColors.label, size: 22),
        ],
      ),
    );
  }
}

String mmss(int sec) {
  final m = (sec ~/ 60).toString().padLeft(2, '0');
  final s = (sec % 60).toString().padLeft(2, '0');
  return '$m:$s';
}
