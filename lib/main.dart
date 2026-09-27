import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import 'data/store.dart';
import 'screens/home_screen.dart';
import 'screens/leaderboard_screen.dart';
import 'screens/live_screen.dart';
import 'screens/profile_screen.dart';
import 'theme/app_colors.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const TypePulseApp());
}

class TypePulseApp extends StatefulWidget {
  const TypePulseApp({super.key});

  @override
  State<TypePulseApp> createState() => _TypePulseAppState();
}

class _TypePulseAppState extends State<TypePulseApp> {
  final store = AppStore();

  @override
  void initState() {
    super.initState();
    store.load().then((_) {
      if (mounted) setState(() {});
    });
    store.addListener(_onStore);
  }

  void _onStore() {
    AppColors.dark = store.profile.darkMode;
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: const Color(0x00000000),
      statusBarIconBrightness: AppColors.dark ? Brightness.light : Brightness.dark,
      systemNavigationBarColor: AppColors.canvas,
      systemNavigationBarIconBrightness: AppColors.dark ? Brightness.light : Brightness.dark,
    ));
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    store.removeListener(_onStore);
    store.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    AppColors.dark = store.profile.darkMode;
    return CupertinoApp(
      title: 'TypePulse',
      debugShowCheckedModeBanner: false,
      theme: AppColors.cupertinoTheme(),
      home: store.loaded
          ? RootTabs(store: store)
          : CupertinoPageScaffold(
              backgroundColor: AppColors.background,
              child: const Center(child: CupertinoActivityIndicator()),
            ),
    );
  }
}

class RootTabs extends StatelessWidget {
  final AppStore store;
  const RootTabs({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    return CupertinoTabScaffold(
      tabBar: CupertinoTabBar(
        backgroundColor: AppColors.tabBar,
        activeColor: AppColors.indigo,
        inactiveColor: AppColors.secondaryLabel,
        border: Border(top: BorderSide(color: AppColors.separator, width: 0.5)),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.house),
            activeIcon: Icon(CupertinoIcons.house_fill),
            label: 'Summary',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.dot_radiowaves_left_right),
            label: 'Live',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.chart_bar),
            activeIcon: Icon(CupertinoIcons.chart_bar_fill),
            label: 'Ranks',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.person),
            activeIcon: Icon(CupertinoIcons.person_fill),
            label: 'You',
          ),
        ],
      ),
      tabBuilder: (context, index) {
        switch (index) {
          case 1:
            return CupertinoTabView(builder: (_) => LiveLobbyScreen(store: store));
          case 2:
            return CupertinoTabView(builder: (_) => LeaderboardScreen(store: store));
          case 3:
            return CupertinoTabView(builder: (_) => ProfileScreen(store: store));
          default:
            return CupertinoTabView(
              builder: (_) => HomeScreen(
                store: store,
                onOpenLive: () {
                  Navigator.of(_).push(
                    CupertinoPageRoute(builder: (ctx) => LiveLobbyScreen(store: store)),
                  );
                },
              ),
            );
        }
      },
    );
  }
}
