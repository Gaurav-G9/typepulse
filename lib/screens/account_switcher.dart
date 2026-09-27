import 'package:flutter/cupertino.dart';

import '../data/store.dart';
import '../models/ar_account.dart';
import '../theme/app_colors.dart';
import 'ar_login_sheet.dart';

Future<void> showAccountSwitcher(BuildContext context, AppStore store) async {
  await showCupertinoModalPopup<void>(
    context: context,
    builder: (ctx) => AccountSwitcherSheet(store: store),
  );
}

class AccountSwitcherSheet extends StatelessWidget {
  final AppStore store;
  const AccountSwitcherSheet({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.62,
          decoration: BoxDecoration(
            color: AppColors.canvas,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 10),
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
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
                  child: Row(
                    children: [
                      Text(
                        'Accounts',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppColors.label,
                        ),
                      ),
                      const Spacer(),
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Done'),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    'Switch between AR Typing logins on this device. History and stats update immediately.',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.secondaryLabel,
                      height: 1.3,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: store.accounts.isEmpty
                      ? Center(
                          child: Text(
                            'No accounts yet',
                            style: TextStyle(color: AppColors.secondaryLabel),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: store.accounts.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (ctx, i) {
                            final a = store.accounts[i];
                            final active = a.id == store.activeAccountId;
                            return _AccountTile(
                              account: a,
                              active: active,
                              onSwitch: () async {
                                await store.switchAccount(a.id);
                              },
                              onRemove: () => _confirmRemove(ctx, a),
                            );
                          },
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: CupertinoButton.filled(
                    onPressed: () async {
                      Navigator.pop(context);
                      await showArLoginSheet(context, store);
                    },
                    child: const Text('Add account'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _confirmRemove(BuildContext context, ArAccount a) {
    showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Remove account?'),
        content: Text(
          'Removes ${a.email} from this device (tokens + synced history for that account).',
        ),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () async {
              Navigator.pop(ctx);
              await store.removeAccount(a.id);
            },
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }
}

class _AccountTile extends StatelessWidget {
  final ArAccount account;
  final bool active;
  final VoidCallback onSwitch;
  final VoidCallback onRemove;

  const _AccountTile({
    required this.account,
    required this.active,
    required this.onSwitch,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: BoxDecoration(
        color: AppColors.groupedBackground,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(
            CupertinoIcons.person_crop_circle_fill,
            size: 36,
            color: active ? AppColors.indigo : AppColors.secondaryLabel,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  account.displayName,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.label,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  account.email,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.secondaryLabel,
                  ),
                ),
              ],
            ),
          ),
          if (active)
            Icon(CupertinoIcons.checkmark_alt, color: AppColors.green, size: 22)
          else
            CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              onPressed: onSwitch,
              child: const Text('Switch', style: TextStyle(fontSize: 14)),
            ),
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            onPressed: onRemove,
            child: Icon(CupertinoIcons.trash, size: 18, color: AppColors.red),
          ),
        ],
      ),
    );
  }
}
