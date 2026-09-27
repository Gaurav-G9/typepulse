import 'package:flutter/cupertino.dart';

import '../data/store.dart';
import '../screens/account_switcher.dart';
import '../screens/ar_login_sheet.dart';
import '../theme/app_colors.dart';
import '../widgets/ios_card.dart';

class ProfileScreen extends StatelessWidget {
  final AppStore store;
  const ProfileScreen({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    final p = store.profile;
    return ColoredBox(
      color: AppColors.canvas,
      child: CustomScrollView(slivers: [
        CupertinoSliverNavigationBar(
          largeTitle: const Text('You'),
          border: null,
          backgroundColor: AppColors.canvas,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () => showAccountSwitcher(context, store),
                child: const Icon(
                  CupertinoIcons.person_2_fill,
                  color: AppColors.indigo,
                  size: 22,
                ),
              ),
              ThemeToggleButton(
                isDark: store.darkMode,
                onToggle: () => store.toggleDarkMode(),
              ),
            ],
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              IosCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.name,
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: AppColors.label)),
                    const SizedBox(height: 2),
                    Text(p.handle,
                        style: TextStyle(color: AppColors.secondaryLabel)),
                    if (store.activeAccount != null) ...[
                      const SizedBox(height: 6),
                      Text(store.activeAccount!.email,
                          style: const TextStyle(
                              fontSize: 13, color: AppColors.blue)),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              IosCard(
                child: Row(children: [
                  StatTile(
                      label: 'Best',
                      value: store.bestNetWpm.toStringAsFixed(0),
                      suffix: 'wpm'),
                  StatTile(
                      label: 'Sessions',
                      value: '${store.sessions.length}',
                      accent: AppColors.blue),
                  StatTile(
                      label: 'Streak',
                      value: '${store.streak}',
                      accent: AppColors.orange),
                ]),
              ),
              const SizedBox(height: 16),
              Text('Accounts',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.secondaryLabel)),
              const SizedBox(height: 8),
              IosCard(
                onTap: () => showAccountSwitcher(context, store),
                child: Row(children: [
                  const Icon(CupertinoIcons.person_2,
                      color: AppColors.indigo, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          store.accounts.isEmpty
                              ? 'No AR accounts'
                              : '${store.accounts.length} account${store.accounts.length == 1 ? '' : 's'}',
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppColors.label),
                        ),
                        Text(
                          store.activeAccount != null
                              ? 'Active: ${store.activeAccount!.displayName}'
                              : 'Add an AR Typing login',
                          style: TextStyle(
                              fontSize: 12, color: AppColors.secondaryLabel),
                        ),
                      ],
                    ),
                  ),
                  Icon(CupertinoIcons.chevron_right,
                      size: 16, color: AppColors.tertiaryLabel),
                ]),
              ),
              const SizedBox(height: 16),
              Text('AR Typing',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.secondaryLabel)),
              const SizedBox(height: 8),
              IosCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Icon(
                        store.arConnected
                            ? CupertinoIcons.checkmark_seal_fill
                            : CupertinoIcons.cloud,
                        color: store.arConnected
                            ? AppColors.green
                            : AppColors.secondaryLabel,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          store.arConnected ? 'Connected' : 'Not connected',
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppColors.label),
                        ),
                      ),
                      if (store.arSyncing) const CupertinoActivityIndicator(),
                    ]),
                    if (store.arStatusMessage != null) ...[
                      const SizedBox(height: 8),
                      Text(store.arStatusMessage!,
                          style: TextStyle(
                              fontSize: 12, color: AppColors.secondaryLabel)),
                    ],
                    if (store.arError != null) ...[
                      const SizedBox(height: 8),
                      Text(store.arError!,
                          style:
                              const TextStyle(fontSize: 12, color: AppColors.red)),
                    ],
                    const SizedBox(height: 12),
                    if (!store.arConnected)
                      SizedBox(
                        width: double.infinity,
                        child: CupertinoButton.filled(
                          onPressed: store.arSyncing
                              ? null
                              : () => showArLoginSheet(context, store),
                          child: Text(store.accounts.isEmpty
                              ? 'Sign in to AR Typing'
                              : 'Re-authenticate / Add account'),
                        ),
                      )
                    else ...[
                      Row(children: [
                        Expanded(
                          child: CupertinoButton.filled(
                            onPressed: store.arSyncing
                                ? null
                                : () => store.syncArHistory(),
                            child: const Text('Sync History'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        CupertinoButton(
                          onPressed: store.arSyncing
                              ? null
                              : () => store.arLogout(),
                          child: const Text('Logout',
                              style: TextStyle(color: AppColors.red)),
                        ),
                      ]),
                      Text(
                        '${store.arSessionCount} AR workouts on device',
                        style: TextStyle(
                            fontSize: 12, color: AppColors.secondaryLabel),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text('Background sync',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.secondaryLabel)),
              const SizedBox(height: 8),
              IosCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Keep syncing in background',
                                style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.label)),
                            const SizedBox(height: 4),
                            Text(
                              store.backgroundSyncEnabled
                                  ? 'Foreground service on — ~30s polls with “TypePulse is syncing” notification. Workmanager also runs ~every 15 min (Android OS minimum).'
                                  : 'Off: foreground 30s timer only + Workmanager ~15 min when signed in. Turn on for continuous background/kill-resistant sync.',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.secondaryLabel),
                            ),
                          ],
                        ),
                      ),
                      CupertinoSwitch(
                        value: store.backgroundSyncEnabled,
                        activeTrackColor: AppColors.indigo,
                        onChanged: store.arConnected
                            ? (v) => store.setBackgroundSyncEnabled(v)
                            : null,
                      ),
                    ]),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text('Goals',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.secondaryLabel)),
              const SizedBox(height: 8),
              IosCard(
                onTap: () => _editInt(
                  context,
                  title: 'Daily goal (minutes)',
                  value: p.dailyGoalMinutes,
                  min: 5,
                  max: 120,
                  onSave: (v) =>
                      store.updateProfile(p.copyWith(dailyGoalMinutes: v)),
                ),
                child: Row(children: [
                  Text('Daily goal', style: TextStyle(color: AppColors.label)),
                  const Spacer(),
                  Text('${p.dailyGoalMinutes} min',
                      style: TextStyle(color: AppColors.secondaryLabel)),
                  Icon(CupertinoIcons.chevron_right,
                      size: 16, color: AppColors.tertiaryLabel),
                ]),
              ),
              const SizedBox(height: 8),
              IosCard(
                onTap: () => _editInt(
                  context,
                  title: 'Target WPM',
                  value: p.targetWpm,
                  min: 15,
                  max: 80,
                  onSave: (v) =>
                      store.updateProfile(p.copyWith(targetWpm: v)),
                ),
                child: Row(children: [
                  Text('Target WPM', style: TextStyle(color: AppColors.label)),
                  const Spacer(),
                  Text('${p.targetWpm}',
                      style: TextStyle(color: AppColors.secondaryLabel)),
                  Icon(CupertinoIcons.chevron_right,
                      size: 16, color: AppColors.tertiaryLabel),
                ]),
              ),
              const SizedBox(height: 8),
              IosCard(
                onTap: () => store.updateProfile(
                  p.copyWith(
                      languagePref: p.languagePref == 'hi' ? 'en' : 'hi'),
                ),
                child: Text(
                  'Practice language: ${p.languagePref == 'hi' ? 'Hindi' : 'English'}',
                  style: TextStyle(color: AppColors.label),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Multi-account · FG 30s · Workmanager ~15m · optional FGS · notifications',
                textAlign: TextAlign.center,
                style:
                    TextStyle(fontSize: 11, color: AppColors.secondaryLabel),
              ),
            ]),
          ),
        ),
      ]),
    );
  }

  void _editInt(
    BuildContext context, {
    required String title,
    required int value,
    required int min,
    required int max,
    required ValueChanged<int> onSave,
  }) {
    var current = value.clamp(min, max);
    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => Container(
        height: 280,
        color: AppColors.card,
        child: Column(children: [
          Row(children: [
            CupertinoButton(
                child: const Text('Cancel'),
                onPressed: () => Navigator.pop(ctx)),
            const Spacer(),
            CupertinoButton(
              child: const Text('Save'),
              onPressed: () {
                onSave(current);
                Navigator.pop(ctx);
              },
            ),
          ]),
          Text(title,
              style:
                  TextStyle(fontWeight: FontWeight.w600, color: AppColors.label)),
          Expanded(
            child: CupertinoPicker(
              itemExtent: 36,
              scrollController:
                  FixedExtentScrollController(initialItem: current - min),
              onSelectedItemChanged: (i) => current = min + i,
              children: [
                for (var i = min; i <= max; i++)
                  Center(
                      child:
                          Text('$i', style: TextStyle(color: AppColors.label))),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}
