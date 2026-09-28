import 'package:flutter/cupertino.dart';

import '../data/store.dart';
import '../theme/app_colors.dart';
import 'ar_login_sheet.dart';

/// First screen: welcome + AR Typing sign-in. Shown whenever there is no
/// signed-in account — the app has no guest mode and no sample data.
class WelcomeScreen extends StatelessWidget {
  final AppStore store;
  const WelcomeScreen({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    final returning = store.activeAccount;
    return CupertinoPageScaffold(
      backgroundColor: AppColors.canvas,
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 48, 24, 32),
          children: [
            Container(
              width: 64,
              height: 64,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.indigo,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(CupertinoIcons.keyboard,
                  color: CupertinoColors.white, size: 34),
            ),
            const SizedBox(height: 20),
            Text(
              returning == null ? 'Welcome to TypePulse' : 'Welcome back',
              style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  color: AppColors.label),
            ),
            const SizedBox(height: 8),
            Text(
              returning == null
                  ? 'Your AR Typing Platform results on your phone — typing '
                      'history, speeds, accuracy and insights, straight from '
                      'your artypingplatform.com member area.\n\n'
                      'Sign in with your AR Typing email and password.'
                  : 'Your session for ${returning.email} has ended. '
                      'Sign in again to keep syncing.',
              style: TextStyle(
                  fontSize: 15, height: 1.4, color: AppColors.secondaryLabel),
            ),
            const SizedBox(height: 28),
            ArLoginForm(store: store, initialEmail: returning?.email),
            const SizedBox(height: 18),
            Text(
              'Your password is sent only to AR Typing. TypePulse keeps just '
              'the sign-in token, in encrypted storage on this device.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppColors.secondaryLabel),
            ),
          ],
        ),
      ),
    );
  }
}
