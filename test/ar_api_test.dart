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

    ArTypingApi insightApi(Future<http.Response> Function(int call) respond,
        {Duration timeout = const Duration(seconds: 60)}) {
      var calls = 0;
      return ArTypingApi(
        insightTimeout: timeout,
        httpClient: MockClient((req) => respond(++calls)),
      )
        ..accountId = 'me'
        ..accessToken = 'tok';
    }

    test('typing-progress: slow first response is retried', () async {
      var calls = 0;
      final api = insightApi((n) async {
        calls = n;
        if (n == 1) await Future<void>.delayed(const Duration(seconds: 1));
        return json({'passage_count': 3, 'avg_gross_speed': 40});
      }, timeout: const Duration(milliseconds: 200));
      final body = await api.fetchTypingProgress(30);
      expect(body?['passage_count'], 3);
      expect(calls, 2);
    });

    test('typing-progress: 503 (dyno waking) is retried once', () async {
      final api = insightApi((n) async => n == 1
          ? http.Response('Application error', 503)
          : json({'passage_count': 1}));
      expect((await api.fetchTypingProgress(7))?['passage_count'], 1);
    });

    test('typing-progress: repeated timeouts give a clear message', () async {
      final api = insightApi((n) async {
        await Future<void>.delayed(const Duration(seconds: 1));
        return json({});
      }, timeout: const Duration(milliseconds: 100));
      await expectLater(
        api.fetchTypingProgress(30),
        throwsA(isA<ArApiException>().having(
            (e) => e.message, 'message', contains('took too long'))),
      );
    });

    test('typing-progress: 403 shows the server reason', () async {
      final api = insightApi((n) async =>
          json({'detail': 'Subscribe to view typing insights.'}, 403));
      await expectLater(
        api.fetchTypingProgress(7),
        throwsA(isA<ArApiException>().having((e) => e.message, 'message',
            'Subscribe to view typing insights.')),
      );
    });

    test('typing-progress: 200 with only a message means no activity',
        () async {
      final api = insightApi(
          (n) async => json({'message': 'No typing data found.'}));
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
