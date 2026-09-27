import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';

import '../data/scoring.dart';
import '../data/store.dart';
import '../models/session.dart';
import '../theme/app_colors.dart';
import '../widgets/activity_rings.dart';

class SessionDetailScreen extends StatefulWidget {
  final AppStore store;
  final TypingSession session;
  const SessionDetailScreen({super.key, required this.store, required this.session});

  @override
  State<SessionDetailScreen> createState() => _SessionDetailScreenState();
}

class _SessionDetailScreenState extends State<SessionDetailScreen> {
  bool speedOnDuration = false;
  bool keystrokeFormula = true;

  TypingSession get s => widget.session;

  ScoreBreakdown get breakdown {
    final hasTexts = (s.expectedText?.isNotEmpty ?? false) && (s.typedText?.isNotEmpty ?? false);
    if (hasTexts) {
      return Scoring.evaluate(
        expected: s.expectedText!,
        typed: s.typedText!,
        durationSec: s.durationSec,
        timeTakenSec: s.timeTakenSec,
        targetWpm: s.targetWpm,
        useDurationForSpeed: speedOnDuration,
        keystrokeWordFormula: keystrokeFormula,
      );
    }
    return Scoring.approximateFromSession(
      typedChars: s.typedChars,
      storedWordsTyped: s.wordsTyped,
      fullMistakes: s.fullMistakes,
      halfMistakes: s.halfMistakes,
      durationSec: s.durationSec,
      timeTakenSec: s.timeTakenSec,
      targetWpm: s.targetWpm,
      accuracy: s.accuracy,
      correctChars: s.correctChars,
      errors: s.errors,
      useDurationForSpeed: speedOnDuration,
      keystrokeWordFormula: keystrokeFormula,
    );
  }

