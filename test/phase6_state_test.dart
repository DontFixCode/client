import 'dart:async';
import 'dart:convert';

import 'package:bus/data/bus_api.dart';
import 'package:bus/models/place.dart';
import 'package:bus/state/app_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

http.Response _json(Json data, [int status = 200]) => http.Response(
  jsonEncode(data),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);
http.Response _error(String code, int status) => _json({
  'error': {'code': code, 'message': code},
}, status);
Json _transfer({String? eventId}) => {
  'snapshotKey': 'fixed-transfer-1',
  'selectionVersion': 1,
  'transferIndex': 1,
  'frontLegIndex': 1,
  'nextLegIndex': 3,
  'result': eventId == null ? null : {'eventId': eventId, 'value': 'success'},
};
Json _journey(String id, {String status = 'active', int resultVersion = 0}) => {
  'journeyId': id,
  'lifecycleStatus': status,
  'stateVersion': 5,
  'resultVersion': resultVersion,
  'selectionVersion': 1,
  'currentProgress': {
    'completedBusLegs': [1],
  },
  'transferResults': [_transfer()],
};
BusApi _api(Future<http.Response> Function(http.Request) handler) =>
    BusApi(client: MockClient(handler), accessToken: () async => 'test-token');

void main() {
  test('종료된 기록의 응답 유실 재시도는 같은 키·본문·대상을 쓰며 활성 이동을 보존한다', () async {
    final requests = <http.Request>[];
    final oldJourney = _journey('ended', status: 'completed');
    final updated = {
      ...oldJourney,
      'transferResults': [_transfer(eventId: '11')],
    };
    final state = AppState(
      api: _api((request) async {
        expect(request.url.path, startsWith('/api/v1/journeys/ended'));
        if (request.method == 'POST') {
          requests.add(request);
          if (requests.length == 1) throw http.ClientException('response lost');
          return _json({
            'eventId': '11',
            'stateVersionAfter': 5,
            'replayed': true,
          });
        }
        return _json(updated);
      }),
    )..journey = _journey('current');
    addTearDown(state.dispose);

    await expectLater(
      state.submitTransferResult(oldJourney, _transfer(), result: 'success'),
      throwsA(isA<ApiException>()),
    );
    expect(state.pendingEventJourneyId, 'ended');
    await expectLater(
      state.sendJourneyEvent('board', {'legIndex': 3}),
      throwsA(
        isA<ApiException>().having((e) => e.code, 'code', 'EVENT_PENDING'),
      ),
    );
    expect(await state.retryPendingEvent(), updated);
    expect(requests[0].body, requests[1].body);
    expect(
      requests[0].headers['idempotency-key'],
      requests[1].headers['idempotency-key'],
    );
    expect(state.hasPendingEvent, isFalse);
    expect(state.journeyId, 'current');
  });

  test('환승 결과 수정은 최신 eventId를 쓰고 연결 정보 생략을 보존하며 최신 안내와 병합한다', () async {
    final requests = <Json>[];
    final before = _journey('current');
    final updated = {
      ...before,
      'transferResults': [_transfer(eventId: '13')],
    };
    final state =
        AppState(
            api: _api((request) async {
              if (request.method == 'POST') {
                requests.add(jsonDecode(request.body) as Json);
                return _json({
                  'eventId': '13',
                  'stateVersionAfter': 5,
                  'replayed': false,
                });
              }
              return _json(updated);
            }),
          )
          ..journey = {
            ...before,
            'resultVersion': 9,
            'guidance': {'baseStateVersion': 5},
          };
    addTearDown(state.dispose);

    await state.submitTransferResult(
      before,
      _transfer(eventId: '12'),
      result: 'failure',
    );
    expect(requests.single['eventType'], 'correction');
    expect(requests.single['payload'], {
      'supersedesEventId': '12',
      'result': 'failure',
    });
    expect(state.journey!['resultVersion'], 9);
    expect(state.journey!['transferResults'], updated['transferResults']);
    expect(state.guidance, isNotNull);
  });

  test('기록 삭제는 204를 처리하고 다른 기기에서 종료된 활성 캐시도 정리한다', () async {
    var status = 409;
    final state =
        AppState(
            api: _api((request) async {
              expect(request.method, 'DELETE');
              return status == 204
                  ? http.Response('', 204)
                  : _error('JOURNEY_ACTIVE', 409);
            }),
          )
          ..journey = _journey('current')
          ..serverHistory = [
            {'journeyId': 'current'},
            {'journeyId': 'other'},
          ]
          ..searchResult = {'searchId': 'old-search'};
    addTearDown(state.dispose);
    await expectLater(
      state.deleteJourneyRecord('current'),
      throwsA(isA<ApiException>()),
    );
    expect(state.serverHistory, hasLength(2));
    expect(state.journeyId, 'current');
    status = 204;
    await state.deleteJourneyRecord('current');
    expect(state.serverHistory, [
      {'journeyId': 'other'},
    ]);
    expect(state.journeyId, isNull);
    expect(state.searchResult, isNull);
  });

  test('이전 계정의 늦은 탈퇴 오류는 현재 계정 세션을 지우지 않는다', () async {
    var token = 'previous-account';
    final response = Completer<http.Response>();
    final started = Completer<void>();
    final api = BusApi(
      accessToken: () async => token,
      client: MockClient((_) {
        started.complete();
        return response.future;
      }),
    );
    final state = AppState(api: api)..userName = '새 계정';
    addTearDown(state.dispose);
    final request = api.request('GET', '/me');
    final assertion = expectLater(request, throwsA(isA<ApiException>()));
    await started.future;
    token = 'new-account';
    response.complete(_error('ACCOUNT_DELETED', 403));
    await assertion;
    expect(state.accountDeleted, isFalse);
    expect(state.isLoggedIn, isTrue);
  });

  test('현재 계정의 ACCOUNT_DELETED는 개인 상태를 비운다', () async {
    final state =
        AppState(api: _api((_) async => _error('ACCOUNT_DELETED', 403)))
          ..userName = '탈퇴 계정'
          ..journey = _journey('active')
          ..serverHistory = [
            {'journeyId': 'ended'},
          ]
          ..destination = const Place(id: 'saved', name: '저장 장소', address: '');
    addTearDown(state.dispose);
    await expectLater(
      state.api.request('GET', '/me'),
      throwsA(isA<ApiException>()),
    );
    expect(state.accountDeleted, isTrue);
    expect(state.isLoggedIn, isFalse);
    expect(state.journeyId, isNull);
    expect(state.serverHistory, isEmpty);
    expect(state.destination, isNull);
  });

  test('탈퇴 접수 pending도 Supabase 세션을 지우며 Auth 로그아웃 실패로 되돌리지 않는다', () async {
    const id = '11111111-1111-4111-8111-111111111111';
    final payload = base64Url
        .encode(
          utf8.encode(
            jsonEncode({
              'sub': id,
              'exp': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600,
            }),
          ),
        )
        .replaceAll('=', '');
    final logout = Completer<void>();
    final auth = SupabaseClient(
      'http://auth.test',
      'public-anon',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((request) async {
        if (request.url.path.endsWith('/logout')) {
          logout.complete();
          return _json({'message': 'unavailable'}, 503);
        }
        return _json({
          'access_token': 'e30.$payload.signature',
          'refresh_token': 'refresh',
          'token_type': 'bearer',
          'expires_in': 3600,
          'user': {
            'id': id,
            'aud': 'authenticated',
            'email': 'test@example.com',
            'created_at': DateTime.now().toUtc().toIso8601String(),
            'user_metadata': {},
            'app_metadata': {},
          },
        });
      }),
    );
    addTearDown(auth.dispose);
    await auth.auth.signInWithPassword(
      email: 'test@example.com',
      password: 'test-password',
    );
    final state = AppState(
      auth: auth,
      api: _api((request) async {
        expect(request.method, 'DELETE');
        expect(request.url.path, '/api/v1/me');
        return _json({
          'authBlockStatus': 'pending',
          'cancelledJourneyIds': ['active'],
        }, 202);
      }),
    )..userName = '테스트 계정';
    addTearDown(state.dispose);
    await state.deleteAccount();
    await logout.future;
    await Future<void>.delayed(Duration.zero);
    expect(auth.auth.currentSession, isNull);
    expect(state.accountDeleted, isTrue);
    expect(state.isLoggedIn, isFalse);
  });
}
