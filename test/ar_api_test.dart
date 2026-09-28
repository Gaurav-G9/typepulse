import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:typepulse/data/ar_api.dart';

http.Response json(Object body, [int status = 200]) =>
    http.Response(jsonEncode(body), status,
        headers: {'content-type': 'application/json'});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  group('sessionFromRemote', () {
    test('parses Django decimal strings without throwing', () {
      final s = ArTypingApi.sessionFromRemote({
        'id': 7,
        'exam_title': 'UPSSSC Hindi',
        'created_at': '2026-09-20T10:00:00Z',
        'time_duration': '00:05:00.000',
        'time_taken': '4.5',
        'key_strokes_given': '1250',
        'key_strokes_typed': '900',
        'target_speed': '25',
        'gross_speed': '36.00',
        'net_speed': '35.20',
        'full_mistake': '1',
        'half_mistake': 2,
        'accuracy': '98.5',
        'qualified': 1,
      });
      expect(s.id, 'ar-7');
      expect(s.durationSec, 300);
      expect(s.timeTakenSec, 270);
      expect(s.typedChars, 900);
      expect(s.targetWpm, 25);
      expect(s.wpm, 36.0);
      expect(s.netWpm, 35.2);
      expect(s.fullMistakes, 1);
      expect(s.halfMistakes, 2);
      expect(s.accuracy, 98.5);
      expect(s.qualified, isTrue);
      expect(s.language, 'hi');
    });

    test('bare-number duration is seconds, as on the website', () {
      final a = ArTypingApi.sessionFromRemote(
          {'time_duration': '600', 'typing_date': '2026-01-01'});
      final b = ArTypingApi.sessionFromRemote(
          {'time_duration': 300, 'typing_date': '2026-01-02'});
      expect(a.durationSec, 600);
      expect(b.durationSec, 300);
      expect(a.id, isNot(b.id));
      expect(a.id, startsWith('ar-'));
    });

    test('maps a real member-area typing-history row', () {
      final row = {
        'exam_title': 'UPSSSC Assistant English',
        'exam_slug': 'upsssc-assistant',
        'passage_title': 'Chronic Stress',
        'typing_date': '2026-09-20T15:04:05Z',
        'time_duration': '00:05:00',
        'time_taken': 4.95,
        'key_strokes_given': 1500,
        'key_strokes_typed': 1000,
        'key_strokes_error': 20,
        'target_speed': 30,
        'gross_speed': 40.4,
        'net_speed': 39.6,
        'qualified': true,
        'back_space_count': 12,
        'passage_text': 'the quick brown fox',
        'typed_passage_text': 'the quick brwn fox',
      };
      final s = ArTypingApi.sessionFromRemote(row);
      expect(s.startedAt, DateTime.utc(2026, 9, 20, 15, 4, 5).toLocal());
      expect(s.examTitle, 'UPSSSC Assistant English');
      expect(s.durationSec, 300);
      expect(s.timeTakenSec, 297);
      expect(s.accuracy, closeTo(98, 1e-9)); // from key_strokes_error
      expect(s.errors, 20);
      expect(s.wpm, 40.4);
      expect(s.netWpm, 39.6);
      expect(s.qualified, isTrue);
      expect(s.targetWpm, 30);
      expect(s.expectedText, 'the quick brown fox');
      // Same row → same id on every sync (drives new-result notifications).
      expect(ArTypingApi.sessionFromRemote(row).id, s.id);
    });

    test('target 0 means NA and never counts as qualified', () {
      final s = ArTypingApi.sessionFromRemote({
        'typing_date': '2026-09-20',
        'target_speed': 0,
        'gross_speed': 20,
        'net_speed': 18,
        'key_strokes_typed': 500,
        'time_taken': 5,
      });
      expect(s.targetWpm, 0);
      expect(s.qualified, isFalse);
    });

    test('legacy rows with net 0 get net recalculated from the texts', () {
      final words = List.filled(100, 'word').join(' ');
      final s = ArTypingApi.sessionFromRemote({
        'typing_date': '2025-01-10',
        'time_taken': 2,
        'gross_speed': 50,
        'net_speed': 0,
        'key_strokes_typed': words.length,
        'passage_text': words,
        'typed_passage_text': words,
      });
      expect(s.netWpm, closeTo(words.length / 5 / 2, 1e-9));
      expect(s.formulaNote, contains('recalculated'));
    });

    test('Devanagari passage is detected as Hindi', () {
      final s = ArTypingApi.sessionFromRemote({
        'exam_title': 'UPSSSC Assistant',
        'typing_date': '2026-09-20',
        'passage_text': 'सुशासन तभी टिकता है',
      });
      expect(s.language, 'hi');
    });
  });

  group('insight + account', () {
    test('typing-progress 404 means no activity', () async {
      final api = ArTypingApi(
        httpClient: MockClient((req) async {
          expect(req.url.path, endsWith('/learning/typing-progress/'));
          expect(req.url.queryParameters['days'], '7');
          return json({'detail': 'Not found.'}, 404);
        }),
      )
        ..accountId = 'me'
        ..accessToken = 'tok';
      expect(await api.fetchTypingProgress(7), isNull);
    });

    test('users/me is fetched with the JWT header', () async {
      final api = ArTypingApi(
        httpClient: MockClient((req) async {
          expect(req.headers['Authorization'], 'JWT tok');
          return json({
            'first_name': 'Asha',
            'is_subscribed': false,
          });
        }),
      )
        ..accountId = 'me'
        ..accessToken = 'tok';
      final me = await api.fetchMe();
      expect(me?['is_subscribed'], isFalse);
    });
  });

  group('auth + paging', () {
    Future<ArTypingApi> signedIn(MockClient client) async {
      final api = ArTypingApi(httpClient: client);
      api.accountId = 'me@x.com';
      api.accessToken = 'old';
      api.refreshToken = 'r1';
      return api;
    }

    test('parallel 401s share a single token refresh', () async {
      var refreshCalls = 0;
      final client = MockClient((req) async {
        if (req.url.path.endsWith('/jwt/refresh/')) {
          refreshCalls++;
          await Future<void>.delayed(const Duration(milliseconds: 20));
          return json({'access': 'new', 'refresh': 'r2'});
        }
        if (req.headers['Authorization'] != 'JWT new') {
          return json({'detail': 'expired'}, 401);
        }
        return json({'ok': true});
      });
      final api = await signedIn(client);
      final results = await Future.wait([
        api.fetchProfile(),
        api.fetchMemberStats(),
      ]);
      expect(refreshCalls, 1);
      expect(results, everyElement(containsPair('ok', true)));
      expect(api.refreshToken, 'r2', reason: 'rotated refresh token stored');
    });

    test('transient refresh failure keeps the session', () async {
      final client = MockClient((req) async {
        if (req.url.path.endsWith('/jwt/refresh/')) {
          return http.Response('Application error', 503);
        }
        return json({'detail': 'expired'}, 401);
      });
      final api = await signedIn(client);
      await expectLater(
        api.fetchProfile(),
        throwsA(isA<ArApiException>()
            .having((e) => e.needsReauth, 'needsReauth', isFalse)),
      );
      expect(api.isLoggedIn, isTrue);
      expect(api.refreshToken, 'r1');
    });

    test('rejected refresh clears the session and asks to re-auth', () async {
      final client = MockClient((req) async {
        if (req.url.path.endsWith('/jwt/refresh/')) {
          return json({'detail': 'Token is blacklisted'}, 401);
        }
        return json({'detail': 'expired'}, 401);
      });
      final api = await signedIn(client);
      await expectLater(
        api.fetchProfile(),
        throwsA(isA<ArApiException>()
            .having((e) => e.needsReauth, 'needsReauth', isTrue)),
      );
      expect(api.isLoggedIn, isFalse);
    });

    test('follows http:// next links over https', () async {
      final seen = <Uri>[];
      final client = MockClient((req) async {
        seen.add(req.url);
        if (req.url.queryParameters['page'] == '2') {
          return json({
            'count': 2,
            'next': null,
            'results': [
              {'id': 2}
            ],
          });
        }
        return json({
          'count': 2,
          'next':
              'http://artypingplatform-efb5438ddb1b.herokuapp.com/api/v1/learning/typedPassages/?page=2&page_size=1',
          'results': [
            {'id': 1}
          ],
        });
      });
      final api = await signedIn(client);
      final all = await api.fetchAllHistory(pageSize: 1);
      expect(all.map((e) => e['id']), [1, 2]);
      expect(seen.every((u) => u.scheme == 'https'), isTrue);
    });
  });
}
