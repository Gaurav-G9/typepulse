import 'package:flutter/cupertino.dart';

import '../data/store.dart';
import '../theme/app_colors.dart';

/// Cupertino sheet: email + password → AR Typing JWT login + history sync.
Future<void> showArLoginSheet(BuildContext context, AppStore store) async {
  await showCupertinoModalPopup<void>(
    context: context,
    builder: (ctx) => ArLoginSheet(store: store),
  );
}

class ArLoginSheet extends StatefulWidget {
  final AppStore store;
  const ArLoginSheet({super.key, required this.store});

  @override
  State<ArLoginSheet> createState() => _ArLoginSheetState();
}

class _ArLoginSheetState extends State<ArLoginSheet> {
  final email = TextEditingController();
  final password = TextEditingController();
  bool obscure = true;
  bool busy = false;
  String? error;

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final e = email.text.trim();
    final p = password.text;
    if (e.isEmpty || p.isEmpty) {
      setState(() => error = 'Enter your AR Typing email and password.');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    final ok = await widget.store.arLogin(e, p);
    if (!mounted) return;
    setState(() => busy = false);
    if (ok) {
      Navigator.of(context).pop();
    } else {
      setState(() => error = widget.store.arError ?? 'Login failed');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.72,
      decoration: const BoxDecoration(
        color: AppColors.canvas,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            Center(
              child: Container(
                width: 36,
                height: 5,
                decoration: BoxDecoration(
                  color: AppColors.tertiaryLabel,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Connect AR Typing',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            const Text(
              'Sign in with your artypingplatform.com account. TypePulse pulls history and presents it as Fitness-style workouts — your password is stored only in secure device storage.',
              style: TextStyle(fontSize: 13, color: AppColors.secondaryLabel, height: 1.35),
            ),
            const SizedBox(height: 20),
            const Text('Email', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            CupertinoTextField(
              controller: email,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              placeholder: 'you@example.com',
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.fill,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            const SizedBox(height: 14),
            const Text('Password', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            CupertinoTextField(
              controller: password,
              obscureText: obscure,
              placeholder: 'Your AR Typing password',
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.fill,
                borderRadius: BorderRadius.circular(12),
              ),
              suffix: CupertinoButton(
                padding: const EdgeInsets.only(right: 8),
                onPressed: () => setState(() => obscure = !obscure),
                child: Icon(
                  obscure ? CupertinoIcons.eye : CupertinoIcons.eye_slash,
                  size: 20,
                  color: AppColors.secondaryLabel,
                ),
              ),
            ),
            if (error != null) ...[
              const SizedBox(height: 12),
              Text(error!, style: const TextStyle(color: AppColors.red, fontSize: 13)),
            ],
            const SizedBox(height: 20),
            CupertinoButton.filled(
              onPressed: busy ? null : _submit,
              child: busy
                  ? const CupertinoActivityIndicator(color: CupertinoColors.white)
                  : const Text('Sign in & Sync'),
            ),
            const SizedBox(height: 10),
            CupertinoButton(
              onPressed: busy ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }
}
