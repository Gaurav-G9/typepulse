import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';

import '../data/store.dart';
import '../models/session.dart';
import '../theme/app_colors.dart';
import '../widgets/activity_rings.dart';
import '../widgets/ios_card.dart';
import '../widgets/store_rebuild.dart';
import 'session_detail_screen.dart';

class HistoryScreen extends StatefulWidget {
  final AppStore store;
  const HistoryScreen({super.key, required this.store});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen>
    with RebuildOn<HistoryScreen> {
  @override
  Listenable get rebuildSource => widget.store;

  String filter = 'all'; // all | en | hi | qualified

  List<TypingSession> get filtered {
    final all = widget.store.sessions;
    switch (filter) {
      case 'en':
        return all.where((s) => s.language == 'en').toList();
      case 'hi':
        return all.where((s) => s.language == 'hi').toList();
      case 'qualified':
        return all.where((s) => s.qualified).toList();
      default:
        return all;
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final list = filtered;
    return CupertinoPageScaffold(
      backgroundColor: AppColors.canvas,
      navigationBar: CupertinoNavigationBar(
        middle: Text('Workouts', style: TextStyle(color: AppColors.label)),
        backgroundColor: AppColors.navBar,
        border: null,
        trailing: ThemeToggleButton(
          isDark: store.darkMode,
          onToggle: () => store.toggleDarkMode(),
        ),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          children: [
            Row(children: [
              _agg('${store.sessions.length}', 'Tests'),
              _agg(store.avgGross.toStringAsFixed(0), 'Gross'),
              _agg(store.avgNet.toStringAsFixed(0), 'Net'),
              _agg('${store.avgAccuracy.toStringAsFixed(0)}%', 'Acc'),
            ]),
            const SizedBox(height: 14),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                _chip('All', 'all'),
                _chip('English', 'en'),
                _chip('Hindi', 'hi'),
                _chip('Qualified', 'qualified'),
              ]),
            ),
            const SizedBox(height: 14),
            ...list.map((s) {
              final isAr = s.source == 'ar' || s.id.startsWith('ar-');
              return GestureDetector(
                onTap: () => Navigator.of(context).push(
                  CupertinoPageRoute(
                    builder: (_) => SessionDetailScreen(store: store, session: s),
                  ),
                ),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.groupedBackground,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Expanded(
                          child: Text(
                            s.examTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.label, fontSize: 14),
                          ),
                        ),
                        if (isAr)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.blue.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text('AR', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.blue)),
                          ),
                      ]),
                      const SizedBox(height: 2),
                      Text(s.passageTitle, style: TextStyle(color: AppColors.secondaryLabel, fontSize: 13)),
                      const SizedBox(height: 10),
                      Row(children: [
                        _cell(DateFormat('dd/MM/yyyy').format(s.startedAt), 'Date'),
                        _cell(mmss(s.timeTakenSec), 'Time'),
                        _cell('${s.typedChars}', 'Keys'),
                        _cell(s.targetWpm > 0 ? '${s.targetWpm}' : 'NA', 'Tgt'),
                        _cell(s.wpm.toStringAsFixed(0), 'Gross'),
                        _cell(s.netWpm.toStringAsFixed(0), 'Net'),
                      ]),
                    ],
                  ),
                ),
              );
            }),
            if (list.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 40),
                child: Center(
                  child: Text('No workouts in this filter', style: TextStyle(color: AppColors.secondaryLabel)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _agg(String v, String l) {
    return Expanded(
      child: Column(children: [
        Text(v, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.label)),
        const SizedBox(height: 2),
        Text(l, style: TextStyle(fontSize: 11, color: AppColors.secondaryLabel)),
      ]),
    );
  }

  Widget _chip(String label, String key) {
    final on = filter == key;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () => setState(() => filter = key),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: on ? AppColors.label : AppColors.fill,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: on ? AppColors.canvas : AppColors.secondaryLabel,
            ),
          ),
        ),
      ),
    );
  }

  Widget _cell(String v, String l) {
    return Expanded(
      child: Column(children: [
        Text(v, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.label)),
        Text(l, style: TextStyle(fontSize: 9, color: AppColors.secondaryLabel)),
      ]),
    );
  }
}
