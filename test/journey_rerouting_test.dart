import 'package:bus/data/bus_api.dart';
import 'package:bus/models/place.dart';
import 'package:bus/models/travel_route.dart';
import 'package:bus/state/app_state.dart';
import 'package:bus/ui/pages/search/place_search_page.dart';
import 'package:bus/ui/theme/app_theme.dart';
import 'package:bus/ui/widgets/journey_rerouting.dart';
import 'package:bus/ui/widgets/transfer_evaluation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _State extends AppState {
  _State() : super(api: BusApi(accessToken: () async => 'test'));
  Json? event;
  bool pending = false;

  @override
  bool get hasPendingEvent => pending;

  @override
  Future<void> sendJourneyEvent(String type, Json payload) async {
    event = {'eventType': type, 'payload': payload};
  }
}

_State _state({bool proposal = false}) {
  const place = Place(id: 'old', name: '대전역', address: '');
  final state = _State();
  state.activeRoute = TravelRoute.fromJson(
    {
      'candidateId': 'original',
      'legs': [
        {
          'legIndex': 1,
          'kind': 'bus',
          'route': {'id': '7', 'routeNo': '612'},
          'patternKey': 'pattern',
          'vehicle': {'vehicleId': '오래된 차량'},
        },
      ],
    },
    searchId: 'search',
    origin: place,
    destination: place,
  );
  state.journey = {
    'journeyId': 'journey',
    'lifecycleStatus': 'active',
    'stateVersion': 3,
    'selectionVersion': 2,
    'resultVersion': 4,
    'movementState': 'waiting',
    'currentProgress': {'nextBusLegIndex': 1, 'completedBusLegs': <int>[]},
    'guidance': {
      'baseStateVersion': 3,
      'nextBoarding': {
        'legIndex': 1,
        'routeId': '7',
        'patternKey': 'pattern',
        'vehicle': {'vehicleId': '대전75자1234'},
      },
    },
    if (proposal)
      'proposedRoute': <String, dynamic>{
        'candidateId': 'alternative',
        'proposalVersion': 2,
        'baseStateVersion': 3,
        'evaluatedAt': '2026-11-25T12:00:00Z',
        'rankingMode': 'nominal',
        'nominalTotalSeconds': 1200,
        'destination': {'name': '시청'},
        'changeDecision': {'improvementSeconds': 300},
        'legs': [
          {
            'kind': 'bus',
            'legIndex': 1,
            'routeNo': '605',
            'routeInternalId': 12,
            'board': {'name': '대전역'},
            'alight': {'name': '시청'},
          },
        ],
      },
  };
  return state;
}

