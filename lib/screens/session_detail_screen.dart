import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';
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

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppColors.canvas,
      navigationBar: const CupertinoNavigationBar(middle: Text('Performance Dashboard'), backgroundColor: AppColors.navBar, border: null),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 36),
          children: [
            Row(children: [
              const Expanded(child: Text('Speed based on Time Duration', style: TextStyle(fontSize: 13, color: AppColors.secondaryLabel))),
              CupertinoSwitch(value: speedOnDuration, activeColor: AppColors.green, onChanged: (v) => setState(() => speedOnDuration = v)),
            ]),
            const SizedBox(height: 12),
            _meta('Exam Title', s.examTitle),
            _meta('Passage Title', s.passageTitle),
            _meta('Total Key Strokes Given', '${s.keystrokesGiven}'),
            _meta('Time Duration', '${mmss(s.durationSec)} min.'),
            _meta('Typing Date', DateFormat('dd/MM/yyyy').format(s.startedAt)),
            _meta('Time Taken', '${mmss(s.timeTakenSec)} min.'),
            Row(children: [
              const Expanded(child: Text('Key Stroke Based Error Formula', style: TextStyle(fontSize: 13, color: AppColors.secondaryLabel))),
              CupertinoSwitch(value: keystrokeFormula, activeColor: AppColors.red, onChanged: (v) => setState(() => keystrokeFormula = v)),
            ]),
            const SizedBox(height: 12),
            DashRow(title: 'Total Keystrokes / Words Typed', value: '${s.typedChars} / ${s.wordsTyped.toStringAsFixed(1)}', icon: CupertinoIcons.keyboard),
            const SizedBox(height: 8),
            DashRow(title: 'Full Mistake (Words)', value: '${s.fullMistakes}', icon: CupertinoIcons.xmark_circle),
            const SizedBox(height: 8),
            DashRow(title: 'Half Mistake (Words)', value: '${s.halfMistakes}', icon: CupertinoIcons.lab_flask),
            const SizedBox(height: 8),
            DashRow(title: 'Total Wrong Words', value: '${s.totalWrongWords}', icon: CupertinoIcons.xmark_circle),
            const SizedBox(height: 8),
            DashRow(title: 'Net Wrong Words', value: s.netWrongWords.toStringAsFixed(2), icon: CupertinoIcons.lab_flask),
            const SizedBox(height: 8),
            DashRow(title: 'Net Typing Speed (wpm)', value: s.netWpm.toStringAsFixed(2), icon: CupertinoIcons.gauge),
            const SizedBox(height: 8),
            DashRow(title: 'Gross Speed (wpm)', value: s.wpm.toStringAsFixed(2), icon: CupertinoIcons.speedometer),
            const SizedBox(height: 8),
            DashRow(title: 'Accuracy', value: '${s.accuracy.toStringAsFixed(0)} %', icon: CupertinoIcons.checkmark_seal),
            const SizedBox(height: 8),
            DashRow(title: 'Backspace Count', value: '${s.backspaceCount}', icon: CupertinoIcons.delete_left),
            const SizedBox(height: 8),
            DashRow(title: 'Result', value: s.qualified ? 'Qualified' : 'Not Qualified', icon: CupertinoIcons.scope),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: Color(0xFFEEF4FF), borderRadius: BorderRadius.circular(12)),
              child: Text('Calculation of ${s.formulaNote}', style: const TextStyle(fontSize: 13, height: 1.35, color: Color(0xFF1C3A6E))),
            ),
          ],
        ),
      ),
    );
  }

  Widget _meta(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text.rich(TextSpan(style: const TextStyle(color: AppColors.label, fontSize: 15), children: [
        TextSpan(text: '$k: ', style: const TextStyle(fontWeight: FontWeight.w700)),
        TextSpan(text: v),
      ])),
    );
  }
}
