import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:typepulse/data/ar_api.dart';
import 'package:typepulse/data/store.dart';

http.Response json(Object body, [int status = 200]) =>
    http.Response(jsonEncode(body), status,
        headers: {'content-type': 'application/json'});

Map<String, dynamic> row(int id, String date,
        {Object? gross = 40, Object? net = 39}) =>
    {
      'id': id,
      'exam_title': 'UPSSSC Assistant English',
      'passage_title': 'Passage $id',
      'typing_date': date,
      'time_taken': 5,
      'key_strokes_typed': 1000,
      'target_speed': 30,
      'gross_speed': gross,
      'net_speed': net,
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late int historyCalls;
  late Completer<void>? gate;
  late List<Map<String, dynamic>> historyA;

  MockClient client() => MockClient((req) async {
        final path = req.url.path;
        final token = req.headers['Authorization'];
        if (path.endsWith('/jwt/create/')) {
          final body = jsonDecode(req.body) as Map<String, dynamic>;
          if (body['password'] != 'right') {
            return json({'detail': 'No active account found'}, 401);
          }
          return json({'access': 'tokA', 'refresh': 'rA'});
        }
        if (path.endsWith('/typedPassages/')) {
          historyCalls++;
          if (gate != null) await gate!.future;
          if (token == 'JWT tokA') {
            return json(
                {'count': historyA.length, 'next': null, 'results': historyA});
          }
          return json({'count': 0, 'next': null, 'results': []});
        }
        if (path.endsWith('/students/profile/')) {
          return json({'phone_number': '9999999999', 'city': 'Lucknow'});
        }
        if (path.endsWith('/users/me/')) {
          return json({
            'first_name': 'Asha',
            'last_name': 'Verma',
            'email': 'a@x.com',
            'is_subscribed': true,
            'days_remaining': 12,
            'expiration_date': '2026-10-10',
            'subscription_plan': {'name': 'Premium 3 Months'},
          });
        }
        if (path.endsWith('/memberTypingStats/')) {
          return json({
            'total_tests': 57,
            'avg_gross_speed': '40.50',
            'avg_net_speed': 39.25,
            'avg_accuracy_percentage': 97.5,
          });
        }
        return json({}, 404);
      });

  Future<AppStore> store({
    Map<String, Object> prefs = const {},
    Map<String, String> tokens = const {},
  }) async {
    SharedPreferences.setMockInitialValues(Map.of(prefs));
    FlutterSecureStorage.setMockInitialValues(Map.of(tokens));
    final s = AppStore(api: ArTypingApi(httpClient: client()));
    await s.load();
    s.stopAutoSync();
    return s;
  }

  final twoAccounts = {
    'tp_accounts': jsonEncode([
      {'id': 'a@x.com', 'email': 'a@x.com', 'displayName': 'a'},
      {'id': 'b@x.com', 'email': 'b@x.com', 'displayName': 'b'},
    ]),
    'tp_active_account_id': 'a@x.com',
  };
  const tokens = {
    'ar_access_a@x.com': 'tokA',
    'ar_refresh_a@x.com': 'rA',
    'ar_access_b@x.com': 'tokB',
    'ar_refresh_b@x.com': 'rB',
  };

  setUp(() {
    historyCalls = 0;
    gate = null;
    historyA = [row(2, '2026-09-21T10:00:00Z'), row(1, '2026-09-20T10:00:00Z')];
  });

  test('first launch: no data at all, login required', () async {
    final s = await store();
    expect(s.needsLogin, isTrue);
    expect(s.results, isEmpty);
    expect(s.memberStats, isNull);
    expect(s.displayName, isNull);
    s.dispose();
  });

  test('old sample/local data is purged on startup', () async {
    final s = await store(prefs: {
      'tp_sessions': '[{"id":"seed-1"}]',
      'tp_profile': '{"name":"Gaurav"}',
      'tp_sessions_a@x.com': '[]',
      'tp_profile_a@x.com': '{}',
    });
    final prefs = await SharedPreferences.getInstance();
    expect(
        prefs.getKeys().where(
            (k) => k.startsWith('tp_sessions') || k.startsWith('tp_profile')),
        isEmpty);
    expect(s.results, isEmpty);
    s.dispose();
  });

  test('login → real history, stats, profile and subscription', () async {
    final s = await store();
    expect(await s.login('a@x.com', 'wrong'), isFalse);
    expect(s.error, contains('Invalid email or password'));
    expect(s.needsLogin, isTrue);

    expect(await s.login('a@x.com', 'right'), isTrue, reason: s.error);
    expect(s.needsLogin, isFalse);
    expect(s.results.map((r) => r.id), ['ar-2', 'ar-1']);
    expect(s.totalTests, 57);
    expect(s.avgGross, 40.5);
    expect(s.avgNet, 39.25);
    expect(s.avgAccuracy, 97.5);
    expect(s.displayName, 'Asha Verma');
    expect(s.planName, 'Premium 3 Months');
    expect(s.daysRemaining, 12);
    expect(s.studentProfile?['city'], 'Lucknow');
    s.dispose();
  });

  test('graph uses the last results only and skips NA values', () async {
    historyA = [
      row(5, '2026-09-25T10:00:00Z', gross: 44, net: 43),
      row(4, '2026-09-24T10:00:00Z', gross: 42, net: 41),
      row(3, '2025-01-10', gross: 0, net: 0), // "See In Detail" → no data
      row(2, '2026-09-10T10:00:00Z', gross: 40, net: 39),
      row(1, '2026-09-01T10:00:00Z', gross: 38, net: 37),
    ];
    final s = await store(prefs: twoAccounts, tokens: tokens);
    await s.syncNow();
    final chart = s.lastResultsForChart(3);
    // Oldest → newest, three most recent results that have data.
    expect(chart.map((r) => r.id), ['ar-2', 'ar-4', 'ar-5']);
    expect(s.lastResultsForChart(30).any((r) => r.id == 'ar-3'), isFalse);
    s.dispose();
  });

  test('history persists as raw website rows and reloads', () async {
    final s = await store(prefs: twoAccounts, tokens: tokens);
    await s.syncNow();
    s.dispose();
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonDecode(prefs.getString('tp_history_a@x.com')!) as List;
    expect(raw.first['passage_title'], 'Passage 2');

    final again = AppStore(api: ArTypingApi(httpClient: client()));
    await again.load();
    again.stopAutoSync();
    expect(again.results.map((r) => r.id), ['ar-2', 'ar-1']);
    again.dispose();
  });

  test('concurrent syncs share one request', () async {
    gate = Completer<void>();
    final s = await store(prefs: twoAccounts, tokens: tokens);
    final a = s.manualRefresh();
    final b = s.syncNow();
    gate!.complete();
    await Future.wait([a, b]);
    expect(historyCalls, 1);
    s.dispose();
  });

  test('switching accounts mid-sync does not leak history', () async {
    gate = Completer<void>();
    final s = await store(prefs: twoAccounts, tokens: tokens);
    await s.switchAccount('b@x.com');
    gate!.complete();
    await s.syncNow();
    await pumpEventQueue();
    expect(s.activeAccountId, 'b@x.com');
    expect(s.results, isEmpty);
    s.dispose();
  });

  test('logout returns to the sign-in screen', () async {
    final s = await store(prefs: twoAccounts, tokens: tokens);
    expect(s.needsLogin, isFalse);
    await s.logout();
    expect(s.needsLogin, isTrue);
    s.dispose();
  });

  test('removing the last account clears everything', () async {
    final s = await store(prefs: {
      'tp_accounts': jsonEncode([
        {'id': 'a@x.com', 'email': 'a@x.com', 'displayName': 'a'}
      ]),
      'tp_active_account_id': 'a@x.com',
    }, tokens: tokens);
    await s.syncNow();
    await s.removeAccount('a@x.com');
    expect(s.needsLogin, isTrue);
    expect(s.results, isEmpty);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('tp_history_a@x.com'), isNull);
    s.dispose();
  });

  test('corrupt prefs do not block startup', () async {
    final s = await store(prefs: {
      'tp_accounts': '{not json',
      'tp_history_a@x.com': '[{"broken": ',
    });
    expect(s.loaded, isTrue);
    expect(s.needsLogin, isTrue);
    s.dispose();
  });
}
