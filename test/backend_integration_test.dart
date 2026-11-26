import 'dart:async';
import 'dart:convert';

import 'package:bus/data/bus_api.dart';
import 'package:bus/models/place.dart';
import 'package:bus/models/travel_route.dart';
import 'package:bus/state/app_state.dart';
import 'package:bus/ui/pages/journey/live_journey_guide.dart';
import 'package:bus/ui/pages/routes/route_detail_page.dart';
import 'package:bus/ui/pages/routes/route_results_page.dart';
import 'package:bus/ui/pages/search/place_search_page.dart';
import 'package:bus/ui/theme/app_theme.dart';
import 'package:bus/ui/widgets/route_timeline.dart';
import 'package:bus/ui/widgets/route_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _id = '11111111-1111-4111-8111-111111111111';
const _origin = Place(
  id: 'origin',
  name: '대전역',
  address: '',
  latitude: 36.3315,
  longitude: 127.4335,
);
const _destination = Place(
  id: 'destination',
  name: '대전시청',
  address: '',
  latitude: 36.3504,
  longitude: 127.3845,
);

Json _leg(int index, String routeId, String number, String from, String to) => {
  'legIndex': index,
  'kind': 'bus',
  'route': {'id': routeId, 'routeNo': number},
  'patternKey': 'P$index',
  'board': {
    'stopId': '${index * 10}',
    'name': from,
    'seq': 1,
    'directionCode': null,
  },
  'alight': {
    'stopId': '${index * 10 + 1}',
    'name': to,
    'seq': 5,
    'directionCode': null,
  },
  'vehicle': {'vehicleId': 'planned-vehicle'},
  'geometryStatus': 'unavailable',
};
Json _candidate() => {
  'candidateId': _id,
  'startable': true,
  'startMode': 'data_limited',
  'legs': [
    {
      'legIndex': 0,
      'kind': 'walk',
      'from': {'name': '대전역'},
      'to': {'name': 'A'},
      'status': 'available',
      'durationSeconds': 120,
    },
    _leg(1, '9007199254740993', '605', 'A', 'B'),
    {
      'legIndex': 2,
      'kind': 'walk',
      'from': {'name': 'B'},
      'to': {'name': 'C'},
      'status': 'same_stop',
      'durationSeconds': 0,
    },
    _leg(3, '2', '102', 'C', 'D'),
    {
      'legIndex': 4,
      'kind': 'walk',
      'from': {'name': 'D'},
      'to': {'name': 'E'},
      'status': 'available',
      'durationSeconds': 60,
    },
    _leg(5, '3', '104', 'E', 'F'),
    {
      'legIndex': 6,
      'kind': 'walk',
      'from': {'name': 'F'},
      'to': {'name': '대전시청'},
      'status': 'available',
      'durationSeconds': 180,
    },
  ],
  'evaluation': {
    'nominalTotalSeconds': null,
    'expectedTotalSeconds': null,
    'walkingSeconds': 360,
    'journeyProbability': null,
    'reasonCodes': ['eta_basis_unconfirmed'],
    'transfers': [
      {
        'transferIndex': 0,
        'frontLegIndex': 1,
        'nextLegIndex': 3,
        'slackSeconds': 120,
        'probability': 0.8,
        'reasonCodes': [],
      },
      {
        'transferIndex': 1,
        'frontLegIndex': 3,
        'nextLegIndex': 5,
        'slackSeconds': null,
        'probability': null,
        'reasonCodes': ['eta_basis_unconfirmed'],
      },
    ],
  },
};
Json _search() => {
  'searchId': _id,
  'status': 'data_limited',
  'expired': false,
  'expiresAt': DateTime.now()
      .add(const Duration(minutes: 10))
      .toUtc()
      .toIso8601String(),
  'origin': _origin.toJson(),
  'destination': _destination.toJson(),
  'candidates': [_candidate()],
};
Json _journey({int version = 1, String movement = 'walking', Json? progress}) =>
    {
      'journeyId': _id,
      'lifecycleStatus': 'active',
      'stateVersion': version,
      'resultVersion': 0,
      'selectionVersion': 1,
      'movementState': movement,
      'selectedRoute': {
        ..._candidate(),
        'searchId': _id,
        'origin': {'lat': 36.3315, 'lon': 127.4335, 'name': '대전역'},
        'destination': {'lat': 36.3504, 'lon': 127.3845, 'name': '대전시청'},
      },
      'currentProgress':
          progress ??
          {
            'legIndex': 0,
            'nextBusLegIndex': 1,
            'boarded': null,
            'completedBusLegs': [],
          },
      'guidance': null,
      'guidanceStatus': 'pending',
    };
