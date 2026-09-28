import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:typepulse/data/ar_api.dart';
import 'package:typepulse/data/store.dart';
import 'package:typepulse/main.dart';
import 'package:typepulse/models/ar_result.dart';
import 'package:typepulse/screens/insight_screen.dart';
import 'package:typepulse/screens/result_detail_screen.dart';
import 'package:typepulse/theme/app_colors.dart';

import 'test_support.dart';

void main() {
  for (final width in [360.0, 390.0]) {
    testWidgets('all tabs render real data without overflow at ${width}px',
        (tester) async {
      phoneSize(tester, width);
      resetStorage(signedIn: true);
      await tester.pumpWidget(TypePulseApp(store: fakeStore()));
      await settle(tester);

      for (final tab in ['History', 'Insight', 'You', 'Summary']) {
        await tester.tap(find.text(tab).last);
        await settle(tester);
        expect(tester.takeException(), isNull, reason: tab);
      }
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('History lists every synced result and searches', (tester) async {
    phoneSize(tester);
    resetStorage(signedIn: true);
    await tester.pumpWidget(TypePulseApp(store: fakeStore(results: 12)));
    await settle(tester);
    await tester.tap(find.text('History').last);
    await settle(tester);
    expect(find.text('12 results'), findsOneWidget);
    await tester.enterText(find.byType(CupertinoSearchTextField), '995');
    await settle(tester);
    expect(find.text('1 of 12'), findsOneWidget);
    expect(find.text('Passage number 995'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('You shows the website profile and subscription', (tester) async {
    phoneSize(tester);
    resetStorage(signedIn: true);
    await tester.pumpWidget(TypePulseApp(store: fakeStore()));
    await settle(tester);
    await tester.tap(find.text('You').last);
    await settle(tester);
    expect(find.text('Asha Verma'), findsOneWidget);
    expect(find.text('Premium Plan'), findsOneWidget);
    expect(find.text('About to end'), findsOneWidget); // 3 days remaining
    expect(find.text('Lucknow, Uttar Pradesh'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('opening a result and going back works (nav-bar animation)',
      (tester) async {
    phoneSize(tester);
    resetStorage(signedIn: true);
    await tester.pumpWidget(TypePulseApp(store: fakeStore()));
    await settle(tester);
    await tester.tap(find.text('History').last);
    await settle(tester);
    await tester.tap(find.text('Passage number 1000'));
    await settle(tester);
    expect(find.text('Detailed comparison'), findsOneWidget);
    await tester.pageBack();
    await settle(tester);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('result detail shows NA and the word comparison', (tester) async {
    phoneSize(tester);
    resetStorage(signedIn: true);
    final store = fakeStore();
    final r = ArResult.fromRow({
      'exam_title': 'UPSSSC',
      'passage_title': 'Chronic Stress',
      'typing_date': '2026-09-20',
      'time_taken': 5,
      'key_strokes_typed': 19,
      'target_speed': 0,
      'gross_speed': 40.4,
      'net_speed': 39.6,
      'passage_text': 'the quick brown fox',
      'typed_passage_text': 'the quick brwn fox',
    });
    await tester.pumpWidget(CupertinoApp(
        theme: AppColors.cupertinoTheme(),
        home: ResultDetailScreen(store: store, result: r)));
    await settle(tester);
    expect(find.text('NA'), findsOneWidget); // target speed
    expect(find.text('39.60 wpm'), findsOneWidget);
    expect(find.text('brwn → brown'), findsOneWidget);
    expect(find.text('1 wrong'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Typing Insight renders website data', (tester) async {
    phoneSize(tester, 360);
    resetStorage(signedIn: true);
    final store = fakeStore();
    await tester.runAsync(store.load);
    store.stopAutoSync();
    await tester.pumpWidget(CupertinoApp(
        theme: AppColors.cupertinoTheme(), home: InsightScreen(store: store)));
    await settle(tester);
    expect(find.text('48.2 wpm'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Misspelled words'), 300);
    expect(find.textContaining('misspeltword39 → word39'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    store.dispose();
  });

  testWidgets('Insight: empty interval offers wider ones, error offers retry',
      (tester) async {
    phoneSize(tester);
    resetStorage(signedIn: true);
    var mode = 'empty';
    final api = ArTypingApi(
      httpClient: MockClient((req) async {
        if (!req.url.path.endsWith('/typing-progress/')) {
          return http.Response('{"count":0,"next":null,"results":[]}', 200);
        }
        final days = req.url.queryParameters['days'];
        if (mode == 'error') {
          return http.Response('{"detail":"Server exploded"}', 400);
        }
        return days == '30'
            ? http.Response('{"passage_count": 9, "avg_gross_speed": 40}', 200)
            : http.Response('{"detail":"Not found."}', 404);
      }),
    );
    final store = AppStore(api: api);
    await tester.runAsync(store.load);
    store.stopAutoSync();
    await tester.pumpWidget(CupertinoApp(
        theme: AppColors.cupertinoTheme(), home: InsightScreen(store: store)));
    await settle(tester);
    expect(find.textContaining('no typing activity for the last 7 days'),
        findsOneWidget);
    await tester.tap(find.text('Show last 30 days'));
    await settle(tester);
    expect(find.text('9'), findsOneWidget); // Typed passages

    mode = 'error';
    await tester.tap(find.text('15 days'));
    await settle(tester);
    expect(find.textContaining('Server exploded'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    mode = 'empty';
    await tester.tap(find.text('Try again'));
    await settle(tester);
    expect(find.textContaining('no typing activity for the last 15 days'),
        findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    store.dispose();
  });
}
