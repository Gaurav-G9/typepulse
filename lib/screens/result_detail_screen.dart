import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';

import '../data/store.dart';
import '../data/text_compare.dart';
import '../models/ar_result.dart';
import '../theme/app_colors.dart';
import '../widgets/ios_card.dart';
import '../widgets/store_rebuild.dart';
import 'result_tile.dart';

/// "View Detail" for one Typing History result — only values AR Typing
/// provides, plus a word-by-word comparison of the passage and typed text.
class ResultDetailScreen extends StatefulWidget {
  final AppStore store;
  final ArResult result;
  const ResultDetailScreen(
      {super.key, required this.store, required this.result});

  @override
  State<ResultDetailScreen> createState() => _ResultDetailScreenState();
}

class _ResultDetailScreenState extends State<ResultDetailScreen>
    with RebuildOn<ResultDetailScreen> {
  @override
  Listenable get rebuildSource => widget.store;

  List<WordAlignment>? _aligned;
  bool showAllWords = false;

  ArResult get r => widget.result;

  @override
  Widget build(BuildContext context) {
    final rows = <(String, String, Color?)>[
      (
        'Typing exam',
        r.durationSec == null
            ? r.examTitle
            : '${r.examTitle} — ${mmss(r.durationSec!)} min. duration',
        null
      ),
      (
        'Typing passage',
        r.keystrokesGiven == null
            ? r.passageTitle
            : '${r.passageTitle} — ${r.keystrokesGiven} key strokes',
        null
      ),
      ('Typing date', DateFormat('dd/MM/yyyy').format(r.date), null),
      if (r.timeTakenSec != null)
        ('Time used', '${mmss(r.timeTakenSec!)} min.', null),
      if (r.keystrokesTyped != null)
        ('Key strokes typed', '${r.keystrokesTyped}', null),
      if (r.keystrokesError != null)
        ('Key stroke errors', '${r.keystrokesError}', null),
      if (r.accuracy != null)
        ('Accuracy', '${r.accuracy!.toStringAsFixed(2)} %', null),
      ('Target speed', r.targetWpm == null ? 'NA' : '${r.targetWpm} wpm', null),
      (
        'Gross speed',
        r.grossWpm == null ? 'NA' : '${speedText(r.grossWpm)} wpm',
        speedColor(r.grossWpm, r.targetWpm)
      ),
      (
        'Net speed',
        r.netWpm == null ? 'NA' : '${speedText(r.netWpm)} wpm',
        speedColor(r.netWpm, r.targetWpm)
      ),
      if (r.totalWrongWords != null)
        ('Total wrong words', _trim(r.totalWrongWords!), null),
      if (r.backspaces != null) ('Backspace', '${r.backspaces}', null),
      if (r.qualified != null)
        (
          'Result',
          r.qualified! ? 'Qualified' : 'Not Qualified',
          r.qualified! ? AppColors.green : AppColors.red
        ),
    ];

    return CupertinoPageScaffold(
      backgroundColor: AppColors.canvas,
      navigationBar: CupertinoNavigationBar(
        middle: Text('Result', style: TextStyle(color: AppColors.label)),
        backgroundColor: AppColors.navBar,
        border: null,
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            IosCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Column(children: [
                for (var i = 0; i < rows.length; i++) ...[
                  if (i > 0) Container(height: 0.5, color: AppColors.separator),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 130,
                          child: Text(rows[i].$1,
                              style: TextStyle(
                                  fontSize: 14,
                                  color: AppColors.secondaryLabel)),
                        ),
                        Expanded(
                          child: Text(rows[i].$2,
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: rows[i].$3 ?? AppColors.label)),
                        ),
                      ],
                    ),
                  ),
                ],
              ]),
            ),
            if (r.netWpm == null && r.date.isBefore(ArResult.legacyCutoff))
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
                child: Text(
                  'AR Typing did not store speeds for tests before '
                  '13 Mar 2025 (the website shows "See In Detail").',
                  style:
                      TextStyle(fontSize: 12, color: AppColors.secondaryLabel),
                ),
              ),
            const SizedBox(height: 20),
            Text('Detailed comparison',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.label)),
            const SizedBox(height: 8),
            ..._comparison(),
          ],
        ),
      ),
    );
  }

  static String _trim(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

  List<Widget> _comparison() {
    if (!r.hasTexts) {
      return [
        Text(
          'AR Typing did not include the passage and typed text for this '
          'result.',
          style: TextStyle(fontSize: 13, color: AppColors.secondaryLabel),
        ),
      ];
    }
    final aligned =
        _aligned ??= TextCompare.align(r.passageText!, r.typedText!);
    final counts = <WordMark, int>{};
    for (final w in aligned) {
      counts[w.mark] = (counts[w.mark] ?? 0) + 1;
    }
    final shown = showAllWords ? aligned : aligned.take(150).toList();
    return [
      Wrap(spacing: 8, runSpacing: 8, children: [
        _chip('${counts[WordMark.correct] ?? 0} correct', AppColors.green),
        _chip('${counts[WordMark.wrong] ?? 0} wrong', AppColors.red),
        _chip('${counts[WordMark.missed] ?? 0} missed', AppColors.orange),
        _chip('${counts[WordMark.extra] ?? 0} extra', AppColors.pink),
      ]),
      const SizedBox(height: 12),
      IosCard(
        padding: const EdgeInsets.all(14),
        child: Wrap(
          spacing: 5,
          runSpacing: 6,
          children: [for (final w in shown) _word(w)],
        ),
      ),
      if (aligned.length > shown.length)
        CupertinoButton(
          onPressed: () => setState(() => showAllWords = true),
          child: Text('Show all ${aligned.length} words'),
        ),
      const SizedBox(height: 8),
      Text(
        'Green = correct · red = typed differently (original shown after →) '
        '· orange = missed · pink = extra word',
        style: TextStyle(fontSize: 11, color: AppColors.secondaryLabel),
      ),
    ];
  }

  Widget _chip(String text, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(text,
            style:
                TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c)),
      );

  Widget _word(WordAlignment w) {
    final (String text, Color color, bool strike) = switch (w.mark) {
      WordMark.correct => (w.typed!, AppColors.green, false),
      WordMark.unfinished => (w.typed!, AppColors.secondaryLabel, false),
      WordMark.wrong => ('${w.typed} → ${w.expected}', AppColors.red, false),
      WordMark.missed => (w.expected!, AppColors.orange, true),
      WordMark.extra => (w.typed!, AppColors.pink, false),
    };
    return Text(
      text,
      style: TextStyle(
        fontSize: 14,
        color: color,
        fontWeight:
            w.mark == WordMark.correct ? FontWeight.w400 : FontWeight.w700,
        decoration: strike ? TextDecoration.lineThrough : null,
      ),
    );
  }
}
