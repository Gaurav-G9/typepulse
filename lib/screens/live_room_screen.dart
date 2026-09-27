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
  int remaining = duration;
  bool running = false;
  bool done = false;
  final rng = Random();

  @override
  void initState() {
    super.initState();
    final names = ['Aarav', 'Isha', 'Rohan', 'Neha', 'Kabir', 'Ananya', 'Vikram']..shuffle();
    field = [LiveRacer(id: widget.store.profile.id, name: 'You', isYou: true), ...List.generate(widget.fieldSize - 1, (i) => LiveRacer(id: 'b$i', name: names[i]))];
    controller.addListener(_onType);
  }

  @override
  void dispose() {
    tick?.cancel();
    controller.dispose();
    super.dispose();
  }

  void _start() {
    if (running) return;
    setState(() => running = true);
    tick = Timer.periodic(const Duration(milliseconds: 400), (_) {
      if (!mounted || done) return;
      setState(() {
        for (final r in field.where((e) => !e.isYou && !e.finished)) {
          r.progress = min(1, r.progress + 0.01 + rng.nextDouble() * 0.02);
          r.wpm = 22 + r.progress * 20;
          if (r.progress >= 1) r.finished = true;
        }
      });
    });
    Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted || done) { t.cancel(); return; }
      setState(() => remaining--);
      if (remaining <= 0) _finish();
    });
  }

  void _onType() {
    if (done) return;
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
      navigationBar: CupertinoNavigationBar(middle: Text(widget.roomName), trailing: Text('${remaining}s')),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Rank #$myRank of ${field.length}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 22)),
            const SizedBox(height: 10),
            ...sorted.map((r) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text('${r.name}   ${(r.progress * 100).toStringAsFixed(0)}%   ${r.wpm.toStringAsFixed(0)} wpm',
                  style: TextStyle(fontWeight: r.isYou ? FontWeight.w800 : FontWeight.w500)),
            )),
            const SizedBox(height: 12),
            Text(widget.passage.text),
            const SizedBox(height: 10),
            CupertinoTextField(controller: controller, maxLines: 5, enabled: !done, placeholder: 'Type to race'),
          ],
        ),
      ),
    );
  }
}
