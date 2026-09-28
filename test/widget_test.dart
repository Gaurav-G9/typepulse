import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:typepulse/data/ar_api.dart';
import 'package:typepulse/data/store.dart';
import 'package:typepulse/main.dart';

import 'test_support.dart';

void main() {
  testWidgets('first launch shows welcome + sign-in, no data', (tester) async {
    phoneSize(tester);
    resetStorage();
    final store = fakeStore();
    await tester.pumpWidget(TypePulseApp(store: store));
    await settle(tester);

    expect(find.text('Welcome to TypePulse'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
    // No tabs, no numbers, nothing invented.
    expect(find.text('Summary'), findsNothing);
    expect(find.textContaining('wpm'), findsNothing);
    expect(store.results, isEmpty);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('wrong password shows the AR error; right one opens the app',
      (tester) async {
    phoneSize(tester);
    resetStorage();
    final store = fakeStore();
    await tester.pumpWidget(TypePulseApp(store: store));
    await settle(tester);

    final fields = find.byType(CupertinoTextField);
    await tester.enterText(fields.at(0), 'a@x.com');
    await tester.enterText(fields.at(1), 'nope');
    await tester.tap(find.text('Sign in'));
    await settle(tester);
    expect(find.textContaining('Invalid email or password'), findsOneWidget);

    await tester.enterText(fields.at(1), 'secret');
    await tester.tap(find.text('Sign in'));
    await settle(tester);
    expect(find.text('Summary'), findsWidgets);
    expect(find.text('1234', findRichText: true),
        findsOneWidget); // Total Tests Attempted
    expect(find.text('41.26 wpm', findRichText: true),
        findsOneWidget); // Avg. Gross Speed
    expect(find.text('Hi, Asha Verma'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('session ended elsewhere → welcome explains why', (tester) async {
    phoneSize(tester);
    resetStorage(signedIn: true);
    var kicked = false;
    final store = AppStore(
      api: ArTypingApi(
        httpClient: MockClient((req) async {
          if (kicked) {
            if (req.url.path.endsWith('/jwt/refresh/')) {
              return http.Response('{"detail":"Token is invalid"}', 401);
            }
            return http.Response('{"detail":"expired"}', 401);
          }
          return fakeArTyping().send(req).then(http.Response.fromStream);
        }),
      ),
    );
    await tester.pumpWidget(TypePulseApp(store: store));
    await settle(tester);
    expect(find.text('Summary'), findsWidgets);

    kicked = true; // user signs in on another device
    await tester.runAsync(() => store.syncNow(quiet: true));
    await settle(tester);
    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.textContaining('another device'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
