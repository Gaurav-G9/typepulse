import 'dart:async';
import 'dart:math';
import 'package:flutter/cupertino.dart';
import '../data/passages.dart';
import '../data/store.dart';
import '../models/leaderboard_entry.dart';
import '../theme/app_colors.dart';
import 'session_detail_screen.dart';

class LiveRoomScreen extends StatefulWidget {
  final AppStore store;
  final String roomName;
  final Passage passage;
  final int fieldSize;
  const LiveRoomScreen({super.key, required this.store, required this.roomName, required this.passage, this.fieldSize = 8});
  @override
  State<LiveRoomScreen> createState() => _LiveRoomScreenState();
}

class _LiveRoomScreenState extends State<LiveRoomScreen> {
  static const duration = 60;
  late List<LiveRacer> field;
  final controller = TextEditingController();
  Timer? tick;
  Timer? clock;
  String last = '';
  int remaining = duration;
  bool running = false;
  bool done = false;
  final rng = Random();
  final botPace = <String, double>{}; // bot id → target WPM

  @override
  void initState() {
    super.initState();
    final names = ['Aarav', 'Isha', 'Rohan', 'Neha', 'Kabir', 'Ananya', 'Vikram']..shuffle();
    field = [LiveRacer(id: widget.store.profile.id, name: 'You', isYou: true), ...List.generate(widget.fieldSize - 1, (i) => LiveRacer(id: 'b$i', name: names[i % names.length]))];
    for (final r in field.where((e) => !e.isYou)) {
      botPace[r.id] = 22 + rng.nextDouble() * 23; // 22–45 WPM, exam-realistic
    }
    controller.addListener(_onType);
  }

  @override
  void dispose() {
    tick?.cancel();
    clock?.cancel();
    controller.dispose();
    super.dispose();
  }

  void _start() {
    if (running) return;
    setState(() => running = true);
    tick = Timer.periodic(const Duration(milliseconds: 400), (_) {
      if (!mounted || done) return;
      setState(() {
        final len = max(1, widget.passage.text.length);
        for (final r in field.where((e) => !e.isYou && !e.finished)) {
          final pace = botPace[r.id] ?? 30;
          r.wpm = pace * (0.85 + rng.nextDouble() * 0.3);
          // WPM × 5 keystrokes per word, over one 0.4s tick.
          final chars = r.wpm * 5 / 60 * 0.4;
          r.progress = min(1, r.progress + chars / len);
          if (r.progress >= 1) r.finished = true;
        }
      });
    });
    clock = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted || done) { t.cancel(); return; }
      setState(() => remaining--);
      if (remaining <= 0) _finish();
    });
  }

  void _onType() {
    if (done) return;
    // Ignore cursor/selection-only notifications (e.g. tapping the field).
    if (controller.text == last) return;
    last = controller.text;
    if (!running) _start();
    final you = field.firstWhere((r) => r.isYou);
    setState(() {
      you.progress = (controller.text.length / widget.passage.text.length).clamp(0, 1);
      final used = max(duration - remaining, 1);
      you.wpm = (controller.text.length / 5.0) / (used / 60.0);
      if (you.progress >= 1) you.finished = true;
    });
    if (controller.text.length >= widget.passage.text.length) _finish();
  }

  int get myRank {
    final sorted = [...field]..sort((a, b) => b.progress.compareTo(a.progress));
    return sorted.indexWhere((r) => r.isYou) + 1;
  }

  void _finish() {
    if (done) return;
    tick?.cancel();
    clock?.cancel();
    setState(() => done = true);
    final taken = (duration - max(remaining, 0)).clamp(1, duration);
    final session = AppStore.buildSession(
      allottedSec: duration,
      timeTakenSec: taken.toInt(),
      language: widget.passage.language,
      mode: 'live',
      examTitle: widget.roomName,
      passageTitle: widget.passage.title,
      expected: widget.passage.text,
      typed: controller.text,
      backspaceCount: 0,
      targetWpm: widget.store.profile.targetWpm,
      liveRank: myRank,
      liveField: field.length,
    );
    widget.store.addSession(session);
    Navigator.of(context).pushReplacement(CupertinoPageRoute(builder: (_) => SessionDetailScreen(store: widget.store, session: session)));
  }

  @override
  Widget build(BuildContext context) {
    final sorted = [...field]..sort((a, b) => b.progress.compareTo(a.progress));
    return CupertinoPageScaffold(
      backgroundColor: AppColors.background,
      navigationBar: CupertinoNavigationBar(
        middle: Text(widget.roomName, style: TextStyle(color: AppColors.label)),
        backgroundColor: AppColors.navBar,
        border: null,
        trailing: Text('${max(remaining, 0)}s', style: TextStyle(color: AppColors.label, fontWeight: FontWeight.w600)),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Rank #$myRank of ${field.length}', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 22, color: AppColors.label)),
            const SizedBox(height: 10),
            ...sorted.map((r) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text('${r.name}   ${(r.progress * 100).toStringAsFixed(0)}%   ${r.wpm.toStringAsFixed(0)} wpm',
                  style: TextStyle(color: r.isYou ? AppColors.indigo : AppColors.label, fontWeight: r.isYou ? FontWeight.w800 : FontWeight.w500)),
            )),
            const SizedBox(height: 12),
            Text(widget.passage.text, style: TextStyle(fontSize: 16, height: 1.45, color: AppColors.label)),
            const SizedBox(height: 10),
            CupertinoTextField(
              controller: controller,
              maxLines: 5,
              enabled: !done,
              placeholder: 'Type to race',
              style: TextStyle(color: AppColors.label),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.separator),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
