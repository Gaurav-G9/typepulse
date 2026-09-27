import 'package:flutter/cupertino.dart';
import '../data/store.dart';
import '../theme/app_colors.dart';

class LeaderboardScreen extends StatelessWidget {
  final AppStore store;
  const LeaderboardScreen({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    final board = store.weeklyBoard();
    final youIndex = board.indexWhere((e) => e.isYou);
    return CustomScrollView(slivers: [
      const CupertinoSliverNavigationBar(largeTitle: Text('Ranks'), border: null, backgroundColor: AppColors.background),
      SliverPadding(
        padding: const EdgeInsets.all(16),
        sliver: SliverList(delegate: SliverChildListDelegate([
          if (youIndex >= 0)
            Container(
              padding: const EdgeInsets.all(14),
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(gradient: const LinearGradient(colors: [AppColors.gradientStart, AppColors.gradientEnd]), borderRadius: BorderRadius.circular(16)),
              child: Text('#${youIndex + 1}  Your weekly place   ${board[youIndex].bestNetWpm.toStringAsFixed(0)}',
                  style: const TextStyle(color: CupertinoColors.white, fontWeight: FontWeight.w800, fontSize: 18)),
            ),
          ...List.generate(board.length, (i) {
            final e = board[i];
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(children: [
                SizedBox(width: 28, child: Text('${i + 1}', style: const TextStyle(fontWeight: FontWeight.w700))),
                Expanded(child: Text(e.isYou ? '${e.name} (you)' : e.name)),
                Text(e.bestNetWpm.toStringAsFixed(1), style: const TextStyle(fontWeight: FontWeight.w800)),
              ]),
            );
          }),
        ])),
      ),
    ]);
  }
}
