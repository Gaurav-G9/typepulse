import 'package:flutter/cupertino.dart';

import '../data/store.dart';
import '../theme/app_colors.dart';
import 'result_tile.dart';

/// Full member-area Typing History with search.
class HistoryScreen extends StatefulWidget {
  final AppStore store;
  const HistoryScreen({super.key, required this.store});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final search = TextEditingController();
  String query = '';

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final q = query.trim().toLowerCase();
    final list = q.isEmpty
        ? store.results
        : store.results
            .where((r) =>
                r.examTitle.toLowerCase().contains(q) ||
                r.passageTitle.toLowerCase().contains(q))
            .toList();
    return ColoredBox(
      color: AppColors.canvas,
      child: CustomScrollView(slivers: [
        CupertinoSliverNavigationBar(
          largeTitle: const Text('Typing History'),
          border: null,
          backgroundColor: AppColors.canvas,
          trailing: CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: store.syncing ? null : store.manualRefresh,
            child: store.syncing
                ? const CupertinoActivityIndicator(radius: 10)
                : Icon(CupertinoIcons.arrow_clockwise,
                    color: AppColors.label, size: 22),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          sliver: SliverToBoxAdapter(
            child: CupertinoSearchTextField(
              controller: search,
              placeholder: 'Search exam or passage',
              style: TextStyle(color: AppColors.label),
              onChanged: (v) => setState(() => query = v),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
          sliver: SliverToBoxAdapter(
            child: Text(
              q.isEmpty
                  ? '${store.results.length} result${store.results.length == 1 ? '' : 's'}'
                  : '${list.length} of ${store.results.length}',
              style: TextStyle(fontSize: 12, color: AppColors.secondaryLabel),
            ),
          ),
        ),
        if (list.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 60),
              child: Center(
                child: Text(
                  store.results.isEmpty
                      ? (store.syncing
                          ? 'Fetching your typing history…'
                          : 'No typing results on AR Typing yet')
                      : 'No results match “$query”',
                  style: TextStyle(color: AppColors.secondaryLabel),
                ),
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) => ResultTile(store: store, result: list[i]),
                childCount: list.length,
              ),
            ),
          ),
      ]),
    );
  }
}
