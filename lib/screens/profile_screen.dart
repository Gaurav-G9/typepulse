import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';

import '../data/store.dart';
import '../theme/app_colors.dart';
import '../widgets/ios_card.dart';
import 'account_switcher.dart';

/// "You": AR Typing profile, My Subscription, accounts and app settings.
class ProfileScreen extends StatelessWidget {
  final AppStore store;
  const ProfileScreen({super.key, required this.store});

  static String? _field(Map<String, dynamic>? m, String k) {
    final v = m?[k];
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  @override
  Widget build(BuildContext context) {
    final p = store.studentProfile;
    final dob = _field(p, 'date_of_birth');
    final dobDate = dob == null ? null : DateTime.tryParse(dob);
    final city = _field(p, 'city');
    final state = _field(p, 'state');
    final profileRows = <(String, String)>[
      if (store.email != null) ('Email', store.email!),
      if (_field(p, 'phone_number') != null)
        ('Phone', _field(p, 'phone_number')!),
      if (dob != null)
        (
          'Date of birth',
          dobDate == null ? dob : DateFormat('dd/MM/yyyy').format(dobDate)
        ),
      if (city != null || state != null)
        ('City / State', [city, state].whereType<String>().join(', ')),
      if (_field(p, 'address') != null) ('Address', _field(p, 'address')!),
    ];

    final dateFmt = DateFormat('dd MMM yyyy');
    final subscribed = store.isSubscribed;
    final days = store.daysRemaining;
    final String? status = subscribed == null
        ? null
        : !subscribed
            ? 'Free'
            : store.isExpired
                ? 'Expired'
                : (days != null && days <= 3)
                    ? 'About to end'
                    : 'Active';
    final statusColor = switch (status) {
      'Active' => AppColors.green,
      'Expired' => AppColors.red,
      'About to end' => AppColors.orange,
      _ => AppColors.secondaryLabel,
    };
    final planRows = <(String, String)>[
      if (store.enrollmentDate != null)
        ('Enrolled', dateFmt.format(store.enrollmentDate!)),
      if (store.expirationDate != null)
        (
          store.isExpired ? 'Expired on' : 'Valid until',
          dateFmt.format(store.expirationDate!)
        ),
      if (days != null) ('Days remaining', '$days'),
    ];

    return ColoredBox(
      color: AppColors.canvas,
      child: CustomScrollView(slivers: [
        CupertinoSliverNavigationBar(
          largeTitle: const Text('You'),
          border: null,
          backgroundColor: AppColors.canvas,
          trailing: ThemeToggleButton(
              isDark: store.darkMode, onToggle: store.toggleDarkMode),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              IosCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(store.displayName ?? store.email ?? 'AR Typing',
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: AppColors.label)),
                    for (final row in profileRows) _kv(row.$1, row.$2),
                    if (profileRows.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text('Profile details load on the next sync.',
                            style: TextStyle(
                                fontSize: 12, color: AppColors.secondaryLabel)),
                      ),
                  ],
                ),
              ),
              _header('My Subscription'),
              IosCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(
                        child: Text(store.planName ?? '—',
                            style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: AppColors.label)),
                      ),
                      if (status != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(status,
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: statusColor)),
                        ),
                    ]),
                    for (final row in planRows) _kv(row.$1, row.$2),
                  ],
                ),
              ),
              _header('Accounts'),
              IosCard(
                onTap: () => showAccountSwitcher(context, store),
                child: Row(children: [
                  const Icon(CupertinoIcons.person_2, color: AppColors.indigo),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${store.accounts.length} account'
                      '${store.accounts.length == 1 ? '' : 's'} on this device',
                      style: TextStyle(
                          fontWeight: FontWeight.w600, color: AppColors.label),
                    ),
                  ),
                  Icon(CupertinoIcons.chevron_right,
                      size: 16, color: AppColors.tertiaryLabel),
                ]),
              ),
              _header('Sync'),
              IosCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(
                        child: Text(
                          store.lastSyncedAt == null
                              ? 'Not synced yet'
                              : 'Last synced ${DateFormat('d MMM, HH:mm').format(store.lastSyncedAt!)}',
                          style: TextStyle(color: AppColors.label),
                        ),
                      ),
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: store.syncing ? null : store.manualRefresh,
                        child: store.syncing
                            ? const CupertinoActivityIndicator()
                            : const Text('Sync now'),
                      ),
                    ]),
                    if (store.statusMessage != null)
                      Text(store.statusMessage!,
                          style: TextStyle(
                              fontSize: 12, color: AppColors.secondaryLabel)),
                    if (store.error != null)
                      Text(store.error!,
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.red)),
                    const SizedBox(height: 10),
                    Container(height: 0.5, color: AppColors.separator),
                    const SizedBox(height: 10),
                    Row(children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Keep syncing in background',
                                style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.label)),
                            const SizedBox(height: 2),
                            Text(
                              'Checks for new results about every 30 s with an '
                              'ongoing notification. Off: every ~15 min '
                              '(Android minimum).',
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
                        onChanged: store.setBackgroundSyncEnabled,
                      ),
                    ]),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              CupertinoButton(
                onPressed: store.syncing ? null : () => _confirmLogout(context),
                child: const Text('Sign out',
                    style: TextStyle(color: AppColors.red)),
              ),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _header(String t) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
        child: Text(t,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.secondaryLabel)),
      );

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 110,
              child: Text(k,
                  style:
                      TextStyle(fontSize: 13, color: AppColors.secondaryLabel)),
            ),
            Expanded(
              child: Text(v,
                  style: TextStyle(fontSize: 13, color: AppColors.label)),
            ),
          ],
        ),
      );

  void _confirmLogout(BuildContext context) {
    showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Sign out?'),
        content: Text('You will need your AR Typing password to sign in '
            'again as ${store.email ?? 'this account'}.'),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(ctx);
              store.logout();
            },
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
  }
}
