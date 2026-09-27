import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:typepulse/data/ar_api.dart';
import 'package:typepulse/data/store.dart';
import 'package:typepulse/models/session.dart';

TypingSession session(String id, DateTime at, {double net = 30}) =>
    AppStore.buildSession(
      allottedSec: 300,
      timeTakenSec: 300,
      language: 'en',
      mode: 'practice',
      examTitle: 'Exam',
      passageTitle: 'P',
      expected: 'a b c',
      typed: 'a b c',
      backspaceCount: 0,
      targetWpm: 30,
    ).copyForTest(id: id, startedAt: at, netWpm: net);

extension on TypingSession {
  TypingSession copyForTest(
      {required String id, required DateTime startedAt, double? netWpm}) {
    final j = toJson()
      ..['id'] = id
      ..['startedAt'] = startedAt.toIso8601String();
    if (netWpm != null) j['netWpm'] = netWpm;
    return TypingSession.fromJson(j);
  }
}

http.Response json(Object body, [int status = 200]) =>
    http.Response(jsonEncode(body), status,
        headers: {'content-type': 'application/json'});

Map<String, dynamic> row(int id, String day) => {
      'id': id,
      'exam_title': 'UPSSSC English',
      'passage_title': 'Passage $id',
      'created_at': '${day}T10:00:00Z',
      'time_taken': 5,
      'key_strokes_typed': 1000,
      'gross_speed': 40,
      'net_speed': 39,
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('aggregates', () {
    test('streak survives until the first test of today', () {
      final store = AppStore();
      final now = DateTime.now();
      DateTime daysAgo(int n) =>
          DateTime(now.year, now.month, now.day - n, 12);
      store.sessions = [
        session('a', daysAgo(1)),
        session('b', daysAgo(2)),
        session('c', daysAgo(4)),
      ];
      expect(store.streak, 2);
      store.sessions = [session('t', daysAgo(0)), ...store.sessions];
      expect(store.streak, 3);
      store.dispose();
    });

    test('lastNNetWpm buckets by calendar day, today last', () {
      final store = AppStore();
      final now = DateTime.now();
      store.sessions = [
        session('a', DateTime(now.year, now.month, now.day, 9), net: 41),
        session('b', DateTime(now.year, now.month, now.day - 6, 9), net: 33),
      ];
      final series = store.lastNNetWpm(7);
      expect(series.length, 7);
      expect(series.last, 41);
      expect(series.first, 33);
      store.dispose();
    });
  });

  group('AR sync', () {
    late int historyCalls;
    late Completer<void>? gate;

    MockClient client() => MockClient((req) async {
          final path = req.url.path;
          if (path.endsWith('/typedPassages/')) {
            historyCalls++;
            if (gate != null) await gate!.future;
            final token = req.headers['Authorization'];
            if (token == 'JWT tokA') {
              return json({
                'count': 2,
                'next': null,
                'results': [row(1, '2026-09-20'), row(2, '2026-09-21')],
              });
            }
            return json({'count': 0, 'next': null, 'results': []});
          }
          if (path.endsWith('/profile/')) return json({'full_name': 'Asha'});
          if (path.endsWith('/memberTypingStats/')) {
            return json({'total_tests': 2});
          }
          return json({}, 404);
        });

    Future<AppStore> loadedStore() async {
      SharedPreferences.setMockInitialValues({
        'tp_accounts': jsonEncode([
          {'id': 'a@x.com', 'email': 'a@x.com', 'displayName': 'a'},
          {'id': 'b@x.com', 'email': 'b@x.com', 'displayName': 'b'},
        ]),
        'tp_active_account_id': 'a@x.com',
      });
      FlutterSecureStorage.setMockInitialValues({
        'ar_access_a@x.com': 'tokA',
        'ar_refresh_a@x.com': 'rA',
        'ar_access_b@x.com': 'tokB',
        'ar_refresh_b@x.com': 'rB',
      });
      final store = AppStore(api: ArTypingApi(httpClient: client()));
      await store.load();
      return store;
    }

    setUp(() {
      historyCalls = 0;
      gate = null;
    });

    test('signed-in account shows real history, never sample data', () async {
      final store = await loadedStore();
      await store.syncArHistory();
      expect(store.sessions.map((s) => s.id), containsAll(['ar-1', 'ar-2']));
      expect(store.sessions.any((s) => s.id.startsWith('seed-')), isFalse);
      expect(store.profile.name, 'Asha');
      expect(store.remoteTotalTests, 2);
      store.dispose();
    });

    test('concurrent syncs share one request', () async {
      gate = Completer<void>();
      final store = await loadedStore(); // kicks off a quiet sync
      final manual = store.manualRefresh();
      final again = store.syncArHistory();
      gate!.complete();
      await Future.wait([manual, again]);
      expect(historyCalls, 1);
      store.dispose();
    });

    test('switching accounts mid-sync does not leak history', () async {
      gate = Completer<void>();
      final store = await loadedStore(); // A's sync is now blocked on gate
      await store.switchAccount('b@x.com');
      gate!.complete();
      await store.syncArHistory();
      await pumpEventQueue();
      expect(store.activeAccountId, 'b@x.com');
      expect(store.sessions.where((s) => s.id.startsWith('ar-')), isEmpty);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('tp_sessions_b@x.com') ?? '', isNot(contains('ar-1')));
      store.dispose();
    });

    test('local practice survives a sync', () async {
      final store = await loadedStore();
      await store.syncArHistory();
      final local = session('local-1', DateTime.now());
      await store.addSession(local);
      await store.syncArHistory();
      expect(store.sessions.map((s) => s.id), contains('local-1'));
      store.dispose();
    });
  });

  test('corrupt prefs fall back instead of hanging on the splash', () async {
    SharedPreferences.setMockInitialValues({
      'tp_accounts': '{not json',
      'tp_sessions': '[{"broken": true}]',
    });
    FlutterSecureStorage.setMockInitialValues({});
    final store = AppStore();
    await store.load();
    expect(store.loaded, isTrue);
    expect(store.sessions, isNotEmpty); // sample history for guests
    store.dispose();
  });
}
