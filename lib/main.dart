import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import 'data/store.dart';
import 'screens/history_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/summary_screen.dart';
import 'screens/welcome_screen.dart';
import 'services/background_bootstrap.dart';
import 'theme/app_colors.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await BackgroundBootstrap.init();
  } catch (_) {
    // Background plugins may fail on unsupported platforms; UI still works.
  }
  runApp(const TypePulseApp());
}

class TypePulseApp extends StatefulWidget {
  /// Injectable for tests; the app creates its own otherwise.
  final AppStore? store;
  const TypePulseApp({super.key, this.store});

  @override
  State<TypePulseApp> createState() => _TypePulseAppState();
}

class _TypePulseAppState extends State<TypePulseApp>
    with WidgetsBindingObserver {
  late final AppStore store = widget.store ?? AppStore();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    store.addListener(_onStore);
    store.load().whenComplete(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    store.onAppLifecycle(state);
  }

  void _onStore() {
    AppColors.dark = store.darkMode;
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: const Color(0x00000000),
      statusBarIconBrightness:
          store.darkMode ? Brightness.light : Brightness.dark,
      systemNavigationBarColor: AppColors.canvas,
      systemNavigationBarIconBrightness:
          store.darkMode ? Brightness.light : Brightness.dark,
    ));
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    store.removeListener(_onStore);
    store.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    AppColors.dark = store.darkMode;
    return CupertinoApp(
      title: 'TypePulse',
      debugShowCheckedModeBanner: false,
      theme: AppColors.cupertinoTheme(),
      home: !store.loaded
          ? CupertinoPageScaffold(
              backgroundColor: AppColors.canvas,
              child: const Center(child: CupertinoActivityIndicator()),
            )
          // First launch (or signed out): welcome + AR Typing sign-in.
          : store.needsLogin
              ? WelcomeScreen(store: store)
              : RootTabs(key: ValueKey(store.activeAccountId), store: store),
    );
  }
}

class RootTabs extends StatefulWidget {
  final AppStore store;
  const RootTabs({super.key, required this.store});

  @override
  State<RootTabs> createState() => _RootTabsState();
}

class _RootTabsState extends State<RootTabs> {
  final controller = CupertinoTabController();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    return CupertinoTabScaffold(
      controller: controller,
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
            icon: Icon(CupertinoIcons.list_bullet),
            label: 'History',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.person),
            activeIcon: Icon(CupertinoIcons.person_fill),
            label: 'You',
          ),
        ],
      ),
      tabBuilder: (context, index) {
        // A tab's root page is built once and cached by its Navigator, so it
        // must listen to the store itself to reflect syncs / theme changes.
        Widget listen(WidgetBuilder page) => CupertinoTabView(
              builder: (_) => ListenableBuilder(
                listenable: store,
                builder: (ctx, _) => page(ctx),
              ),
            );
        switch (index) {
          case 1:
            return listen((_) => HistoryScreen(store: store));
          case 2:
            return listen((_) => ProfileScreen(store: store));
          default:
            return listen((_) => SummaryScreen(
                  store: store,
                  onOpenHistory: () => controller.index = 1,
                ));
        }
      },
    );
  }
}
