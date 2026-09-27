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
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Color(0x00000000),
    statusBarIconBrightness: Brightness.dark,
  ));
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
    store.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    store.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoApp(
      title: 'TypePulse',
      debugShowCheckedModeBanner: false,
      theme: const CupertinoThemeData(
        brightness: Brightness.light,
        primaryColor: AppColors.indigo,
        scaffoldBackgroundColor: AppColors.canvas,
        barBackgroundColor: AppColors.navBar,
        textTheme: CupertinoTextThemeData(
          textStyle: TextStyle(
            fontFamily: '.SF Pro Text',
            color: AppColors.label,
            fontSize: 16,
          ),
        ),
      ),
      home: store.loaded
          ? RootTabs(store: store)
          : const CupertinoPageScaffold(
              backgroundColor: AppColors.background,
              child: Center(child: CupertinoActivityIndicator()),
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
        backgroundColor: const Color(0xF0F9F9F9),
        activeColor: AppColors.indigo,
        inactiveColor: AppColors.secondaryLabel,
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
            return CupertinoTabView(
              builder: (_) => LiveLobbyScreen(store: store),
            );
          case 2:
            return CupertinoTabView(
              builder: (_) => LeaderboardScreen(store: store),
            );
          case 3:
            return CupertinoTabView(
              builder: (_) => ProfileScreen(store: store),
            );
          default:
            return CupertinoTabView(
              builder: (_) => HomeScreen(
                store: store,
                onOpenLive: () {
                  Navigator.of(_).push(
                    CupertinoPageRoute(
                      builder: (ctx) => LiveLobbyScreen(store: store),
                    ),
                  );
                },
              ),
            );
        }
      },
    );
  }
}
