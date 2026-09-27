import 'dart:async';

import 'package:flutter/cupertino.dart';

import '../data/exams.dart';
import '../data/passages.dart';
import '../data/store.dart';
import '../theme/app_colors.dart';
import '../widgets/store_rebuild.dart';
import 'session_detail_screen.dart';

class PracticeScreen extends StatefulWidget {
  final AppStore store;
  final bool liveMode;
  final Passage? forcedPassage;
  final int? seconds;
  const PracticeScreen({
    super.key,
    required this.store,
    this.liveMode = false,
    this.forcedPassage,
    this.seconds,
  });

  @override
  State<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends State<PracticeScreen>
    with RebuildOn<PracticeScreen> {
  @override
  Listenable get rebuildSource => widget.store;

  late ExamSpec exam;
  late Passage passage;
  late int remaining;
  late int allotted;
  Timer? timer;
  final controller = TextEditingController();
  bool running = false;
  bool done = false;
  bool picking = true;
  int backspaces = 0;
  String last = '';

  @override
  void initState() {
    super.initState();
    final lang = widget.store.profile.languagePref;
    exam = lang == 'hi' ? Exams.upssscHindi : Exams.upssscEnglish;
    final list = Passages.byLang(exam.language);
    passage = widget.forcedPassage ?? (list.isEmpty ? Passages.all.first : list.first);
    allotted = widget.seconds ?? exam.durationSec;
    remaining = allotted;
    if (widget.forcedPassage != null || widget.liveMode) {
      picking = false;
    }
    controller.addListener(_onType);
  }

  @override
  void dispose() {
    timer?.cancel();
    controller.dispose();
    super.dispose();
  }

  void _applyExam(ExamSpec e) {
    setState(() {
      exam = e;
      allotted = e.durationSec;
      remaining = allotted;
      final list = Passages.byLang(e.language);
      if (list.isNotEmpty && passage.language != e.language) {
        passage = list.first;
      }
    });
  }

  void _start() {
    if (running || done) return;
    setState(() {
      picking = false;
      running = true;
    });
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (remaining <= 1) {
        _finish();
      } else {
        setState(() => remaining--);
      }
    });
  }

  void _onType() {
    if (done) return;
    final input = controller.text;
    // The controller also notifies on cursor/selection moves (e.g. tapping
    // the field); only real text changes should start the clock.
    if (input == last) return;
    if (input.length < last.length) backspaces += last.length - input.length;
    last = input;
    if (!running) _start();
    if (input.length >= passage.text.length) _finish();
    setState(() {});
  }

  void _finish() {
    if (done) return;
    timer?.cancel();
    setState(() {
      done = true;
      running = false;
    });
    final taken = (allotted - remaining).clamp(1, allotted);
    final session = AppStore.buildSession(
      allottedSec: allotted,
      timeTakenSec: taken,
      language: passage.language,
      mode: widget.liveMode ? 'live' : 'practice',
      examTitle: widget.liveMode ? 'Live Typing Heat' : exam.title,
      passageTitle: passage.title,
      expected: passage.text,
      typed: controller.text,
      backspaceCount: backspaces,
      targetWpm: exam.targetWpm,
      errorAllowance: exam.errorAllowance,
      useDurationForSpeed: false,
      keystrokeWordFormula: true,
    );
    widget.store.addSession(session);
    Navigator.of(context).pushReplacement(
      CupertinoPageRoute(
        builder: (_) => SessionDetailScreen(store: widget.store, session: session),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (picking && !widget.liveMode) {
      return _picker();
    }
    return CupertinoPageScaffold(
      backgroundColor: AppColors.background,
      navigationBar: CupertinoNavigationBar(
        middle: Text(widget.liveMode ? 'Live heat' : 'Practice', style: TextStyle(color: AppColors.label)),
        backgroundColor: AppColors.navBar,
        border: null,
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: done ? null : _finish,
          child: const Text('End'),
        ),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              '${remaining}s',
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.indigo),
            ),
            const SizedBox(height: 4),
            Text(
              '${exam.title} · target ${exam.targetWpm}',
              style: TextStyle(fontSize: 12, color: AppColors.secondaryLabel),
            ),
            const SizedBox(height: 14),
            Text(passage.text, style: TextStyle(fontSize: 16, height: 1.45, color: AppColors.label)),
            const SizedBox(height: 14),
            CupertinoTextField(
              controller: controller,
              maxLines: 8,
              minLines: 6,
              enabled: !done,
              placeholder: 'Tap and type the passage',
              padding: const EdgeInsets.all(12),
              style: TextStyle(color: AppColors.label),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.separator),
              ),
            ),
            const SizedBox(height: 16),
            if (!running && !done)
              CupertinoButton.filled(
                onPressed: _start,
                child: Text('Start ${allotted ~/ 60} min'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _picker() {
    final passages = Passages.byLang(exam.language);
    return CupertinoPageScaffold(
      backgroundColor: AppColors.canvas,
      navigationBar: CupertinoNavigationBar(
        middle: Text('New Workout', style: TextStyle(color: AppColors.label)),
        backgroundColor: AppColors.navBar,
        border: null,
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Exam', style: TextStyle(fontSize: 13, color: AppColors.secondaryLabel, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            ...Exams.all.map((e) {
              final on = exam.id == e.id;
              return GestureDetector(
                onTap: () => _applyExam(e),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: on ? AppColors.label : AppColors.groupedBackground,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        e.title,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: on ? AppColors.canvas : AppColors.label,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${e.durationSec ~/ 60} min · target ${e.targetWpm} · ${e.keystrokesGiven} keys · allow ${e.errorAllowance}',
                        style: TextStyle(
                          fontSize: 12,
                          color: on ? AppColors.canvas.withValues(alpha: 0.7) : AppColors.secondaryLabel,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 12),
            Text('Passage', style: TextStyle(fontSize: 13, color: AppColors.secondaryLabel, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            ...passages.map((p) {
              final on = passage.id == p.id;
              return GestureDetector(
                onTap: () => setState(() => passage = p),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.groupedBackground,
                    borderRadius: BorderRadius.circular(14),
                    border: on ? Border.all(color: AppColors.indigo, width: 2) : null,
                  ),
                  child: Text(p.title, style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.label)),
                ),
              );
            }),
            const SizedBox(height: 16),
            CupertinoButton.filled(
              onPressed: () => setState(() => picking = false),
              child: Text('Continue · ${allotted ~/ 60} min'),
            ),
          ],
        ),
      ),
    );
  }
}
