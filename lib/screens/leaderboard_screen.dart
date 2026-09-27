import 'package:flutter/cupertino.dart';
import '../data/store.dart';
import '../theme/app_colors.dart';
import '../widgets/ios_card.dart';

class LeaderboardScreen extends StatelessWidget {
  final AppStore store;
  const LeaderboardScreen({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    final board = store.weeklyBoard();
    final youIndex = board.indexWhere((e) => e.isYou);
    return ColoredBox(
      color: AppColors.canvas,
      child: CustomScrollView(slivers: [
        CupertinoSliverNavigationBar(
          largeTitle: const Text('Ranks'),
          border: null,
          backgroundColor: AppColors.canvas,
          trailing: ThemeToggleButton(
            isDark: store.darkMode,
            onToggle: () => store.toggleDarkMode(),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              if (youIndex >= 0)
                Container(
                  padding: const EdgeInsets.all(14),
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [AppColors.gradientStart, AppColors.gradientEnd]),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '#${youIndex + 1}  Your weekly place   ${board[youIndex].bestNetWpm.toStringAsFixed(0)}',
                    style: const TextStyle(color: CupertinoColors.white, fontWeight: FontWeight.w800, fontSize: 18),
                  ),
                ),
              ...List.generate(board.length, (i) {
                final e = board[i];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(children: [
                    SizedBox(
                      width: 28,
                      child: Text('${i + 1}', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.label)),
                    ),
                    Expanded(
                      child: Text(
                        e.isYou ? '${e.name} (you)' : e.name,
                        style: TextStyle(color: AppColors.label, fontWeight: e.isYou ? FontWeight.w700 : FontWeight.w500),
                      ),
                    ),
                    Text(e.bestNetWpm.toStringAsFixed(1), style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.label)),
                  ]),
                );
              }),
            ]),
          ),
        ),
      ]),
    );
  }
}
