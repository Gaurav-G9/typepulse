import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';

import '../models/ar_result.dart';
import '../theme/app_colors.dart';

/// Gross and net WPM of real Typing History results, one point per result
/// (oldest → newest). Missing values are skipped — never plotted as 0 — and
/// days without tests simply don't appear.
class ResultsChart extends StatelessWidget {
  final List<ArResult> results;
  final double height;
  const ResultsChart({super.key, required this.results, this.height = 190});

  static const grossColor = AppColors.blue;
  static const netColor = AppColors.green;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _ResultsPainter(
          results: results,
          gridColor: AppColors.separator,
          labelColor: AppColors.secondaryLabel,
          holeColor: AppColors.groupedBackground,
        ),
      ),
    );
  }
}

class _ResultsPainter extends CustomPainter {
  final List<ArResult> results;
  final Color gridColor;
  final Color labelColor;
  final Color holeColor;

  _ResultsPainter({
    required this.results,
    required this.gridColor,
    required this.labelColor,
    required this.holeColor,
  });

  TextPainter _text(String s, double size) => TextPainter(
        text: TextSpan(
            text: s, style: TextStyle(fontSize: size, color: labelColor)),
        textDirection: ui.TextDirection.ltr,
      )..layout();

  @override
  void paint(Canvas canvas, Size size) {
    const padL = 34.0, padR = 12.0, padT = 12.0, padB = 24.0;
    final chart =
        Rect.fromLTRB(padL, padT, size.width - padR, size.height - padB);

    final values = <double>[
      for (final r in results) ...[
        if ((r.grossWpm ?? 0) > 0) r.grossWpm!,
        if ((r.netWpm ?? 0) > 0) r.netWpm!,
      ]
    ];
    if (values.isEmpty) {
      final tp = _text('No results with speed data yet', 13);
      tp.paint(canvas, chart.center - Offset(tp.width / 2, tp.height / 2));
      return;
    }
    final top = max(10.0, (values.reduce(max) / 10).ceil() * 10.0);

    final grid = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (var i = 0; i <= 2; i++) {
      final y = chart.top + chart.height * i / 2;
      canvas.drawLine(Offset(chart.left, y), Offset(chart.right, y), grid);
      final tp = _text((top * (1 - i / 2)).round().toString(), 10);
      tp.paint(canvas, Offset(padL - tp.width - 6, y - tp.height / 2));
    }

    final n = results.length;
    double x(int i) =>
        n == 1 ? chart.center.dx : chart.left + chart.width * i / (n - 1);
    double y(double v) => chart.bottom - v / top * chart.height;

    void series(double? Function(ArResult) pick, Color color) {
      final path = Path();
      var started = false;
      final pts = <Offset>[];
      for (var i = 0; i < n; i++) {
        final v = pick(results[i]);
        if (v == null || v <= 0) continue; // no data → skip, never draw 0
        final p = Offset(x(i), y(v));
        pts.add(p);
        started ? path.lineTo(p.dx, p.dy) : path.moveTo(p.dx, p.dy);
        started = true;
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2
          ..strokeJoin = StrokeJoin.round,
      );
      final dot = Paint()..color = color;
      final hole = Paint()..color = holeColor;
      for (final p in pts) {
        canvas.drawCircle(p, n > 20 ? 2.5 : 4, dot);
        if (n <= 20) canvas.drawCircle(p, 1.8, hole);
      }
    }

    series((r) => r.grossWpm, ResultsChart.grossColor);
    series((r) => r.netWpm, ResultsChart.netColor);

    // Dates of the first and last result shown.
    final fmt = DateFormat('d MMM');
    final first = _text(fmt.format(results.first.date), 10);
    first.paint(canvas, Offset(chart.left, chart.bottom + 7));
    if (n > 1) {
      final last = _text(fmt.format(results.last.date), 10);
      last.paint(canvas, Offset(chart.right - last.width, chart.bottom + 7));
    }
  }

  @override
  bool shouldRepaint(covariant _ResultsPainter old) =>
      old.results != results ||
      old.gridColor != gridColor ||
      old.labelColor != labelColor;
}

/// Segmented "Last 7 / 15 / 30 tests" selector.
class RangeChips extends StatelessWidget {
  final int selected;
  final List<int> options;
  final ValueChanged<int> onChanged;
  const RangeChips({
    super.key,
    required this.selected,
    required this.onChanged,
    this.options = const [7, 15, 30],
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: AppColors.fill,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final o in options)
            GestureDetector(
              onTap: () => onChanged(o),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: o == selected ? AppColors.card : null,
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Text(
                  '$o',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight:
                        o == selected ? FontWeight.w700 : FontWeight.w500,
                    color: AppColors.label,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
