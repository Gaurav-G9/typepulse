import 'package:flutter/cupertino.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:typepulse/data/passages.dart';
import 'package:typepulse/data/store.dart';
import 'package:typepulse/main.dart';
import 'package:typepulse/screens/account_switcher.dart';
import 'package:typepulse/screens/practice_screen.dart';

Future<AppStore> guestStore() async {
  SharedPreferences.setMockInitialValues({});
  FlutterSecureStorage.setMockInitialValues({});
  final store = AppStore();
  await store.load();
  store.stopAutoSync();
  return store;
}

void tallScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 5000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('app boots to the Summary tab', (tester) async {
    tallScreen(tester);
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    await tester.pumpWidget(const TypePulseApp());
    await tester.pumpAndSettle();
    expect(find.text('Summary'), findsWidgets);
    expect(find.text('Workouts'), findsOneWidget);
    await tester.pumpWidget(const SizedBox()); // dispose store timers
  });

  testWidgets('tab pages rebuild when the store changes', (tester) async {
    tallScreen(tester);
    final store = await tester.runAsync(guestStore);
    await tester.pumpWidget(CupertinoApp(home: RootTabs(store: store!)));
    await tester.pumpAndSettle();
    expect(find.text('Sign in to AR Typing first.'), findsNothing);

    await tester.runAsync(() => store.syncArHistory()); // sets arError
    await tester.pump();
    expect(find.text('Sign in to AR Typing first.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    store.dispose();
  });

  testWidgets('"Add account" from the switcher opens the login sheet',
      (tester) async {
    tallScreen(tester);
    final store = await tester.runAsync(guestStore);
    await tester.pumpWidget(CupertinoApp(
      home: Builder(
        builder: (context) => CupertinoButton(
          onPressed: () => showAccountSwitcher(context, store!),
          child: const Text('open'),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add account'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Connect AR Typing'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    store!.dispose();
  });

  testWidgets('tapping the practice field does not start the clock',
      (tester) async {
    tallScreen(tester);
    final store = await tester.runAsync(guestStore);
    await tester.pumpWidget(CupertinoApp(
      home: PracticeScreen(store: store!, forcedPassage: Passages.all.first),
    ));
    await tester.tap(find.byType(CupertinoTextField));
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('300s'), findsOneWidget);

    await tester.enterText(find.byType(CupertinoTextField), 'Over the');
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('298s'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    store.dispose();
  });
}
