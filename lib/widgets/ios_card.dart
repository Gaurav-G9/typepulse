import 'package:flutter/cupertino.dart';
import '../theme/app_colors.dart';

class IosCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  const IosCard({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.onTap});

  @override
  Widget build(BuildContext context) {
    final card = Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(16)),
      child: child,
    );
    if (onTap == null) return card;
    return GestureDetector(onTap: onTap, behavior: HitTestBehavior.opaque, child: card);
  }
}

class StatTile extends StatelessWidget {
  final String label;
  final String value;
  final String? suffix;
  final Color accent;
  const StatTile({super.key, required this.label, required this.value, this.suffix, this.accent = AppColors.indigo});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: const TextStyle(fontSize: 11, letterSpacing: 0.6, color: AppColors.secondaryLabel, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(value, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: accent, letterSpacing: -0.6)),
              if (suffix != null) ...[
                const SizedBox(width: 4),
                Padding(padding: const EdgeInsets.only(bottom: 3), child: Text(suffix!, style: const TextStyle(fontSize: 13, color: AppColors.secondaryLabel))),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
