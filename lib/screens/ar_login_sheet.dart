import 'package:flutter/cupertino.dart';

import '../data/store.dart';
import '../theme/app_colors.dart';

/// Email + password form for the AR Typing Platform.
class ArLoginForm extends StatefulWidget {
  final AppStore store;
  final String? initialEmail;
  final VoidCallback? onSuccess;
  const ArLoginForm(
      {super.key, required this.store, this.initialEmail, this.onSuccess});

  @override
  State<ArLoginForm> createState() => _ArLoginFormState();
}

class _ArLoginFormState extends State<ArLoginForm> {
  late final email = TextEditingController(text: widget.initialEmail ?? '');
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
    final ok = await widget.store.login(e, p);
    if (!mounted) return;
    setState(() {
      busy = false;
      if (!ok) error = widget.store.error ?? 'Sign-in failed';
    });
    if (ok) widget.onSuccess?.call();
  }

  @override
  Widget build(BuildContext context) {
    final fieldDecoration = BoxDecoration(
      color: AppColors.fill,
      borderRadius: BorderRadius.circular(12),
    );
    return AutofillGroup(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Email',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.label)),
          const SizedBox(height: 6),
          CupertinoTextField(
            controller: email,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.email],
            placeholder: 'you@example.com',
            padding: const EdgeInsets.all(14),
            style: TextStyle(color: AppColors.label),
            decoration: fieldDecoration,
          ),
          const SizedBox(height: 14),
          Text('Password',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.label)),
          const SizedBox(height: 6),
          CupertinoTextField(
            controller: password,
            obscureText: obscure,
            autocorrect: false,
            enableSuggestions: false,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.password],
            onSubmitted: (_) => busy ? null : _submit(),
            placeholder: 'Your AR Typing password',
            padding: const EdgeInsets.all(14),
            style: TextStyle(color: AppColors.label),
            decoration: fieldDecoration,
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
            Text(error!,
                style: const TextStyle(color: AppColors.red, fontSize: 13)),
          ],
          const SizedBox(height: 20),
          CupertinoButton.filled(
            onPressed: busy ? null : _submit,
            child: busy
                ? const CupertinoActivityIndicator(color: CupertinoColors.white)
                : const Text('Sign in'),
          ),
        ],
      ),
    );
  }
}

/// Bottom sheet used to add another AR Typing account.
Future<void> showArLoginSheet(BuildContext context, AppStore store) {
  return showCupertinoModalPopup<void>(
    context: context,
    builder: (ctx) => Container(
      height: MediaQuery.of(ctx).size.height * 0.72,
      decoration: BoxDecoration(
        color: AppColors.canvas,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            Text('Add AR Typing account',
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.label)),
            const SizedBox(height: 16),
            ArLoginForm(
              store: store,
              onSuccess: () => Navigator.of(ctx).pop(),
            ),
            CupertinoButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    ),
  );
}
