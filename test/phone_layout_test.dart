import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:typepulse/data/store.dart';
import 'package:typepulse/main.dart';
import 'package:typepulse/screens/history_screen.dart';
import 'package:typepulse/screens/practice_screen.dart';
import 'package:typepulse/theme/app_colors.dart';

void phone(WidgetTester tester, double width) {
  tester.view.physicalSize = Size(width, 780);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  for (final w in [360.0, 390.0]) {
    testWidgets('all tabs fit at ${w}px and back-navigation works',
        (tester) async {
      phone(tester, w);
      SharedPreferences.setMockInitialValues({
        'tp_accounts': jsonEncode([
          {
            'id': 'a@x.com',
            'email': 'a.very.long.email.address@example.com',
            'displayName': 'a'
          },
          {'id': 'b@x.com', 'email': 'b@x.com', 'displayName': 'b'},
        ]),
        'tp_active_account_id': 'a@x.com',
      });
      FlutterSecureStorage.setMockInitialValues({});
      await tester.pumpWidget(const TypePulseApp());
      await tester.pumpAndSettle();
      for (final tab in ['Live', 'Ranks', 'You', 'Summary']) {
        await tester.tap(find.text(tab).last);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: tab);
      }

      // Push + pop animates the nav-bar title into the back button; this
      // threw "Failed to interpolate TextStyles" with the old theme.
      await tester.scrollUntilVisible(find.text('Show More').hitTestable(), 60,
          scrollable: find.byType(Scrollable).first);
      await tester.tap(find.text('Show More'));
      await tester.pumpAndSettle();
      expect(find.text('No workouts in this filter'), findsNothing);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('pushed screens fit at ${w}px', (tester) async {
      phone(tester, w);
      SharedPreferences.setMockInitialValues({});
      FlutterSecureStorage.setMockInitialValues({});
      final store = (await tester.runAsync(() async {
        final s = AppStore();
        await s.load();
        s.stopAutoSync();
        return s;
      }))!;
      for (final page in <Widget>[
        HistoryScreen(store: store),
        PracticeScreen(store: store),
      ]) {
        await tester.pumpWidget(
            CupertinoApp(theme: AppColors.cupertinoTheme(), home: page));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '${page.runtimeType}');
      }
      await tester.pumpWidget(const SizedBox());
      store.dispose();
    });
  }
}
