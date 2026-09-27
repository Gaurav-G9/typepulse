import 'package:flutter/cupertino.dart';
import '../data/passages.dart';
import '../data/store.dart';
import '../theme/app_colors.dart';
import '../widgets/ios_card.dart';
import 'live_room_screen.dart';

class LiveLobbyScreen extends StatelessWidget {
  final AppStore store;
  const LiveLobbyScreen({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    final rooms = [
      ['Morning Heat', 'en'],
      ['Office Sprint', 'en'],
      ['Hindi Live', 'hi'],
      ['Night Marathon', 'en'],
    ];
    return CustomScrollView(slivers: [
      const CupertinoSliverNavigationBar(largeTitle: Text('Live'), border: null, backgroundColor: AppColors.background),
      SliverPadding(
        padding: const EdgeInsets.all(16),
        sliver: SliverList(delegate: SliverChildListDelegate([
          const Text('Join a room. The field is simulated on this device.', style: TextStyle(color: AppColors.secondaryLabel)),
          const SizedBox(height: 16),
          ...rooms.map((r) {
            final lang = r[1];
            final list = Passages.byLang(lang);
            final passage = list.isEmpty ? Passages.all.first : list.first;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: IosCard(
                onTap: () => Navigator.of(context).push(CupertinoPageRoute(
                  builder: (_) => LiveRoomScreen(store: store, roomName: r[0], passage: passage),
                )),
                child: Row(children: [
                  const Icon(CupertinoIcons.dot_radiowaves_left_right, color: AppColors.pink),
                  const SizedBox(width: 12),
                  Expanded(child: Text(r[0], style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16))),
                  const Icon(CupertinoIcons.chevron_right, size: 16, color: AppColors.tertiaryLabel),
                ]),
              ),
            );
          }),
        ])),
      ),
    ]);
  }
}
