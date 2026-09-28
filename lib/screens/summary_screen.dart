import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';

import '../data/store.dart';
import '../theme/app_colors.dart';
import '../widgets/ios_card.dart';
import '../widgets/trend_chart.dart';
import 'account_switcher.dart';
import 'result_tile.dart';

/// Summary: the member-area stat cards, a graph of your latest results and
/// the most recent Typing History — all from AR Typing.
class SummaryScreen extends StatefulWidget {
  final AppStore store;
  final VoidCallback onOpenHistory;
  const SummaryScreen(
      {super.key, required this.store, required this.onOpenHistory});

  @override
  State<SummaryScreen> createState() => _SummaryScreenState();
}

class _SummaryScreenState extends State<SummaryScreen> {
  int lastN = 15;
  AppStore get store => widget.store;

  @override
  Widget build(BuildContext context) {
    final chart = store.lastResultsForChart(lastN);
    final recent = store.results.take(5).toList();
    return ColoredBox(
      color: AppColors.canvas,
      child: CustomScrollView(slivers: [
        CupertinoSliverNavigationBar(
          largeTitle: const Text('Summary'),
          border: null,
          backgroundColor: AppColors.canvas,
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            if (store.accounts.length > 1)
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () => showAccountSwitcher(context, store),
                child: Icon(CupertinoIcons.person_2,
                    color: AppColors.label, size: 22),
              ),
            ThemeToggleButton(
                isDark: store.darkMode, onToggle: store.toggleDarkMode),
            CupertinoButton(
              padding: const EdgeInsets.only(left: 4),
              onPressed: store.syncing ? null : store.manualRefresh,
              child: store.syncing
                  ? const CupertinoActivityIndicator(radius: 10)
                  : Icon(CupertinoIcons.arrow_clockwise,
                      color: AppColors.label, size: 22),
            ),
          ]),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              if (store.displayName != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text('Hi, ${store.displayName}',
                      style: TextStyle(
                          fontSize: 15, color: AppColors.secondaryLabel)),
                ),
              if (store.error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(store.error!,
                      style:
                          const TextStyle(fontSize: 13, color: AppColors.red)),
                ),
              _statsGrid(),
              const SizedBox(height: 20),
              Row(children: [
                Expanded(
                  child: Text('Last $lastN results',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AppColors.label)),
                ),
                RangeChips(
                    selected: lastN,
                    onChanged: (n) => setState(() => lastN = n)),
              ]),
              const SizedBox(height: 8),
              IosCard(
                padding: const EdgeInsets.fromLTRB(8, 14, 8, 8),
                child: Column(children: [
                  Row(children: [
                    const SizedBox(width: 8),
                    _legend(ResultsChart.grossColor, 'Gross WPM'),
                    const SizedBox(width: 14),
                    _legend(ResultsChart.netColor, 'Net WPM'),
                  ]),
                  const SizedBox(height: 8),
                  ResultsChart(results: chart),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  chart.isEmpty
                      ? ''
                      : 'One point per test, in the order you took them. '
                          'Tests without speed data (NA) are not plotted.',
                  style:
                      TextStyle(fontSize: 11, color: AppColors.secondaryLabel),
                ),
              ),
              const SizedBox(height: 20),
              Row(children: [
                Expanded(
                  child: Text('Typing history',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AppColors.label)),
                ),
                if (store.results.isNotEmpty)
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: widget.onOpenHistory,
                    child: const Text('See all'),
                  ),
              ]),
              const SizedBox(height: 4),
              if (recent.isEmpty)
                _empty()
              else
                for (final r in recent) ResultTile(store: store, result: r),
              if (store.lastSyncedAt != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Synced from artypingplatform.com · '
                    '${DateFormat('d MMM, HH:mm').format(store.lastSyncedAt!)}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 11, color: AppColors.secondaryLabel),
                  ),
                ),
            ]),
          ),
        ),
      ]),
    );
  }

  /// The same four cards as the member-area Typing History page.
  Widget _statsGrid() {
    String n(double? v, [int digits = 2]) =>
        v == null ? '—' : v.toStringAsFixed(digits);
    final tiles = [
      (
        'Total Tests Attempted',
        store.totalTests?.toString() ?? '—',
        '',
        AppColors.dotTests
      ),
      ('Avg. Gross Speed', n(store.avgGross), 'wpm', AppColors.dotGross),
      ('Avg. Net Speed', n(store.avgNet), 'wpm', AppColors.dotNet),
      ('Avg. Accuracy', n(store.avgAccuracy), '%', AppColors.dotAcc),
    ];
    return Column(children: [
      for (var row = 0; row < 2; row++) ...[
        if (row > 0) const SizedBox(height: 10),
        Row(children: [
          for (var col = 0; col < 2; col++) ...[
            if (col > 0) const SizedBox(width: 10),
            Expanded(child: _statCard(tiles[row * 2 + col])),
          ],
        ]),
      ],
      if (store.memberStats == null && !store.syncing)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            'Member stats are not available from AR Typing yet.',
            style: TextStyle(fontSize: 12, color: AppColors.secondaryLabel),
          ),
        ),
    ]);
  }

  Widget _statCard((String, String, String, Color) t) {
    return IosCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: t.$4, shape: BoxShape.circle)),
            const SizedBox(width: 6),
            Expanded(
              child: Text(t.$1,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      TextStyle(fontSize: 12, color: AppColors.secondaryLabel)),
            ),
          ]),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text.rich(TextSpan(children: [
              TextSpan(
                  text: t.$2,
                  style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: AppColors.label)),
              if (t.$3.isNotEmpty && t.$2 != '—')
                TextSpan(
                    text: ' ${t.$3}',
                    style: TextStyle(
                        fontSize: 14, color: AppColors.secondaryLabel)),
            ])),
          ),
        ],
      ),
    );
  }

  Widget _legend(Color c, String label) => Row(children: [
        Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Text(label,
            style: TextStyle(fontSize: 11, color: AppColors.secondaryLabel)),
      ]);

  Widget _empty() => Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(children: [
          Icon(CupertinoIcons.doc_text_search,
              size: 40, color: AppColors.tertiaryLabel),
          const SizedBox(height: 10),
          Text(
            store.syncing
                ? 'Fetching your typing history…'
                : 'No typing results on AR Typing yet',
            style:
                TextStyle(fontWeight: FontWeight.w700, color: AppColors.label),
          ),
          const SizedBox(height: 4),
          Text(
            'Type a passage on artypingplatform.com — it will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppColors.secondaryLabel),
          ),
        ]),
      );
}
