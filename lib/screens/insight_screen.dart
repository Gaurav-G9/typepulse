import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';

import '../data/ar_api.dart';
import '../data/store.dart';
import '../models/typing_insight.dart';
import '../theme/app_colors.dart';
import '../widgets/ios_card.dart';
import '../widgets/store_rebuild.dart';

/// AR Typing member-area "Typing Progress Insight" for a chosen interval.
class InsightScreen extends StatefulWidget {
  final AppStore store;
  const InsightScreen({super.key, required this.store});

  @override
  State<InsightScreen> createState() => _InsightScreenState();
}

class _InsightScreenState extends State<InsightScreen>
    with RebuildOn<InsightScreen> {
  static const intervals = [1, 2, 7, 15, 30];

  @override
  Listenable get rebuildSource => widget.store;

  int days = 7;
  bool loading = false;
  String? error;
  TypingInsight? insight;
  bool empty = false;
  int _request = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool force = false}) async {
    if (widget.store.needsLogin) return;
    final req = ++_request;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final result = await widget.store.loadInsight(days, force: force);
      if (!mounted || req != _request) return;
      setState(() {
        insight = result;
        empty = result == null;
      });
    } on ArApiException catch (e) {
      if (!mounted || req != _request) return;
      setState(() => error = e.message);
    } catch (_) {
      if (!mounted || req != _request) return;
      setState(() => error = 'Could not load insights. Check your connection.');
    } finally {
      if (mounted && req == _request) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    return CupertinoPageScaffold(
      backgroundColor: AppColors.canvas,
      navigationBar: CupertinoNavigationBar(
        middle:
            Text('Typing Insight', style: TextStyle(color: AppColors.label)),
        backgroundColor: AppColors.navBar,
        border: null,
        trailing: !store.needsLogin
            ? CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: loading ? null : () => _load(force: true),
                child: Icon(CupertinoIcons.arrow_clockwise,
                    color: AppColors.label, size: 22),
              )
            : null,
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            ...[
              SizedBox(
                width: double.infinity,
                child: CupertinoSlidingSegmentedControl<int>(
                  groupValue: days,
                  children: {
                    for (final d in intervals)
                      d: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Text(d == 1 ? '1 day' : '$d days',
                            style: TextStyle(
                                fontSize: 13, color: AppColors.label)),
                      ),
                  },
                  onValueChanged: (v) {
                    if (v == null || v == days) return;
                    setState(() => days = v);
                    _load();
                  },
                ),
              ),
              const SizedBox(height: 16),
              ..._body(),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _body() {
    if (loading && insight == null) {
      return const [
        Padding(
          padding: EdgeInsets.only(top: 60),
          child: CupertinoActivityIndicator(radius: 14),
        ),
      ];
    }
    if (error != null) {
      return [_message(CupertinoIcons.exclamationmark_triangle, error!)];
    }
    if (empty || insight == null) {
      return [
        _message(
          CupertinoIcons.chart_bar,
          'No typing activity found for the last ${days == 1 ? 'day' : '$days days'}.\n'
          'Try a longer interval or type a passage on AR Typing.',
        ),
      ];
    }
    final i = insight!;
    return [
      if (loading)
        const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: CupertinoActivityIndicator(),
        ),
      IosCard(
        child: Column(children: [
          Row(children: [
            StatTile(label: 'Typed passages', value: '${i.passageCount}'),
            StatTile(
                label: 'Min. keys hit',
                value: '${i.minAchievedCount}',
                accent: AppColors.orange),
          ]),
          const SizedBox(height: 14),
          Row(children: [
            StatTile(
                label: 'Avg gross',
                value: i.avgGross.toStringAsFixed(1),
                suffix: 'wpm',
                accent: AppColors.blue),
            StatTile(
                label: 'Avg net',
                value: i.avgNet.toStringAsFixed(1),
                suffix: 'wpm',
                accent: AppColors.green),
          ]),
        ]),
      ),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: _best('Best gross', i.bestGross, 'Net')),
        const SizedBox(width: 10),
        Expanded(child: _best('Best net', i.bestNet, 'Gross')),
      ]),
      if (i.dailyBestGross.isNotEmpty ||
          i.dailyBestNet.isNotEmpty ||
          i.dailyMinAchieved.isNotEmpty) ...[
        _section('Daily progress'),
        if (i.dailyBestGross.isNotEmpty)
          _bars('Daily best gross speed', i.dailyBestGross, AppColors.teal),
        if (i.dailyBestNet.isNotEmpty)
          _bars('Daily best net speed', i.dailyBestNet, AppColors.green),
        if (i.dailyMinAchieved.isNotEmpty)
          _bars('Daily min-keystroke achievements', i.dailyMinAchieved,
              AppColors.orange),
      ],
      if (i.exams.isNotEmpty) ...[
        _section('Exams attended'),
        ...i.exams.map((e) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: IosCard(
                padding: const EdgeInsets.all(12),
                child: Row(children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(e.title,
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: AppColors.label)),
                        const SizedBox(height: 2),
                        Text(
                          [
                            if (e.targetWpm != null)
                              'Target ${e.targetWpm!.toStringAsFixed(0)} wpm',
                            if (e.duration.isNotEmpty) e.duration,
                          ].join(' · '),
                          style: TextStyle(
                              fontSize: 12, color: AppColors.secondaryLabel),
                        ),
                      ],
                    ),
                  ),
                  if (e.date != null)
                    Text(DateFormat('d MMM').format(e.date!),
                        style: TextStyle(
                            fontSize: 12, color: AppColors.secondaryLabel)),
                ]),
              ),
            )),
      ],
      _section('Words to practise'),
      _words('Misspelled words', i.misspelled, AppColors.orange),
      const SizedBox(height: 8),
      _words('Most added words / chars', i.added, AppColors.green),
      const SizedBox(height: 8),
      _words('Most deleted words / chars', i.deleted, AppColors.red),
    ];
  }

  Widget _message(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 48),
      child: Column(children: [
        Icon(icon, size: 40, color: AppColors.tertiaryLabel),
        const SizedBox(height: 12),
        Text(text,
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.secondaryLabel, height: 1.4)),
      ]),
    );
  }

  Widget _section(String title) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
        child: Text(title,
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.label)),
      );

  Widget _best(String title, BestSpeed? b, String otherLabel) {
    return IosCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title.toUpperCase(),
              style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 0.6,
                  fontWeight: FontWeight.w600,
                  color: AppColors.secondaryLabel)),
          const SizedBox(height: 6),
          Text(b == null ? '—' : '${b.speed.toStringAsFixed(1)} wpm',
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.label)),
          if (b != null && b.other > 0)
            Text('$otherLabel ${b.other.toStringAsFixed(1)} wpm',
                style:
                    TextStyle(fontSize: 12, color: AppColors.secondaryLabel)),
        ],
      ),
    );
  }

  Widget _bars(String title, List<double> values, Color color) {
    final maxV = values.fold<double>(0, max);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: IosCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.label)),
            const SizedBox(height: 10),
            SizedBox(
              height: 96,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (var k = 0; k < values.length; k++)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            if (values.length <= 15)
                              Text(values[k].toStringAsFixed(0),
                                  style: TextStyle(
                                      fontSize: 9,
                                      color: AppColors.secondaryLabel)),
                            const SizedBox(height: 2),
                            Container(
                              height:
                                  maxV <= 0 ? 3 : max(3, 70 * values[k] / maxV),
                              decoration: BoxDecoration(
                                color: color,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _words(String title, List<WordStat> words, Color color) {
    return IosCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w700, color: color)),
          const SizedBox(height: 8),
          if (words.isEmpty)
            Text('None in this interval',
                style: TextStyle(fontSize: 12, color: AppColors.secondaryLabel))
          else
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final w in words.take(30))
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      w.correct != null
                          ? '${w.word} → ${w.correct} ×${w.count}'
                          : '${w.word} ×${w.count}',
                      style: TextStyle(fontSize: 12, color: AppColors.label),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
