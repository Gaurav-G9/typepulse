import 'package:flutter/cupertino.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:typepulse/data/passages.dart';
import 'package:typepulse/data/store.dart';
import 'package:typepulse/main.dart';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:typepulse/data/ar_api.dart';
import 'package:typepulse/screens/account_switcher.dart';
import 'package:typepulse/screens/insight_screen.dart';
import 'package:typepulse/screens/session_detail_screen.dart';
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

  group('phone-sized screens', () {
    void phone(WidgetTester tester) {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
    }

    Future<AppStore> signedIn() async {
      SharedPreferences.setMockInitialValues({
        'tp_accounts': jsonEncode([
          {'id': 'a@x.com', 'email': 'a@x.com', 'displayName': 'a'}
        ]),
        'tp_active_account_id': 'a@x.com',
      });
      FlutterSecureStorage.setMockInitialValues({
        'ar_access_a@x.com': 'tok',
        'ar_refresh_a@x.com': 'r',
      });
      final client = MockClient((req) async {
        final body = req.url.path.endsWith('/typing-progress/')
            ? {
                'passage_count': 12,
                'min_achieved_count': 8,
                'avg_gross_speed': 41.25,
                'avg_net_speed': 39.8,
                'best_gross_speed_data': {
                  'gross_speed': 48.2,
                  'corresponding_net_speed': 47.1
                },
                'best_net_speed_data': {
                  'net_speed': 47.5,
                  'corresponding_gross_speed': 48.0
                },
                'best_gross_speed_list': List.generate(30, (i) => 35.0 + i % 9),
                'best_net_speed_list': List.generate(30, (i) => 33.0 + i % 7),
                'min_achieved_count_list': List.generate(30, (i) => i % 4),
                'exam_title':
                    'UPSSSC Assistant English Typing Test With A Very Long Name, SSC CHSL',
                'target_speed': '30,35',
                'time_duration': '10:00,15:00',
                'typing_dates': '2026-09-20,2026-09-21',
                'most_misspelled_words': {
                  for (var i = 0; i < 40; i++)
                    'misspeltword$i': {'correct': 'word$i', 'count': i}
                },
                'most_added_words': {'the': 4},
                'most_deleted_words': {},
              }
            : {'count': 0, 'next': null, 'results': []};
        return http.Response(jsonEncode(body), 200,
            headers: {'content-type': 'application/json'});
      });
      final store = AppStore(api: ArTypingApi(httpClient: client));
      await store.load();
      store.stopAutoSync();
      return store;
    }

    testWidgets('Typing Insight renders without overflow', (tester) async {
      phone(tester);
      final store = await tester.runAsync(signedIn);
      await tester.pumpWidget(CupertinoApp(home: InsightScreen(store: store!)));
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pumpAndSettle();
      expect(find.text('12'), findsOneWidget);
      expect(find.text('48.2 wpm'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Misspelled words'), 300);
      await tester.pumpAndSettle();
      expect(find.textContaining('misspeltword39 → word39'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      store.dispose();
    });

    testWidgets('Insight asks guests to sign in', (tester) async {
      phone(tester);
      final store = await tester.runAsync(guestStore);
      await tester.pumpWidget(CupertinoApp(home: InsightScreen(store: store!)));
      await tester.pumpAndSettle();
      expect(find.text('Sign in to AR Typing'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      store.dispose();
    });

    testWidgets('AR result detail shows official speeds and NA target',
        (tester) async {
      phone(tester);
      final store = await tester.runAsync(guestStore);
      final session = ArTypingApi.sessionFromRemote({
        'exam_title': 'UPSSSC Assistant English',
        'passage_title': 'Chronic Stress',
        'typing_date': '2026-09-20',
        'time_duration': '00:05:00',
        'time_taken': 5,
        'key_strokes_typed': 19,
        'target_speed': 0,
        'gross_speed': 40.4,
        'net_speed': 39.6,
        'passage_text': 'the quick brown fox',
        'typed_passage_text': 'the quick brwn fox',
      });
      await tester.pumpWidget(CupertinoApp(
          home: SessionDetailScreen(store: store!, session: session)));
      await tester.pumpAndSettle();
      expect(find.text('39.60'), findsOneWidget); // AR net, not recomputed
      expect(find.textContaining('Target speed: NA', findRichText: true),
          findsOneWidget);
      await tester.scrollUntilVisible(find.text('brwn ½'), 300);
      expect(find.text('brwn ½'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      store.dispose();
    });
  });
}
