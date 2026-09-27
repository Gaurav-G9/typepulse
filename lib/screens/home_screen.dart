import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';
import '../data/store.dart';
import '../theme/app_colors.dart';
import '../widgets/activity_rings.dart';
import 'history_screen.dart';
import 'practice_screen.dart';
import 'session_detail_screen.dart';

class HomeScreen extends StatelessWidget {
  final AppStore store;
  final VoidCallback onOpenLive;
  const HomeScreen({super.key, required this.store, required this.onOpenLive});

  @override
  Widget build(BuildContext context) {
    final testsP = (store.today.length / 20).clamp(0.0, 1.0);
    final speedP = store.avgNet == 0 ? 0.0 : store.avgNet / store.profile.targetWpm;
    return ColoredBox(
      color: AppColors.canvas,
      child: CustomScrollView(slivers: [
        CupertinoSliverNavigationBar(
          largeTitle: const Text('Summary'),
          border: null,
          backgroundColor: AppColors.canvas,
          trailing: CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () => Navigator.of(context).push(CupertinoPageRoute(builder: (_) => PracticeScreen(store: store, seconds: 300))),
            child: const Icon(CupertinoIcons.add_circled_solid),
          ),
        ),
        SliverToBoxAdapter(child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
          child: Row(children: [
            ActivityRings(tests: testsP, speed: speedP, accuracy: store.avgAccuracy / 100),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Tests  ${store.today.length}/20', style: const TextStyle(fontWeight: FontWeight.w700)),
              Text('Speed  ${store.avgNet.toStringAsFixed(0)}/${store.profile.targetWpm}', style: const TextStyle(fontWeight: FontWeight.w700)),
              Text('Accuracy  ${store.avgAccuracy.toStringAsFixed(0)}/100', style: const TextStyle(fontWeight: FontWeight.w700)),
            ])),
          ]),
        )),
        SliverToBoxAdapter(child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Column(children: [
            HeroMetric(value: '${store.sessions.length}', unit: '', label: 'Total Tests Attempted', dot: AppColors.dotTests),
            HeroMetric(value: store.avgGross == 0 ? '—' : store.avgGross.toStringAsFixed(0), unit: 'wpm', label: 'Avg. Gross Speed', dot: AppColors.dotGross),
            HeroMetric(value: store.avgNet == 0 ? '—' : store.avgNet.toStringAsFixed(0), unit: 'wpm', label: 'Avg. Net Speed', dot: AppColors.dotNet),
            HeroMetric(value: store.avgAccuracy == 0 ? '—' : store.avgAccuracy.toStringAsFixed(0), unit: '%', label: 'Avg. Accuracy', dot: AppColors.dotAcc),
          ]),
        )),
        SliverToBoxAdapter(child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Row(children: [
            Expanded(child: _btn('Practice', AppColors.ringMove, () {
              Navigator.of(context).push(CupertinoPageRoute(builder: (_) => PracticeScreen(store: store, seconds: 300)));
            })),
            const SizedBox(width: 10),
            Expanded(child: _btn('Live', const Color(0xFF32ADE6), onOpenLive)),
          ]),
        )),
        SliverToBoxAdapter(child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 12, 8),
          child: Row(children: [
            const Text('Workouts', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
            const Spacer(),
            CupertinoButton(padding: EdgeInsets.zero, onPressed: () => Navigator.of(context).push(CupertinoPageRoute(builder: (_) => HistoryScreen(store: store))), child: const Text('Show More')),
          ]),
        )),
        SliverList(delegate: SliverChildBuilderDelegate((context, i) {
          final s = store.sessions[i];
          return GestureDetector(
            onTap: () => Navigator.of(context).push(CupertinoPageRoute(builder: (_) => SessionDetailScreen(store: store, session: s))),
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: AppColors.groupedBackground, borderRadius: BorderRadius.circular(16)),
              child: Row(children: [
                const Icon(CupertinoIcons.graph_circle_fill, color: AppColors.ringMove),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(s.examTitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text('${DateFormat('d MMM').format(s.startedAt)}  ·  ${mmss(s.timeTakenSec)}', style: const TextStyle(color: AppColors.secondaryLabel, fontSize: 13)),
                ])),
                Text(s.netWpm.toStringAsFixed(0), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
              ]),
            ),
          );
        }, childCount: store.sessions.length.clamp(0, 8))),
      ]),
    );
  }

  Widget _btn(String title, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(18)),
        alignment: Alignment.center,
        child: Text(title, style: const TextStyle(color: CupertinoColors.white, fontWeight: FontWeight.w700)),
      ),
    );
  }
}
