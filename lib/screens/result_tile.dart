import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';

import '../data/store.dart';
import '../models/ar_result.dart';
import '../theme/app_colors.dart';
import 'result_detail_screen.dart';

/// Speed text as on the website: value, or "NA" when not available.
String speedText(double? v) => v == null ? 'NA' : v.toStringAsFixed(2);

/// Green above target, red below — the member-area table's colouring.
Color speedColor(double? v, int? target) {
  if (v == null || target == null) return AppColors.label;
  if (v > target) return AppColors.green;
  if (v < target) return AppColors.red;
  return AppColors.label;
}

/// One Typing History row.
class ResultTile extends StatelessWidget {
  final AppStore store;
  final ArResult result;
  const ResultTile({super.key, required this.store, required this.result});

  @override
  Widget build(BuildContext context) {
    final r = result;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.of(context).push(CupertinoPageRoute(
          builder: (_) => ResultDetailScreen(store: store, result: r))),
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
            Text(r.examTitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: AppColors.label)),
            const SizedBox(height: 2),
            Text(r.passageTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    TextStyle(color: AppColors.secondaryLabel, fontSize: 13)),
            const SizedBox(height: 10),
            Row(children: [
              _cell(DateFormat('dd/MM/yy').format(r.date), 'Date'),
              _cell(
                  r.timeTakenSec == null ? '—' : mmss(r.timeTakenSec!), 'Time'),
              _cell('${r.keystrokesTyped ?? '—'}', 'Keys'),
              _cell(r.targetWpm?.toString() ?? 'NA', 'Target'),
              _cell(speedText(r.grossWpm), 'Gross',
                  color: speedColor(r.grossWpm, r.targetWpm)),
              _cell(speedText(r.netWpm), 'Net',
                  color: speedColor(r.netWpm, r.targetWpm)),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _cell(String v, String l, {Color? color}) => Expanded(
        child: Column(children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(v,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: color ?? AppColors.label)),
          ),
          Text(l,
              style: TextStyle(fontSize: 10, color: AppColors.secondaryLabel)),
        ]),
      );
}
