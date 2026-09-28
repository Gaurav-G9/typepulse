import 'package:flutter/cupertino.dart';
import '../theme/app_colors.dart';

class IosCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  const IosCard(
      {super.key,
      required this.child,
      this.padding = const EdgeInsets.all(16),
      this.onTap});

  @override
  Widget build(BuildContext context) {
    final card = Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
          color: AppColors.card, borderRadius: BorderRadius.circular(16)),
      child: child,
    );
    if (onTap == null) return card;
    return GestureDetector(
        onTap: onTap, behavior: HitTestBehavior.opaque, child: card);
  }
}

class StatTile extends StatelessWidget {
  final String label;
  final String value;
  final String? suffix;
  final Color accent;
  const StatTile(
      {super.key,
      required this.label,
      required this.value,
      this.suffix,
      this.accent = AppColors.indigo});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(),
              style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 0.6,
                  color: AppColors.secondaryLabel,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(value,
                  style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: accent,
                      letterSpacing: -0.6)),
              if (suffix != null) ...[
                const SizedBox(width: 4),
                Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Text(suffix!,
                        style: TextStyle(
                            fontSize: 13, color: AppColors.secondaryLabel))),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// Theme toggle for nav bars.
class ThemeToggleButton extends StatelessWidget {
  final bool isDark;
  final VoidCallback onToggle;
  const ThemeToggleButton(
      {super.key, required this.isDark, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onToggle,
      child: Icon(
        isDark ? CupertinoIcons.sun_max_fill : CupertinoIcons.moon_fill,
        color: AppColors.label,
        size: 22,
      ),
    );
  }
}
