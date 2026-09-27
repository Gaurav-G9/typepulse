import 'package:flutter/cupertino.dart';
import '../data/store.dart';
import '../models/session.dart';
import 'session_detail_screen.dart';

class SessionResultScreen extends StatelessWidget {
  final AppStore store;
  final TypingSession session;
  const SessionResultScreen({super.key, required this.store, required this.session});
  @override
  Widget build(BuildContext context) => SessionDetailScreen(store: store, session: session);
}