http.Response _json(Json data, [int status = 200]) => http.Response(
  jsonEncode(data),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

class _Socket implements WebSocketChannel {
  final incoming = StreamController<dynamic>();
  final outgoing = <dynamic>[];
  late final _Sink output = _Sink(outgoing, () => incoming.close());
  @override
  Stream<dynamic> get stream => incoming.stream;
  @override
  WebSocketSink get sink => output;
  @override
  Future<void> get ready => Future<void>.value();
  @override
  int? get closeCode => null;
  @override
  String? get closeReason => null;
  @override
  String? get protocol => null;
  void emit(Json data) => incoming.add(jsonEncode(data));
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Sink implements WebSocketSink {
  _Sink(this.messages, this.onClose);
  final List<dynamic> messages;
  final Future<void> Function() onClose;
  @override
  void add(dynamic data) => messages.add(data);
  @override
  Future<void> close([int? code, String? reason]) async {
    unawaited(onClose());
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Api extends BusApi {
  _Api(Future<http.Response> Function(http.Request) handler)
    : super(
        client: MockClient(handler),
        accessToken: () async => 'test-access-token',
      );
  final sockets = <_Socket>[];
  @override
  WebSocketChannel connect(String journeyId) {
    final socket = _Socket();
    sockets.add(socket);
    return socket;
  }
}

Future<void> _show(WidgetTester tester, AppState state, Widget page) async {
  tester.view.physicalSize = const Size(360, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    AppScope(
      state: state,
      child: MaterialApp(theme: AppTheme.light, home: page),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  test('HTTP 인증·query 인코딩·bigint를 보존하고 503을 빈 결과로 바꾸지 않는다', () async {
    final api = BusApi(
      client: MockClient((req) async {
        expect(req.headers['authorization'], 'Bearer token');
        expect(req.url.queryParameters['q'], '대전 & 시청');
        return _json({
          'error': {
            'code': 'PLACES_NOT_CONFIGURED',
            'message': '장소 검색 제공처가 설정되지 않았습니다.',
          },
        }, 503);
      }),
      accessToken: () async => 'token',
    );
    addTearDown(api.close);
    expect(
      api.uri('/routes/9007199254740993').path,
      '/api/v1/routes/9007199254740993',
    );
    await expectLater(
      api.request('GET', '/places/search', query: {'q': '대전 & 시청'}),
      throwsA(
        isA<ApiException>()
            .having((e) => e.code, 'code', 'PLACES_NOT_CONFIGURED')
            .having((e) => e.status, 'status', 503),
      ),
    );
  });

  test('검색 202 접수 후 서버 결과의 null과 다중 환승을 보존한다', () async {
    final calls = <String>[];
    var reads = 0;
    final api = _Api((req) async {
      calls.add(req.method);
      if (req.method == 'POST') {
        final body = jsonDecode(req.body) as Json;
        expect(body['origin']['latitude'], 36.3315);
        expect(body.keys, containsAll(['origin', 'destination']));
        return _json({'searchId': _id, 'status': 'processing'}, 202);
      }
      if (++reads == 1) {
        return _json({..._search(), 'status': 'processing', 'candidates': []});
      }
      return _json(_search());
    });
    final state = AppState(api: api)
      ..setOrigin(_origin)
      ..setDestination(_destination);
    addTearDown(state.dispose);
    await state.searchRoutes();
    expect(calls, ['POST', 'GET', 'GET']);
    final route = state.routeOptions.single;
    expect(route.minutes, isNull);
    expect(route.waitMinutes, isNull);
    expect(route.walkMinutes, 6);
    expect(route.transfers, 2);
    expect(route.transferEvaluations[1]['probability'], isNull);
    expect(route.busLegs.first['route']['id'], '9007199254740993');
    expect(route.probability, isNull);
    expect(route.minutesLabel, '시간 확인 불가');
  });

  test('예상 경로 표시를 파싱·이동 복구하고 서버 추천 순서를 보존한다', () async {
    final candidate = _candidate();
    final leg = (candidate['legs'] as List)[1] as Json;
    leg['alightEta'] = {
      'etaSource': 'headway_estimate',
      'predictedArrivalAt': '2026-11-13T06:30:00Z',
      'vehicleId': null,
    };
    final journey = _journey();
    (journey['selectedRoute'] as Json)['legs'] = candidate['legs'];
    final state = AppState(api: _Api((_) async => _json(journey)))
      ..setOrigin(_origin)
      ..setDestination(_destination);
    addTearDown(state.dispose);
    state.searchResult = {
      ..._search(),
      'candidates': [
        {..._candidate(), 'candidateId': 'realtime'},
        {...candidate, 'candidateId': 'estimated'},
        {..._candidate(), 'candidateId': 'flag-only', 'estimated': true},
      ],
    };
    expect(state.routeOptions.map((r) => r.id), [
      'realtime',
      'estimated',
      'flag-only',
    ]);
    expect(state.routeOptions.map((r) => r.estimated), [false, true, true]);
    await state.restoreJourney(_id);
    expect(state.activeRoute!.estimated, isTrue);
    expect(state.activeRoute!.minutes, isNull);
    expect(state.activeRoute!.busLegs.first['alightEta']['vehicleId'], isNull);
  });

  testWidgets('예상 경로의 목록·상세·구간 안내에 ETA 출처와 기준시각을 표시한다', (tester) async {
    final candidate = _candidate()..['estimated'] = true;
    final leg = (candidate['legs'] as List)[1] as Json;
    leg['boardEta'] = {
      'predictedArrivalAt': '2026-11-13T06:10:00Z',
      'basisAt': '2026-11-13T06:00:00Z',
      'etaSource': 'headway_estimate',
    };
    leg['alightEta'] = {
      'predictedArrivalAt': '2026-11-13T06:30:00Z',
      'basisAt': null,
      'etaSource': 'leading_vehicle_gap',
    };
    final route = TravelRoute.fromJson(
      candidate,
      searchId: _id,
      origin: _origin,
      destination: _destination,
      recommendedId: _id,
    );
    final state = AppState(api: _Api((_) async => _json(_journey())));
    addTearDown(state.dispose);
    await _show(
      tester,
      state,
      Scaffold(
        body: SingleChildScrollView(
          child: RouteCard(route: route, onTap: () {}),
        ),
      ),
    );
    expect(find.text('배차간격 기반 예상'), findsOneWidget);
    expect(find.textContaining('아직 출발하지 않은 차량'), findsOneWidget);
    await _show(tester, state, RouteDetailPage(route: route));
    expect(find.text('배차간격 기반 예상'), findsOneWidget);
    expect(find.text('추천 경로'), findsOneWidget);
    expect(find.text('여유 있는 환승'), findsNothing);
    await tester.scrollUntilVisible(
      find.byType(RouteTimeline),
      200,
      scrollable: find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.textContaining('배차간격으로 예상한 시간'), findsOneWidget);
    expect(find.textContaining('앞차 기준으로 예상한 시간'), findsOneWidget);
    expect(find.textContaining('예측 기준: 확인 불가'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  test('응답 유실 후 동일 이벤트 키·본문을 재전송하고 차량을 임의 확정하지 않는다', () async {
    var data = _journey();
    final eventRequests = <http.Request>[];
    final api = _Api((req) async {
      if (req.method == 'POST' && req.url.path.endsWith('/events')) {
        eventRequests.add(req);
        if (eventRequests.length == 1) {
          throw http.ClientException('connection lost');
        }
        return _json({
          'eventId': '1',
          'stateVersionAfter': 2,
          'replayed': true,
        });
      }
      return _json(data, req.method == 'POST' ? 201 : 200);
    });
    final state = AppState(api: api);
    addTearDown(state.dispose);
    final route = TravelRoute.fromJson(
      _candidate(),
      searchId: _id,
      origin: _origin,
      destination: _destination,
    );
    await state.startJourney(route);
    expect(jsonDecode(api.sockets.last.outgoing.single as String), {
      'type': 'auth',
      'accessToken': 'test-access-token',
    });
    await expectLater(
      state.sendJourneyEvent('board', {
        'legIndex': 1,
        'routeId': '9007199254740993',
        'vehicleId': null,
      }),
      throwsA(isA<ApiException>()),
    );
    expect(state.hasPendingEvent, isTrue);
    data = _journey(
      version: 2,
      movement: 'onboard',
      progress: {
        'legIndex': 1,
        'nextBusLegIndex': null,
        'boarded': {
          'legIndex': 1,
          'routeId': '9007199254740993',
          'vehicleId': null,
          'eventId': '1',
        },
      },
    );
    await state.retryPendingEvent();
    expect(
      eventRequests[0].headers['idempotency-key'],
      eventRequests[1].headers['idempotency-key'],
    );
    expect(eventRequests[0].body, eventRequests[1].body);
    expect(
      (jsonDecode(eventRequests[1].body) as Json)['payload']['vehicleId'],
      isNull,
    );
    expect(state.hasPendingEvent, isFalse);
    expect(state.journey!['stateVersion'], 2);
  });

  test('상태 충돌은 최신 상태를 복구하고 오래된 스트림·잘못된 평가 버전을 적용하지 않는다', () async {
    final api = _Api((req) async {
      if (req.method == 'POST') {
        return _json({
          'error': {
            'code': 'STATE_VERSION_CONFLICT',
            'message': '최신 상태를 확인해 주세요.',
          },
        }, 409);
      }
      return _json(_journey(version: 3));
    });
    final state = AppState(api: api);
    addTearDown(state.dispose);
    await state.restoreJourney(_id);
    await expectLater(
      state.sendJourneyEvent('board', {'legIndex': 1}),
      throwsA(isA<ApiException>()),
    );
    expect(state.hasPendingEvent, isFalse);
    final socket = api.sockets.last;
    socket.emit({
      ..._journey(version: 2),
      'type': 'journey_state',
      'resultVersion': 99,
    });
    await Future<void>.delayed(Duration.zero);
    expect(state.journey!['stateVersion'], 3);
    socket.emit({
      ..._journey(version: 3),
      'type': 'journey_state',
      'resultVersion': 1,
      'guidance': {'baseStateVersion': 2},
    });
    await Future<void>.delayed(Duration.zero);
    expect(state.guidance, isNull);
    socket.emit({
      ..._journey(version: 3),
      'type': 'journey_state',
      'resultVersion': 2,
      'guidance': {
        'baseStateVersion': 3,
        'arrival': {'remainingSeconds': 600},
      },
    });
    await Future<void>.delayed(Duration.zero);
    expect(state.guidance!['arrival']['remainingSeconds'], 600);
  });

  test('Supabase 로그인·프로필 수정·로그아웃을 서버 계약에 연결한다', () async {
    final token =
        '${base64Url.encode(utf8.encode('{"alg":"HS256"}')).replaceAll('=', '')}.${base64Url.encode(utf8.encode(jsonEncode({'sub': _id, 'exp': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600}))).replaceAll('=', '')}.signature';
    final authRequests = <http.Request>[];
    final auth = SupabaseClient(
      'http://auth.test',
      'public-anon-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((req) async {
        authRequests.add(req);
        if (req.url.path.endsWith('/logout')) return _json({});
        return _json({
          'access_token': token,
          'refresh_token': 'test-refresh',
          'token_type': 'bearer',
          'expires_in': 3600,
          'user': {
            'id': _id,
            'aud': 'authenticated',
            'email': 'user@example.com',
            'user_metadata': {},
            'app_metadata': {},
            'created_at': DateTime.now().toUtc().toIso8601String(),
          },
        });
      }),
    );
    addTearDown(auth.dispose);
    var displayName = '서버 사용자';
    final api = BusApi(
      accessToken: () async => auth.auth.currentSession?.accessToken,
      client: MockClient((req) async {
        expect(req.headers['authorization'], 'Bearer $token');
        if (req.url.path.endsWith('/me')) {
          if (req.method == 'PATCH') {
            displayName =
                (jsonDecode(req.body) as Json)['displayName'] as String;
          }
          return _json({'userId': _id, 'displayName': displayName});
        }
        return _json({'items': [], 'nextCursor': null});
      }),
    );
    final state = AppState(auth: auth, api: api);
    addTearDown(state.dispose);
    await state.login('user@example.com', 'password123');
    expect(state.isLoggedIn, isTrue);
    expect(state.userName, '서버 사용자');
    expect(authRequests.first.url.queryParameters['grant_type'], 'password');
    await state.updateProfile(name: '수정 이름');
    expect(state.userName, '수정 이름');
    expect(displayName, '수정 이름');
    await state.signOut();
    expect(state.isLoggedIn, isFalse);
    expect(auth.auth.currentSession, isNull);
  });

  testWidgets('세 버스의 탑승·하차·완료를 서버 legIndex 순서대로 확인한다', (tester) async {
    var data = _journey();
    final events = <Json>[];
    final api = _Api((req) async {
      if (req.method == 'POST' && req.url.path.endsWith('/events')) {
        final body = jsonDecode(req.body) as Json;
        events.add(body);
        final payload = body['payload'] as Json;
        final version = (data['stateVersion'] as int) + 1;
        if (body['eventType'] == 'board') {
          expect(payload['vehicleId'], isNull);
          data = _journey(
            version: version,
            movement: 'onboard',
            progress: {
              'legIndex': payload['legIndex'],
              'nextBusLegIndex': null,
              'boarded': {
                ...payload,
                'eventId': '$version',
                'matchesPlannedRoute': true,
              },
            },
          );
        } else if (body['eventType'] == 'alight') {
          final index = payload['legIndex'] as int;
          data = _journey(
            version: version,
            movement: index == 5 ? 'walking' : 'transferring',
            progress: {
              'legIndex': index + 1,
              'boarded': null,
              'nextBusLegIndex': index == 5 ? null : index + 2,
            },
          );
        } else {
          data = {
            ...data,
            'stateVersion': version,
            'lifecycleStatus': 'completed',
          };
        }
        return _json({
          'eventId': '$version',
          'stateVersionAfter': version,
          'replayed': false,
        });
      }
      if (req.url.path.endsWith('/journeys')) {
        return _json({'items': [], 'nextCursor': null});
      }
      return _json(data);
    });
    final state = AppState(api: api);
    addTearDown(state.dispose);
    await state.restoreJourney(_id);
    await _show(tester, state, const LiveJourneyGuide());
    for (final index in [1, 3, 5]) {
      await tester.tap(find.widgetWithText(FilledButton, '버스에 탑승했어요'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('확인한 정보 저장'));
      await tester.pumpAndSettle();
      expect(state.progress['boarded']['legIndex'], index);
      await tester.tap(find.widgetWithText(FilledButton, '이 정류소에서 내렸어요'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('하차 확인'));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('목적지 도착 확인'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('도착 확인'));
    await tester.pumpAndSettle();
    expect(events.map((e) => e['eventType']), [
      'board',
      'alight',
      'board',
      'alight',
      'board',
      'alight',
      'completed',
    ]);
    expect(events.take(6).map((e) => e['payload']['legIndex']), [
      1,
      1,
      3,
      3,
      5,
      5,
    ]);
    expect(state.activeRoute, isNull);
    expect(state.journeyId, isNull);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('360px 실제 경로 상세와 안내는 다중 환승·자료 부족을 표시하고 예시 지도는 숨긴다', (
    tester,
  ) async {
    final api = _Api((req) async => _json(_journey()));
    final state = AppState(api: api);
    addTearDown(state.dispose);
    final route = TravelRoute.fromJson(
      _candidate(),
      searchId: _id,
      origin: _origin,
      destination: _destination,
    );
    await _show(tester, state, RouteDetailPage(route: route));
    expect(find.text('시간 확인 불가'), findsOneWidget);
    expect(find.text('경로 체험'), findsNothing);
    await tester.scrollUntilVisible(
      find.text('연결 버스별 환승 평가'),
      200,
      scrollable: find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.textContaining('2번째 환승'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await state.restoreJourney(_id);
    await _show(tester, state, const LiveJourneyGuide());
    expect(find.text('체험 안내'), findsNothing);
    expect(find.text('버스에 탑승했어요'), findsOneWidget);
    await tester.tap(find.text('버스에 탑승했어요'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('지금은 확인하기 어려워요'));
    await tester.pumpAndSettle();
    expect(state.journey!['movementState'], 'walking');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('장소 제공처 503과 경로 out_of_scope를 체험 결과로 대체하지 않는다', (tester) async {
    final api = _Api((req) async {
      if (req.url.path.endsWith('/places/search')) {
        return _json({
          'error': {
            'code': 'PLACES_NOT_CONFIGURED',
            'message': '장소 검색 제공처가 설정되지 않았습니다.',
          },
        }, 503);
      }
      if (req.method == 'POST') return _json({'searchId': _id}, 202);
      return _json({..._search(), 'status': 'out_of_scope', 'candidates': []});
    });
    final state = AppState(api: api)
      ..setOrigin(_origin)
      ..setDestination(_destination);
    addTearDown(state.dispose);
    await _show(tester, state, const PlaceSearchPage(isOrigin: false));
    await tester.enterText(find.byType(TextField), '대전시청');
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pumpAndSettle();
    expect(find.text('장소 검색을 사용할 수 없어요'), findsOneWidget);
    expect(
      find.text('장소 검색 서비스가 아직 준비되지 않았어요. 나중에 다시 시도해 주세요.'),
      findsOneWidget,
    );
    expect(find.textContaining('좌표'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await _show(tester, state, const RouteResultsPage());
    await tester.pumpAndSettle();
    expect(find.text('출발지 또는 도착지가 지원 구간 밖이에요.'), findsWidgets);
    expect(find.text('검색 결과와 안내를 확인해 주세요.'), findsOneWidget);
    expect(find.byType(RouteTimeline), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
}