  @override
  Widget build(BuildContext context) {
    final b = breakdown;
    final isAr = s.source == 'ar' || s.id.startsWith('ar-');
    return CupertinoPageScaffold(
      backgroundColor: AppColors.canvas,
      navigationBar: CupertinoNavigationBar(
        middle: Text('Dashboard', style: TextStyle(color: AppColors.label)),
        backgroundColor: AppColors.navBar,
        border: null,
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 36),
          children: [
            if (isAr)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text('Synced from AR Typing', style: TextStyle(fontSize: 12, color: AppColors.blue, fontWeight: FontWeight.w600)),
              ),
            _toggleRow(
              'Speed on Time Duration',
              speedOnDuration,
              AppColors.green,
              (v) => setState(() => speedOnDuration = v),
            ),
            const SizedBox(height: 10),
            _meta('Exam', s.examTitle),
            _meta('Passage', s.passageTitle),
            _meta('Keystrokes given', '${s.keystrokesGiven}'),
            _meta('Duration', '${mmss(s.durationSec)}'),
            _meta('Date', DateFormat('dd/MM/yyyy').format(s.startedAt)),
            _meta('Time taken', '${mmss(s.timeTakenSec)}'),
            _toggleRow(
              'Keystroke word formula (/5)',
              keystrokeFormula,
              AppColors.red,
              (v) => setState(() => keystrokeFormula = v),
            ),
            const SizedBox(height: 12),
            DashRow(title: 'Keystrokes / Words', value: '${b.typedChars} / ${b.wordsTyped.toStringAsFixed(1)}', icon: CupertinoIcons.keyboard),
            const SizedBox(height: 8),
            DashRow(title: 'Full Mistake', value: '${b.fullMistakes}', icon: CupertinoIcons.xmark_circle),
            const SizedBox(height: 8),
            DashRow(title: 'Half Mistake', value: '${b.halfMistakes}', icon: CupertinoIcons.lab_flask),
            const SizedBox(height: 8),
            DashRow(title: 'Total Wrong Words', value: b.totalWrongWords.toStringAsFixed(1), icon: CupertinoIcons.xmark_circle),
            const SizedBox(height: 8),
            DashRow(title: 'Net Wrong Words', value: b.netWrongWords.toStringAsFixed(2), icon: CupertinoIcons.lab_flask),
            const SizedBox(height: 8),
            DashRow(title: 'Gross Speed (wpm)', value: b.grossWpm.toStringAsFixed(2), icon: CupertinoIcons.speedometer),
            const SizedBox(height: 8),
            DashRow(title: 'Net Typing Speed (wpm)', value: b.netWpm.toStringAsFixed(2), icon: CupertinoIcons.gauge),
            const SizedBox(height: 8),
            DashRow(title: 'Accuracy', value: '${b.accuracy.toStringAsFixed(0)} %', icon: CupertinoIcons.checkmark_seal),
            const SizedBox(height: 8),
            DashRow(title: 'Backspace', value: '${s.backspaceCount}', icon: CupertinoIcons.delete_left),
            const SizedBox(height: 8),
            DashRow(title: 'Result', value: b.qualified ? 'Qualified' : 'Not Qualified', icon: CupertinoIcons.scope),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.dark ? const Color(0xFF1A2744) : const Color(0xFFEEF4FF),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                b.formulaNote,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.35,
                  color: AppColors.dark ? const Color(0xFFB8D0FF) : const Color(0xFF1C3A6E),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text('Detailed Comparison', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.label)),
            const SizedBox(height: 8),
            if ((s.expectedText?.isNotEmpty ?? false) && (s.typedText?.isNotEmpty ?? false))
              ..._wordDiff(s.expectedText!, s.typedText!)
            else ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.groupedBackground,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    Icon(CupertinoIcons.doc_text_search, size: 36, color: AppColors.tertiaryLabel),
                    const SizedBox(height: 10),
                    Text(
                      isAr ? 'Passage text not included in sync' : 'No passage text for this session',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.label),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isAr
                          ? 'AR Typing sometimes omits full passage bodies. Scores above still reflect the synced result.'
                          : 'Complete a practice or live test to see word-by-word comparison here.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: AppColors.secondaryLabel, height: 1.35),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _toggleRow(String label, bool value, Color active, ValueChanged<bool> onChanged) {
    return Row(children: [
      Expanded(child: Text(label, style: TextStyle(fontSize: 13, color: AppColors.secondaryLabel))),
      CupertinoSwitch(value: value, activeColor: active, onChanged: onChanged),
    ]);
  }

  Widget _meta(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text.rich(
        TextSpan(
          style: TextStyle(color: AppColors.label, fontSize: 15),
          children: [
            TextSpan(text: '$k: ', style: const TextStyle(fontWeight: FontWeight.w700)),
            TextSpan(text: v),
          ],
        ),
      ),
    );
  }

  List<Widget> _wordDiff(String expected, String typed) {
    final exp = expected.trim().isEmpty ? <String>[] : expected.trim().split(RegExp(r'\s+'));
    final got = typed.trim().isEmpty ? <String>[] : typed.trim().split(RegExp(r'\s+'));
    final n = exp.length > got.length ? exp.length : got.length;
    final rows = <Widget>[];
    final limit = n > 80 ? 80 : n;
    for (var i = 0; i < limit; i++) {
      final a = i < exp.length ? exp[i] : '—';
      final b = i < got.length ? got[i] : '—';
      final ok = a == b;
      rows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(children: [
            SizedBox(width: 28, child: Text('${i + 1}', style: TextStyle(fontSize: 11, color: AppColors.secondaryLabel))),
            Expanded(child: Text(a, style: TextStyle(fontSize: 13, color: AppColors.secondaryLabel))),
            Expanded(
              child: Text(
                b,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: ok ? AppColors.green : AppColors.red,
                ),
              ),
            ),
          ]),
        ),
      );
    }
    if (n > 80) {
      rows.add(Text('… ${n - 80} more words', style: TextStyle(color: AppColors.secondaryLabel, fontSize: 12)));
    }
    return rows;
  }
}
