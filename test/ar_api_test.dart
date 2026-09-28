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

  group('account', () {
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

    test('uses tokens a background isolate already refreshed', () async {
      var refreshCalls = 0;
      final client = MockClient((req) async {
        if (req.url.path.endsWith('/jwt/refresh/')) {
          refreshCalls++;
          return json({'detail': 'Token is blacklisted'}, 401);
        }
        return req.headers['Authorization'] == 'JWT fresh'
            ? json({'ok': true})
            : json({'detail': 'expired'}, 401);
      });
      // Background isolate rotated the tokens and saved them.
      FlutterSecureStorage.setMockInitialValues({
        'ar_access_me@x.com': 'fresh',
        'ar_refresh_me@x.com': 'r2',
      });
      final api = await signedIn(client); // still holds old/r1 in memory
      expect(await api.fetchProfile(), containsPair('ok', true));
      expect(refreshCalls, 0, reason: 'must not burn the stale refresh token');
      expect(api.accessToken, 'fresh');
      expect(api.refreshToken, 'r2');
    });

    test('signed in on another device → clear re-login request', () async {
      final client = MockClient((req) async {
        if (req.url.path.endsWith('/jwt/refresh/')) {
          return json({'access': 'new'}); // refresh "works"…
        }
        return json({'detail': 'expired'}, 401); // …but every token is refused
      });
      final api = await signedIn(client);
      await expectLater(
        api.fetchProfile(),
        throwsA(isA<ArApiException>()
            .having((e) => e.needsReauth, 'needsReauth', isTrue)
            .having((e) => e.message, 'message', contains('another device'))),
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
