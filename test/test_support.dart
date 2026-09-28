import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:typepulse/data/ar_api.dart';
import 'package:typepulse/data/store.dart';

/// Realistic AR Typing responses for widget tests.
MockClient fakeArTyping({int results = 12}) => MockClient((req) async {
      final path = req.url.path;
      Object body;
      var status = 200;
      if (path.endsWith('/jwt/create/')) {
        final b = jsonDecode(req.body) as Map<String, dynamic>;
        if (b['password'] == 'secret') {
          body = {'access': 'tok', 'refresh': 'ref'};
        } else {
          body = {'detail': 'No active account found'};
          status = 401;
        }
      } else if (path.endsWith('/typedPassages/')) {
        body = {
          'count': results,
          'next': null,
          'results': [
            for (var i = 0; i < results; i++)
              {
                'id': 1000 - i,
                'exam_title':
                    'UPSSSC Assistant English Typing Test With A Long Name',
                'passage_title': 'Passage number ${1000 - i}',
                'typing_date':
                    DateTime.utc(2026, 9, 27 - i, 10).toIso8601String(),
                'time_duration': '00:10:00',
                'time_taken': 9.5,
                'key_strokes_given': 2000,
                'key_strokes_typed': 1800 + i,
                'key_strokes_error': 12,
                'target_speed': i.isEven ? 30 : 0,
                'gross_speed': 36.5 + i,
                'net_speed': 35.25 + i,
                'qualified': i.isEven,
                'passage_text': 'the quick brown fox jumps',
                'typed_passage_text': 'the quick brwn fox',
              }
          ],
        };
      } else if (path.endsWith('/memberTypingStats/')) {
        body = {
          'total_tests': 1234,
          'avg_gross_speed': 41.26,
          'avg_net_speed': 39.8,
          'avg_accuracy_percentage': 97.45,
        };
      } else if (path.endsWith('/users/me/')) {
        body = {
          'first_name': 'Asha',
          'last_name': 'Verma',
          'email': 'asha.verma.long.address@example.com',
          'is_subscribed': true,
          'enrollment_date': '2026-07-01',
          'expiration_date': '2026-10-01',
          'days_remaining': 3,
          'subscription_plan': {'name': 'Premium Plan'},
        };
      } else if (path.endsWith('/students/profile/')) {
        body = {
          'phone_number': '9876543210',
          'date_of_birth': '2001-05-04',
          'city': 'Lucknow',
          'state': 'Uttar Pradesh',
          'address': '12 Long Street Name, Some Colony, Near The Big Market',
        };
      } else if (path.endsWith('/typing-progress/')) {
        body = {
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
          'exam_title': 'UPSSSC Assistant English Typing Test, SSC CHSL',
          'target_speed': '30,35',
          'time_duration': '10:00,15:00',
          'typing_dates': '2026-09-20,2026-09-21',
          'most_misspelled_words': {
            for (var i = 0; i < 40; i++)
              'misspeltword$i': {'correct': 'word$i', 'count': i}
          },
          'most_added_words': {'the': 4},
          'most_deleted_words': {},
        };
      } else {
        body = {};
        status = 404;
      }
      return http.Response(jsonEncode(body), status,
          headers: {'content-type': 'application/json'});
    });

void resetStorage({bool signedIn = false}) {
  SharedPreferences.setMockInitialValues(signedIn
      ? {
          'tp_accounts': jsonEncode([
            {'id': 'a@x.com', 'email': 'a@x.com', 'displayName': 'a'},
            {'id': 'b@x.com', 'email': 'b@x.com', 'displayName': 'b'},
          ]),
          'tp_active_account_id': 'a@x.com',
        }
      : {});
  FlutterSecureStorage.setMockInitialValues(signedIn
      ? <String, String>{
          'ar_access_a@x.com': 'tok',
          'ar_refresh_a@x.com': 'ref'
        }
      : <String, String>{});
}

AppStore fakeStore({int results = 12}) =>
    AppStore(api: ArTypingApi(httpClient: fakeArTyping(results: results)));

void phoneSize(WidgetTester tester, [double width = 390]) {
  tester.view.physicalSize = Size(width, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// Lets the mocked HTTP futures complete, then settles the UI.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump();
  }
  await tester.pumpAndSettle();
}
