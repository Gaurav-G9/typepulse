import 'dart:async';
import 'package:flutter/cupertino.dart';
import '../data/passages.dart';
import '../data/store.dart';
import '../theme/app_colors.dart';
import 'session_detail_screen.dart';

class PracticeScreen extends StatefulWidget {
  final AppStore store;
  final bool liveMode;
  final Passage? forcedPassage;
  final int seconds;
  const PracticeScreen({super.key, required this.store, this.liveMode = false, this.forcedPassage, this.seconds = 60});
  @override
  State<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends State<PracticeScreen> {
  late Passage passage;
  late int remaining;
  Timer? timer;
  final controller = TextEditingController();
  bool running = false;
  bool done = false;
  int backspaces = 0;
  String last = '';

  @override
  void initState() {
    super.initState();
    final lang = widget.store.profile.languagePref;
    final list = Passages.byLang(lang);
    passage = widget.forcedPassage ?? (list.isEmpty ? Passages.all.first : list.first);
    remaining = widget.seconds;
    controller.addListener(_onType);
  }

  @override
  void dispose() {
    timer?.cancel();
    controller.dispose();
    super.dispose();
  }

  void _start() {
    if (running || done) return;
    setState(() => running = true);
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
    if (input.length < last.length) backspaces += last.length - input.length;
    last = input;
    if (!running) _start();
    if (input.length >= passage.text.length) _finish();
    setState(() {});
  }

  void _finish() {
    if (done) return;
    timer?.cancel();
    setState(() { done = true; running = false; });
    final taken = (widget.seconds - remaining).clamp(1, widget.seconds);
    final session = AppStore.buildSession(
      allottedSec: widget.seconds,
      timeTakenSec: taken,
      language: passage.language,
      mode: widget.liveMode ? 'live' : 'practice',
      examTitle: widget.liveMode ? 'Live Typing Heat' : 'UPSSSC Assistants English Typing Test',
      passageTitle: passage.title,
      expected: passage.text,
      typed: controller.text,
      backspaceCount: backspaces,
      targetWpm: widget.store.profile.targetWpm,
    );
    widget.store.addSession(session);
    Navigator.of(context).pushReplacement(CupertinoPageRoute(builder: (_) => SessionDetailScreen(store: widget.store, session: session)));
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppColors.background,
      navigationBar: CupertinoNavigationBar(
        middle: Text(widget.liveMode ? 'Live heat' : 'Practice'),
        trailing: CupertinoButton(padding: EdgeInsets.zero, onPressed: done ? null : _finish, child: const Text('End')),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('${remaining}s', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.indigo)),
            const SizedBox(height: 12),
            Text(passage.text, style: const TextStyle(fontSize: 17, height: 1.4)),
            const SizedBox(height: 12),
            CupertinoTextField(controller: controller, maxLines: 8, minLines: 6, enabled: !done, placeholder: 'Tap and type the passage'),
            const SizedBox(height: 16),
            if (!running && !done)
              CupertinoButton.filled(onPressed: _start, child: Text('Start ${widget.seconds ~/ 60} min')),
          ],
        ),
      ),
    );
  }
}
