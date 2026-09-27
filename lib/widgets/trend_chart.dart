import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/cupertino.dart';
import '../theme/app_colors.dart';

/// Minimal net-WPM (and optional accuracy) trend for 7 / 15 / 30 days.
class TrendChart extends StatelessWidget {
  final List<double> netWpm;
  final List<double>? accuracy;
  final int days;
  final double height;

  const TrendChart({
    super.key,
    required this.netWpm,
    this.accuracy,
    required this.days,
    this.height = 160,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _TrendPainter(
          net: netWpm,
          accuracy: accuracy,
          days: days,
          lineColor: AppColors.ringMove,
          accColor: AppColors.ringStand,
          gridColor: AppColors.separator,
          labelColor: AppColors.secondaryLabel,
          fillColor: AppColors.ringMove.withOpacity(AppColors.dark ? 0.18 : 0.12),
        ),
      ),
    );
  }
}

class _TrendPainter extends CustomPainter {
  final List<double> net;
  final List<double>? accuracy;
  final int days;
  final Color lineColor;
  final Color accColor;
  final Color gridColor;
  final Color labelColor;
  final Color fillColor;

  _TrendPainter({
    required this.net,
    required this.accuracy,
    required this.days,
    required this.lineColor,
    required this.accColor,
    required this.gridColor,
    required this.labelColor,
    required this.fillColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final padL = 36.0;
    final padR = 12.0;
    final padT = 16.0;
    final padB = 28.0;
    final chart = Rect.fromLTRB(padL, padT, size.width - padR, size.height - padB);

    final values = net.isEmpty ? List.filled(days, 0.0) : net;
    final maxV = max(40.0, values.fold<double>(0, max) * 1.15);
    final minV = 0.0;

    // Grid
    final gridPaint = Paint()
      ..color = gridColor.withOpacity(0.55)
      ..strokeWidth = 1;
    for (var i = 0; i <= 3; i++) {
      final y = chart.top + chart.height * i / 3;
      canvas.drawLine(Offset(chart.left, y), Offset(chart.right, y), gridPaint);
      final label = (maxV * (1 - i / 3)).round().toString();
      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(fontSize: 10, color: labelColor, fontWeight: FontWeight.w500),
        ),
        textDirection: ui.TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(padL - tp.width - 6, y - tp.height / 2));
    }

    if (values.every((v) => v <= 0)) {
      final tp = TextPainter(
        text: TextSpan(
          text: 'No workouts in this range',
          style: TextStyle(fontSize: 13, color: labelColor),
        ),
        textDirection: ui.TextDirection.ltr,
      )..layout(maxWidth: chart.width);
      tp.paint(
        canvas,
        Offset(chart.left + (chart.width - tp.width) / 2, chart.center.dy - tp.height / 2),
      );
      _xLabels(canvas, chart);
      return;
    }

    Offset pt(int i, double v) {
      final n = max(1, values.length - 1);
      final x = chart.left + chart.width * (i / n);
      final y = chart.bottom - ((v - minV) / (maxV - minV)) * chart.height;
      return Offset(x, y);
    }

    final path = Path();
    final fill = Path();
    for (var i = 0; i < values.length; i++) {
      final p = pt(i, values[i]);
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
        fill.moveTo(p.dx, chart.bottom);
        fill.lineTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
        fill.lineTo(p.dx, p.dy);
      }
    }
    fill.lineTo(pt(values.length - 1, values.last).dx, chart.bottom);
    fill.close();

    canvas.drawPath(fill, Paint()..color = fillColor);
    canvas.drawPath(
      path,
      Paint()
        ..color = lineColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // Dots only on active days
    final dot = Paint()..color = lineColor;
    final hole = Paint()..color = AppColors.card;
    for (var i = 0; i < values.length; i++) {
      if (values[i] <= 0) continue;
      final p = pt(i, values[i]);
      canvas.drawCircle(p, 4.5, dot);
      canvas.drawCircle(p, 2.2, hole);
    }

    // Optional accuracy as thin dashed-feel secondary line (scaled 0-100 → chart)
    if (accuracy != null && accuracy!.length == values.length) {
      final accPath = Path();
      var started = false;
      for (var i = 0; i < accuracy!.length; i++) {
        final a = accuracy![i];
        if (a <= 0) continue;
        final mapped = minV + (a / 100.0) * (maxV - minV);
        final p = pt(i, mapped);
        if (!started) {
          accPath.moveTo(p.dx, p.dy);
          started = true;
        } else {
          accPath.lineTo(p.dx, p.dy);
        }
      }
      canvas.drawPath(
        accPath,
        Paint()
          ..color = accColor.withOpacity(0.85)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..strokeCap = StrokeCap.round,
      );
    }

    _xLabels(canvas, chart);
  }

  void _xLabels(Canvas canvas, Rect chart) {
    final labels = days <= 7
        ? ['−6', '−5', '−4', '−3', '−2', '−1', 'Today']
        : days <= 15
            ? ['−14', '−10', '−7', '−3', 'Today']
            : ['−30', '−20', '−10', 'Today'];
    final positions = days <= 7
        ? [0, 1, 2, 3, 4, 5, 6]
        : days <= 15
            ? [0, 4, 7, 11, 14]
            : [0, 10, 20, 29];
    for (var i = 0; i < labels.length && i < positions.length; i++) {
      final idx = positions[i].clamp(0, days - 1);
      final n = max(1, days - 1);
      final x = chart.left + chart.width * (idx / n);
      final tp = TextPainter(
        text: TextSpan(
          text: labels[i],
          style: TextStyle(fontSize: 10, color: labelColor),
        ),
        textDirection: ui.TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x - tp.width / 2, chart.bottom + 8));
    }
  }

  @override
  bool shouldRepaint(covariant _TrendPainter old) =>
      old.net != net || old.accuracy != accuracy || old.days != days || old.lineColor != lineColor;
}

/// Compact segmented control for 7 / 15 / 30.
class RangeChips extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onChanged;
  const RangeChips({super.key, required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    Widget chip(int days, String label) {
      final on = selected == days;
      return GestureDetector(
        onTap: () => onChanged(days),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: on ? AppColors.label : AppColors.fill,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: on ? AppColors.canvas : AppColors.secondaryLabel,
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        chip(7, '7D'),
        const SizedBox(width: 8),
        chip(15, '15D'),
        const SizedBox(width: 8),
        chip(30, '30D'),
      ],
    );
  }
}
