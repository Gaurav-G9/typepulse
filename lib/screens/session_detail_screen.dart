import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';

import '../data/scoring.dart';
import '../data/store.dart';
import '../models/session.dart';
import '../theme/app_colors.dart';
import '../widgets/activity_rings.dart';
import '../widgets/store_rebuild.dart';

class SessionDetailScreen extends StatefulWidget {
  final AppStore store;
  final TypingSession session;
  const SessionDetailScreen({super.key, required this.store, required this.session});

  @override
  State<SessionDetailScreen> createState() => _SessionDetailScreenState();
}

class _SessionDetailScreenState extends State<SessionDetailScreen>
    with RebuildOn<SessionDetailScreen> {
  @override
  Listenable get rebuildSource => widget.store;

  bool speedOnDuration = false;
  bool keystrokeFormula = true;

  TypingSession get s => widget.session;

  bool get isAr => s.source == 'ar' || s.id.startsWith('ar-');

  ScoreBreakdown? _cached;
  List<WordAlignment>? _aligned;
  (bool, bool)? _cachedFor;

  /// Word alignment is O(words²) — only recompute when a toggle changes.
  ScoreBreakdown get breakdown {
    final key = (speedOnDuration, keystrokeFormula);
    if (_cached != null && _cachedFor == key) return _cached!;
    _cachedFor = key;
    return _cached = _computeBreakdown();
  }

  ScoreBreakdown _computeBreakdown() {
    final hasTexts = (s.expectedText?.isNotEmpty ?? false) && (s.typedText?.isNotEmpty ?? false);
    final ScoreBreakdown b;
    if (hasTexts) {
      b = Scoring.evaluate(
        expected: s.expectedText!,
        typed: s.typedText!,
        durationSec: s.durationSec,
        timeTakenSec: s.timeTakenSec,
        targetWpm: s.targetWpm,
        useDurationForSpeed: speedOnDuration,
        keystrokeWordFormula: keystrokeFormula,
      );
    } else {
      b = Scoring.approximateFromSession(
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
    // With default toggles an AR result shows AR Typing's official numbers;
    // the toggles switch to an on-device recalculation.
    if (isAr && !speedOnDuration && keystrokeFormula) {
      return b.withOfficial(
        grossWpm: s.wpm,
        netWpm: s.netWpm,
        accuracy: s.accuracy,
        qualified: s.qualified,
        note: s.formulaNote,
      );
    }
    return b;
  }

  @override
  Widget build(BuildContext context) {
    final b = breakdown;
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
              const Padding(
                padding: EdgeInsets.only(bottom: 10),
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
            _meta('Target speed', s.targetWpm > 0 ? '${s.targetWpm} wpm' : 'NA'),
            _meta('Duration', mmss(s.durationSec)),
            _meta('Date', DateFormat('dd/MM/yyyy').format(s.startedAt)),
            _meta('Time taken', mmss(s.timeTakenSec)),
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
      CupertinoSwitch(value: value, activeTrackColor: active, onChanged: onChanged),
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
    final aligned = _aligned ??= Scoring.alignWords(expected, typed);
    final rows = <Widget>[];
    const limit = 120;
    final shown = aligned.length > limit ? limit : aligned.length;
    for (var i = 0; i < shown; i++) {
      final w = aligned[i];
      final Color color;
      final String tag;
      switch (w.mark) {
        case WordMark.correct:
          color = AppColors.green;
          tag = '';
        case WordMark.pending:
          color = AppColors.secondaryLabel;
          tag = ' (unfinished)';
        case WordMark.half:
          color = AppColors.orange;
          tag = ' ½';
        case WordMark.full:
          color = AppColors.red;
          tag = '';
        case WordMark.omitted:
          color = AppColors.red;
          tag = ' (missed)';
        case WordMark.extra:
          color = AppColors.red;
          tag = ' (extra)';
      }
      rows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(children: [
            SizedBox(width: 32, child: Text('${i + 1}', style: TextStyle(fontSize: 11, color: AppColors.secondaryLabel))),
            Expanded(child: Text(w.expected ?? '—', style: TextStyle(fontSize: 13, color: AppColors.secondaryLabel))),
            Expanded(
              child: Text(
                '${w.typed ?? '—'}$tag',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ),
          ]),
        ),
      );
    }
    if (aligned.length > limit) {
      rows.add(Text('… ${aligned.length - limit} more words', style: TextStyle(color: AppColors.secondaryLabel, fontSize: 12)));
    }
    if (aligned.isEmpty) {
      rows.add(Text('Nothing was typed in this session.', style: TextStyle(color: AppColors.secondaryLabel, fontSize: 13)));
    }
    return rows;
  }
}
