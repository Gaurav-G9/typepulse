import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';

import '../data/store.dart';
import '../theme/app_colors.dart';
import '../widgets/activity_rings.dart';
import '../widgets/ios_card.dart';
import '../widgets/trend_chart.dart';
import 'account_switcher.dart';
import 'history_screen.dart';
import 'practice_screen.dart';
import 'session_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  final AppStore store;
  final VoidCallback onOpenLive;
  const HomeScreen({super.key, required this.store, required this.onOpenLive});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int rangeDays = 7;
  AppStore get store => widget.store;

  @override
  Widget build(BuildContext context) {
    final testsP = (store.today.length / 8).clamp(0.0, 1.0);
    final speedP =
        store.avgNet == 0 ? 0.0 : store.avgNet / store.profile.targetWpm;
    final netSeries = store.lastNNetWpm(rangeDays);
    final accSeries = store.lastNAccuracy(rangeDays);

    final totalTests = store.remoteTotalTests ?? store.sessions.length;
    final avgNet = store.remoteAvgNet ?? store.avgNet;
    final avgGross = store.remoteAvgGross ?? store.avgGross;
    final avgAcc = store.remoteAvgAccuracy ?? store.avgAccuracy;

    return ColoredBox(
      color: AppColors.canvas,
      child: CustomScrollView(slivers: [
        CupertinoSliverNavigationBar(
          largeTitle: const Text('Summary'),
          border: null,
          backgroundColor: AppColors.canvas,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (store.accounts.length > 1)
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: () => showAccountSwitcher(context, store),
                  child: Icon(
                    CupertinoIcons.person_2,
                    color: AppColors.label,
                    size: 22,
                  ),
                ),
              ThemeToggleButton(
                isDark: store.darkMode,
                onToggle: () => store.toggleDarkMode(),
              ),
              CupertinoButton(
                padding: const EdgeInsets.only(left: 2),
                onPressed: store.refreshing || store.arSyncing
                    ? null
                    : () => store.manualRefresh(),
                child: store.refreshing || (store.arSyncing && store.arConnected)
                    ? const CupertinoActivityIndicator(radius: 10)
                    : Icon(
                        CupertinoIcons.arrow_clockwise,
                        color: AppColors.label,
                        size: 22,
                      ),
              ),
              CupertinoButton(
                padding: const EdgeInsets.only(left: 4),
                onPressed: () => Navigator.of(context).push(
                  CupertinoPageRoute(
                      builder: (_) => PracticeScreen(store: store)),
                ),
                child: Icon(CupertinoIcons.add_circled_solid,
                    color: AppColors.indigo),
              ),
            ],
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: Row(children: [
              ActivityRings(
                  tests: testsP,
                  speed: speedP,
                  accuracy: store.avgAccuracy / 100),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ringLegend('Move', '${store.today.length} tests',
                        AppColors.ringMove),
                    const SizedBox(height: 8),
                    _ringLegend(
                        'Exercise',
                        '${store.avgNet.toStringAsFixed(0)} net',
                        AppColors.ringExerciseDark),
                    const SizedBox(height: 8),
                    _ringLegend(
                        'Stand',
                        '${store.avgAccuracy.toStringAsFixed(0)}% acc',
                        const Color(0xFF32ADE6)),
                  ],
                ),
              ),
            ]),
          ),
        ),
        if (store.arConnected && store.arMemberStats != null)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.groupedBackground,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Icon(CupertinoIcons.chart_bar_alt_fill,
                          size: 16, color: AppColors.blue),
                      const SizedBox(width: 6),
                      Text(
                        'AR Member Stats',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.label,
                        ),
                      ),
                      const Spacer(),
                      if (store.activeAccount != null)
                        Text(
                          store.activeAccount!.displayName,
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.secondaryLabel,
                          ),
                        ),
                    ]),
                    const SizedBox(height: 12),
                    Row(children: [
                      _miniStat('$totalTests', 'Tests'),
                      _miniStat(
                          avgGross == 0
                              ? '—'
                              : avgGross.toStringAsFixed(0),
                          'Avg Gross'),
                      _miniStat(
                          avgNet == 0 ? '—' : avgNet.toStringAsFixed(0),
                          'Avg Net'),
                      _miniStat(
                          avgAcc == 0 ? '—' : '${avgAcc.toStringAsFixed(0)}%',
                          'Accuracy'),
                    ]),
                  ],
                ),
              ),
            ),
          ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
            child: Row(
              children: [
                Text('Trend',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.label)),
                const Spacer(),
                RangeChips(
                  selected: rangeDays,
                  onChanged: (d) => setState(() => rangeDays = d),
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
            child: Container(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
              decoration: BoxDecoration(
                color: AppColors.groupedBackground,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 6, 10, 0),
                    child: Row(children: [
                      _legendDot(AppColors.ringMove, 'Net WPM'),
                      const SizedBox(width: 14),
                      _legendDot(AppColors.ringStand, 'Accuracy'),
                      const Spacer(),
                      Text(
                        store.arConnected
                            ? (store.activeAccount?.email ?? 'AR synced')
                            : 'Local + sample',
                        style: TextStyle(
                            fontSize: 11, color: AppColors.secondaryLabel),
                      ),
                    ]),
                  ),
                  TrendChart(
                      netWpm: netSeries, accuracy: accSeries, days: rangeDays),
                ],
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
            child: Column(children: [
              HeroMetric(
                value: '${store.sessions.length}',
                unit: '',
                label: 'Total Tests',
                dot: AppColors.dotTests,
              ),
              HeroMetric(
                value: store.avgNet == 0
                    ? '—'
                    : store.avgNet.toStringAsFixed(0),
                unit: 'wpm',
                label: 'Avg. Net Speed',
                dot: AppColors.dotNet,
              ),
              HeroMetric(
                value: store.avgGross == 0
                    ? '—'
                    : store.avgGross.toStringAsFixed(0),
                unit: 'wpm',
                label: 'Avg. Gross Speed',
                dot: AppColors.dotGross,
              ),
              HeroMetric(
                value: store.avgAccuracy == 0
                    ? '—'
                    : store.avgAccuracy.toStringAsFixed(0),
                unit: '%',
                label: 'Avg. Accuracy',
                dot: AppColors.dotAcc,
              ),
            ]),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Row(children: [
              _insightChip('${store.streak} day streak', AppColors.orange),
              const SizedBox(width: 8),
              _insightChip(
                  '${store.qualifiedCount} qualified', AppColors.green),
            ]),
          ),
        ),
        if (store.arError != null)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                store.arError!,
                style: TextStyle(fontSize: 12, color: AppColors.red),
              ),
            ),
          ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: Row(children: [
              Expanded(
                child: _btn('Practice', AppColors.ringMove, () {
                  Navigator.of(context).push(
                    CupertinoPageRoute(
                        builder: (_) => PracticeScreen(store: store)),
                  );
                }),
              ),
              const SizedBox(width: 10),
              Expanded(
                  child: _btn(
                      'Live', const Color(0xFF32ADE6), widget.onOpenLive)),
            ]),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 12, 8),
            child: Row(children: [
              Text('Workouts',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.label)),
              const Spacer(),
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () => Navigator.of(context).push(
                  CupertinoPageRoute(
                      builder: (_) => HistoryScreen(store: store)),
                ),
                child: const Text('Show More'),
              ),
            ]),
          ),
        ),
        if (store.sessions.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
              child: Column(
                children: [
                  Icon(CupertinoIcons.graph_circle,
                      size: 40, color: AppColors.tertiaryLabel),
                  const SizedBox(height: 10),
                  Text(
                    'No workouts yet',
                    style: TextStyle(
                        fontWeight: FontWeight.w700, color: AppColors.label),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Sign in on You → AR Typing, or start a Practice session.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 13, color: AppColors.secondaryLabel),
                  ),
                ],
              ),
            ),
          )
        else
          SliverList(
            delegate: SliverChildBuilderDelegate((context, i) {
              final s = store.sessions[i];
              final isAr = s.source == 'ar' || s.id.startsWith('ar-');
              return GestureDetector(
                onTap: () => Navigator.of(context).push(
                  CupertinoPageRoute(
                      builder: (_) =>
                          SessionDetailScreen(store: store, session: s)),
                ),
                child: Container(
                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.groupedBackground,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(children: [
                    Icon(
                      isAr
                          ? CupertinoIcons.cloud_fill
                          : CupertinoIcons.graph_circle_fill,
                      color: isAr ? AppColors.blue : AppColors.ringMove,
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.passageTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: AppColors.label),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${DateFormat('d MMM').format(s.startedAt)}  ·  ${mmss(s.timeTakenSec)}${isAr ? '  ·  AR' : ''}',
                            style: TextStyle(
                                color: AppColors.secondaryLabel, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      s.netWpm.toStringAsFixed(0),
                      style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 20,
                          color: AppColors.label),
                    ),
                  ]),
                ),
              );
            }, childCount: store.sessions.length.clamp(0, 8)),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 28)),
      ]),
    );
  }

  Widget _miniStat(String value, String label) {
    return Expanded(
      child: Column(
        children: [
          Text(value,
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.label)),
          const SizedBox(height: 2),
          Text(label,
              style:
                  TextStyle(fontSize: 10, color: AppColors.secondaryLabel)),
        ],
      ),
    );
  }

  Widget _ringLegend(String title, String value, Color c) {
    return Row(children: [
      Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
      const SizedBox(width: 8),
      Text('$title  ',
          style: TextStyle(fontSize: 13, color: AppColors.secondaryLabel)),
      Text(value,
          style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.label)),
    ]);
  }

  Widget _legendDot(Color c, String label) {
    return Row(children: [
      Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
      const SizedBox(width: 5),
      Text(label,
          style: TextStyle(fontSize: 11, color: AppColors.secondaryLabel)),
    ]);
  }

  Widget _insightChip(String text, Color c) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: c.withOpacity(0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(text,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c)),
    );
  }

  Widget _btn(String title, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration:
            BoxDecoration(color: color, borderRadius: BorderRadius.circular(16)),
        alignment: Alignment.center,
        child: Text(title,
            style: const TextStyle(
                color: CupertinoColors.white, fontWeight: FontWeight.w700)),
      ),
    );
  }
}
