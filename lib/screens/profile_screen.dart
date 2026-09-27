import 'package:flutter/cupertino.dart';
import '../data/store.dart';
import '../theme/app_colors.dart';
import '../widgets/ios_card.dart';

class ProfileScreen extends StatelessWidget {
  final AppStore store;
  const ProfileScreen({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    final p = store.profile;
    return CustomScrollView(slivers: [
      const CupertinoSliverNavigationBar(largeTitle: Text('You'), border: null, backgroundColor: AppColors.background),
      SliverPadding(
        padding: const EdgeInsets.all(16),
        sliver: SliverList(delegate: SliverChildListDelegate([
          IosCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(p.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            Text(p.handle, style: const TextStyle(color: AppColors.secondaryLabel)),
          ])),
          const SizedBox(height: 12),
          IosCard(child: Row(children: [
            StatTile(label: 'Best', value: store.bestNetWpm.toStringAsFixed(0), suffix: 'wpm'),
            StatTile(label: 'Sessions', value: '${store.sessions.length}', accent: AppColors.blue),
            StatTile(label: 'Streak', value: '${store.streak}', accent: AppColors.orange),
          ])),
          const SizedBox(height: 16),
          IosCard(
            onTap: () => store.updateProfile(p.copyWith(languagePref: p.languagePref == 'hi' ? 'en' : 'hi')),
            child: Text('Language: ${p.languagePref == 'hi' ? 'Hindi' : 'English'}'),
          ),
        ])),
      ),
    ]);
  }
}
