import 'dart:math';
import 'package:flutter/cupertino.dart';
import '../theme/app_colors.dart';

/// Simple 7-day net WPM bars — no chart packages.
class NetSparkline extends StatelessWidget {
  final List<double> values;
  final double height;
  const NetSparkline({super.key, required this.values, this.height = 72});

  @override
  Widget build(BuildContext context) {
    final maxV = values.isEmpty ? 1.0 : max(1.0, values.reduce(max));
    final days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    // Align labels to last 7 calendar days ending today — cosmetic only.
    final today = DateTime.now().weekday; // 1=Mon
    final labels = List.generate(7, (i) {
      final d = (today - 6 + i);
      final idx = ((d - 1) % 7 + 7) % 7;
      return days[idx];
    });

    return SizedBox(
      height: height + 22,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(values.length, (i) {
          final v = values[i];
          final h = (v / maxV) * height;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (v > 0)
                    Text(
                      v.toStringAsFixed(0),
                      style: const TextStyle(fontSize: 9, color: AppColors.secondaryLabel),
                    ),
                  const SizedBox(height: 4),
                  Container(
                    height: max(4, h),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          AppColors.ringMove.withOpacity(0.85),
                          AppColors.orange,
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(labels[i], style: const TextStyle(fontSize: 11, color: AppColors.secondaryLabel)),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}