Future<void> _show(WidgetTester tester, _State state) async {
  await tester.pumpWidget(
    AppScope(
      state: state,
      child: MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(
          body: SingleChildScrollView(child: JourneyRerouting()),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, String text) async {
  await tester.ensureVisible(find.text(text));
  await tester.tap(find.text(text));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('놓친 다음 버스 차량을 확인 후 전송하고 기존 경로를 유지한다', (tester) async {
    final state = _state();
    addTearDown(state.dispose);
    final original = state.activeRoute;
    await _show(tester, state);
    await _tap(tester, '버스를 놓쳤어요');
    expect(state.event, isNull);
    expect(find.textContaining('안내 차량 대전75자1234'), findsOneWidget);
    await _tap(tester, '놓침 확인');
    expect(state.event, {
      'eventType': 'missed_bus',
      'payload': {'legIndex': 1, 'vehicleId': '대전75자1234'},
    });
    expect(state.activeRoute, same(original));
  });

  testWidgets('오래된 안내 차량을 놓친 차량으로 사용하지 않는다', (tester) async {
    final state = _state();
    addTearDown(state.dispose);
    state.journey!['guidance']['baseStateVersion'] = 2;
    await _show(tester, state);
    await _tap(tester, '버스를 놓쳤어요');
    expect(find.textContaining('차량 번호를 확인하지 못했어요'), findsOneWidget);
    await _tap(tester, '놓침 확인');
    expect(state.event?['payload'], {'legIndex': 1, 'vehicleId': null});
  });

  testWidgets('놓침 확인 중 차량 번호 없는 예상 차량이 바뀌면 전송하지 않는다', (tester) async {
    final state = _state();
    addTearDown(state.dispose);
    state.journey!['guidance']['nextBoarding'] = <String, dynamic>{
      'legIndex': 1,
      'routeId': '7',
      'patternKey': 'pattern',
      'vehicle': {'vehicleId': null},
      'predictedArrivalAt': '2026-11-27T05:00:00Z',
    };
    await _show(tester, state);
    await _tap(tester, '버스를 놓쳤어요');
    state.journey!['guidance']['nextBoarding']['predictedArrivalAt'] =
        '2026-11-27T05:15:00Z';
    await _tap(tester, '놓침 확인');
    expect(state.event, isNull);
    expect(find.textContaining('안내가 갱신됐어요'), findsOneWidget);
  });

  testWidgets('제안 raw leg를 표시하고 proposalVersion으로 수락한다', (tester) async {
    final state = _state(proposal: true);
    addTearDown(state.dispose);
    final original = state.activeRoute;
    await _show(tester, state);
    expect(find.text('605번 · 대전역 → 시청'), findsOneWidget);
    expect(find.text('남은 예상 시간 20분'), findsOneWidget);
    expect(find.text('현재 경로보다 약 5분 단축 예상'), findsOneWidget);
    await _tap(tester, '제안 수락');
    expect(state.event, isNull);
    await _tap(tester, '경로 변경');
    expect(state.event, {
      'eventType': 'route_accepted',
      'payload': {'proposalVersion': 2},
    });
    expect(state.activeRoute, same(original));
  });

  testWidgets('탑승 중 놓침·수락을 막지만 거절은 허용한다', (tester) async {
    final state = _state(proposal: true);
    addTearDown(state.dispose);
    state.journey!['movementState'] = 'onboard';
    await _show(tester, state);
    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, '버스를 놓쳤어요'),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '제안 수락'))
          .onPressed,
      isNull,
    );
    await _tap(tester, '현재 경로 유지');
    await _tap(tester, '제안 거절');
    expect(state.event, {
      'eventType': 'route_rejected',
      'payload': {'proposalVersion': 2},
    });
  });

  testWidgets('전송 대기 중 모든 입력과 오래된 제안 응답을 막는다', (tester) async {
    final state = _state(proposal: true)..pending = true;
    addTearDown(state.dispose);
    await _show(tester, state);
    for (final button in tester.widgetList<ButtonStyleButton>(
      find.bySubtype<ButtonStyleButton>(),
    )) {
      expect(button.onPressed, isNull);
    }
    state.pending = false;
    state.journey!['proposedRoute']['baseStateVersion'] = 2;
    await _show(tester, state);
    expect(find.text('상태가 바뀌어 제안을 다시 확인하고 있어요.'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '제안 수락'))
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, '현재 경로 유지'))
          .onPressed,
      isNull,
    );
  });

  testWidgets('확인 중 같은 버전의 제안이 교체돼도 이전 제안을 전송하지 않는다', (tester) async {
    final state = _state(proposal: true);
    addTearDown(state.dispose);
    await _show(tester, state);
    await _tap(tester, '제안 수락');
    state.journey!['proposedRoute'] = <String, dynamic>{
      ...state.journey!['proposedRoute'],
      'candidateId': 'replacement',
    };
    await _tap(tester, '경로 변경');
    expect(state.event, isNull);
    expect(find.textContaining('안내가 갱신됐어요'), findsOneWidget);
  });

  testWidgets('목적지 검색 선택을 확인하고 Place payload만 전송한다', (tester) async {
    final state = _state();
    addTearDown(state.dispose);
    final original = state.activeRoute;
    const place = Place(
      id: 'new',
      name: '시청',
      address: '대전 서구',
      latitude: 36.35,
      longitude: 127.38,
      provider: 'kakao',
      externalId: 'place-2',
    );
    await _show(tester, state);
    await _tap(tester, '목적지 변경');
    expect(find.byType(PlaceSearchPage), findsOneWidget);
    Navigator.of(tester.element(find.byType(PlaceSearchPage))).pop(place);
    await tester.pumpAndSettle();
    expect(state.event, isNull);
    expect(find.textContaining('새 경로는 제안을 수락한 뒤 적용돼요'), findsOneWidget);
    await _tap(tester, '변경 요청');
    expect(state.event, {
      'eventType': 'destination_changed',
      'payload': place.toJson(),
    });
    expect(state.activeRoute, same(original));
  });

  testWidgets('놓침 재검색 중 출발 근거와 기존 다음 버스 안내 유지를 알린다', (tester) async {
    final state = _state();
    addTearDown(state.dispose);
    final original = state.activeRoute;
    state.journey!['guidance'].addAll({
      'alternativesReason': 'missed_bus_reroute_pending',
      'reroute': {
        'kind': 'missed_bus',
        'status': 'pending',
        'reason': 'missed_bus_reroute_pending',
        'origin': {'basis': 'missed_stop', 'lat': 36.33, 'lon': 127.43},
      },
    });
    await _show(tester, state);
    expect(find.text('놓친 버스의 승차 정류소에서 새 경로를 찾아요.'), findsOneWidget);
    expect(find.textContaining('기존 경로의 다음 버스 안내는 계속돼요'), findsOneWidget);
    expect(state.activeRoute, same(original));
    expect(state.event, isNull);
  });

  testWidgets('탑승 중 목적지 미리보기는 고정 구간을 빼고 하차 후 재검색을 알린다', (tester) async {
    final state = _state(proposal: true);
    addTearDown(state.dispose);
    state.journey!['movementState'] = 'onboard';
    state.journey!['guidance'].addAll({
      'alternativesReason': 'destination_reroute_preview_until_alight',
      'reroute': {
        'kind': 'destination',
        'status': 'ready',
        'origin': {'basis': 'planned_alight_stop'},
      },
    });
    final proposal = state.journey!['proposedRoute'] as Json;
    final next = {...(proposal['legs'] as List).single as Json, 'legIndex': 3};
    proposal.addAll({
      'acceptedProgress': {
        'completedBusLegs': [1],
        'nextBusLegIndex': 3,
      },
      'changeDecision': {
        'kind': 'destination',
        'reasonCodes': ['destination_changed_route_proposed'],
        'arrivalBasis': 'reroute_search_evaluation',
        'improvementSeconds': null,
      },
      'legs': [
        {
          'kind': 'bus',
          'legIndex': 1,
          'routeNo': '612',
          'board': {'name': '기존 승차'},
          'alight': {'name': '기존 하차'},
        },
        next,
      ],
    });
    await _show(tester, state);
    expect(find.text('하차 후 경로 미리보기'), findsOneWidget);
    expect(find.textContaining('실제 내린 정류소와 시각으로 다시 찾아요'), findsOneWidget);
    expect(find.text('605번 · 대전역 → 시청'), findsOneWidget);
    expect(find.textContaining('612번 · 기존 승차'), findsNothing);
    expect(find.text('재검색 당시의 도착 예상시각을 사용했어요.'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '제안 수락'))
          .onPressed,
      isNull,
    );
    expect(state.event, isNull);
  });

  testWidgets('시간 미확인 목적지 제안은 저장된 시간을 숨기고 수락은 허용한다', (tester) async {
    final state = _state(proposal: true);
    addTearDown(state.dispose);
    final proposal = state.journey!['proposedRoute'] as Json;
    proposal.addAll({
      'changeDecision': {
        'kind': 'destination',
        'arrivalBasis': null,
        'reasonCodes': ['destination_changed_route_proposed_time_unconfirmed'],
        'improvementSeconds': null,
      },
      'evaluation': {
        'times': {'plannedArrivalAt': '2026-11-25T12:20:00Z'},
      },
    });
    await _show(tester, state);
    expect(find.text('남은 예상 시간 확인 불가'), findsOneWidget);
    expect(find.text('남은 예상 시간 20분'), findsNothing);
    expect(find.textContaining('도착 예상 '), findsNothing);
    expect(find.textContaining('도착시각은 아직 확인하지 못했어요'), findsOneWidget);
    await _tap(tester, '제안 수락');
    await _tap(tester, '경로 변경');
    expect(state.event?['eventType'], 'route_accepted');
  });

  testWidgets('작은 도착시간 개선과 제안의 새 환승 평가를 표시한다', (tester) async {
    final state = _state(proposal: true);
    addTearDown(state.dispose);
    final transfer = <String, dynamic>{
      'transferIndex': 1,
      'probability': 0.5,
      'probabilitySource': 'slack_fallback',
      'probabilityRange': {'min': 0.3, 'max': 0.7},
      'slackSeconds': 120,
      'slackGrade': 'normal',
      'slackEstimated': true,
      'reason': ['transfer_probability_by_marginal_errors'],
    };
    state.journey!['proposedRoute']['changeDecision'] = {
      'kind': 'missed_bus',
      'improvementSeconds': 20,
      'reasonCodes': ['alternative_has_lower_comparable_cost'],
    };
    state.journey!['proposedRoute']['evaluation'] = {
      'transfers': [transfer],
    };
    await _show(tester, state);
    expect(find.text('현재 경로보다 약 20초 단축 예상'), findsOneWidget);
    expect(
      tester
          .widget<TransferEvaluation>(find.byType(TransferEvaluation))
          .transfer,
      same(transfer),
    );
  });
}
