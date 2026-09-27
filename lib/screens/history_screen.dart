import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';
import '../data/store.dart';
import '../theme/app_colors.dart';
import 'session_detail_screen.dart';

class HistoryScreen extends StatelessWidget {
  final AppStore store;
  const HistoryScreen({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppColors.canvas,
      navigationBar: const CupertinoNavigationBar(middle: Text('Workouts'), backgroundColor: AppColors.navBar, border: null),
      child: SafeArea(
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: store.sessions.length,
          itemBuilder: (context, i) {
            final s = store.sessions[i];
            return GestureDetector(
              onTap: () => Navigator.of(context).push(CupertinoPageRoute(builder: (_) => SessionDetailScreen(store: store, session: s))),
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: AppColors.groupedBackground, borderRadius: BorderRadius.circular(16)),
                child: Row(
                  children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(s.examTitle, style: const TextStyle(fontWeight: FontWeight.w700)),
                      Text(s.passageTitle, style: const TextStyle(color: AppColors.secondaryLabel, fontSize: 13)),
                    ])),
                    Text('${s.netWpm.toStringAsFixed(1)}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
