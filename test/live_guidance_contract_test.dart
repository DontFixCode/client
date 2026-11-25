import 'package:bus/data/bus_api.dart';
import 'package:bus/models/place.dart';
import 'package:bus/models/travel_route.dart';
import 'package:bus/state/app_state.dart';
import 'package:bus/ui/pages/journey/live_journey_guide.dart';
import 'package:bus/ui/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _State extends AppState {
  _State() : super(api: BusApi(accessToken: () async => 'test-token'));
  Json? event;

  @override
  Future<void> sendJourneyEvent(String type, Json payload) async {
    event = {'eventType': type, 'payload': payload};
  }
}

_State _state({String movement = 'walking', Json? boarded, Json? guidance}) {
  const place = Place(id: 'origin', name: '대전역', address: '');
  final state = _State();
  state.activeRoute = TravelRoute.fromJson(
    {
      'candidateId': 'candidate',
      'legs': [
        {
          'legIndex': 1,
          'kind': 'bus',
          'route': {'id': '1', 'routeNo': '605'},
          'patternKey': 'planned',
          'board': {'name': '대전역', 'directionCode': '0'},
          'alight': {'name': '시청'},
        },
      ],
    },
    searchId: 'search',
    origin: place,
    destination: place,
  );
  state.journey = {
    'journeyId': 'journey',
    'stateVersion': 1,
    'movementState': movement,
    'currentProgress': {'nextBusLegIndex': 1, 'boarded': boarded},
    'guidance': {'baseStateVersion': 1, ...?guidance},
  };
  return state;
}

Future<void> _show(WidgetTester tester, AppState state) async {
  tester.view.physicalSize = const Size(360, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    AppScope(
      state: state,
      child: MaterialApp(theme: AppTheme.light, home: const LiveJourneyGuide()),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _openBoarding(WidgetTester tester) async {
  await tester.ensureVisible(find.text('버스에 탑승했어요'));
  await tester.tap(find.text('버스에 탑승했어요'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('GPS로 추정한 다른 노선의 탑승 후보를 확인하거나 차량번호를 수정해 저장한다', (tester) async {
    const candidate = {
      'legIndex': 1,
      'routeId': '2',
      'patternKey': 'other-pattern',
      'directionCode': '1',
      'vehicleId': '대전75자2511',
    };
    final state = _state(
      guidance: {
        'boardingEstimate': {
          'status': 'suggested',
          'confidence': 'high',
          'suggestion': {...candidate, 'requiresUserConfirmation': true},
        },
      },
    );
    addTearDown(state.dispose);
    await _show(tester, state);
    expect(state.event, isNull);
    await tester.tap(find.text('이 버스에 탑승했어요'));
    await tester.pumpAndSettle();
    expect(state.event, {
      'eventType': 'board',
      'payload': {...candidate, 'confirmation': 'user_confirmed'},
    });

    await tester.tap(find.text('탑승 버스 직접 확인·수정'));
    await tester.pumpAndSettle();
    final field = find.byType(TextField).last;
    expect(tester.widget<TextField>(field).controller!.text, '대전75자2511');
    await tester.enterText(field, '대전75자9228');
    await tester.tap(find.text('확인한 정보 저장'));
    await tester.pumpAndSettle();
    expect(state.event, {
      'eventType': 'board',
      'payload': {
        ...candidate,
        'vehicleId': '대전75자9228',
        'confirmation': 'user_entered_vehicle',
      },
    });
  });

  testWidgets('다음 승차 차량·도착시각과 추정 근거를 실제 안내에 표시한다', (tester) async {
    final state = _state(
      guidance: {
        'arrival': {
          'remainingSeconds': 600,
          'plannedArrivalAt': '2026-11-13T06:20:00Z',
        },
        'nextBoarding': <String, dynamic>{
          'predictedArrivalAt': '2026-11-13T06:10:00Z',
          'waitSeconds': 120,
          'slackSeconds': -198.784654,
          'vehicle': {'vehicleId': '대전75자1234'},
          'upcoming': [
            {
              'predictedArrivalAt': '2026-11-13T06:10:00Z',
              'waitSeconds': 120,
              'vehicleId': '대전75자1234',
              'etaSource': 'provider',
              'basisSource': 'server_received_at_approx',
            },
            {
              'predictedArrivalAt': '2026-11-13T06:15:00Z',
              'waitSeconds': 420,
              'vehicleId': null,
              'etaSource': 'headway_estimate',
            },
          ],
        },
      },
    );
    addTearDown(state.dispose);
    await _show(tester, state);
    expect(find.text('평가한 차량: 대전75자1234'), findsOneWidget);
    expect(find.textContaining('목적지 도착 예상:'), findsOneWidget);
    expect(find.textContaining('승차 정류소 도착 예상:'), findsOneWidget);
    expect(find.textContaining('제공처 예상 · 수집 시각 기준 근사'), findsOneWidget);
    expect(find.textContaining('배차간격 기반 추정 · 실제 차량·시각 미확정'), findsOneWidget);
    expect(find.text('승차 여유: -199초'), findsOneWidget);
    state.journey!['guidance']['nextBoarding']['slackSeconds'] = null;
    state.notifyListeners();
    await tester.pumpAndSettle();
    expect(find.text('승차 여유: 확인 불가'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('탑승 차량 하차 ETA와 최종 도보를 연결하고 미제공·불일치는 추정하지 않는다', (tester) async {
    final boarded = <String, dynamic>{
      'legIndex': 1,
      'routeId': '1',
      'patternKey': 'planned',
      'directionCode': '0',
      'vehicleId': '대전75자1234',
      'matchesPlannedRoute': true,
    };
    final state = _state(
      movement: 'onboard',
      boarded: boarded,
      guidance: {
        'onboard': {
          'alightEta': {
            'predictedArrivalAt': '2026-11-13T06:20:00Z',
            'waitSeconds': 300,
            'etaSource': 'leading_vehicle_gap',
          },
        },
      },
    );
    addTearDown(state.dispose);
    await _show(tester, state);
    expect(find.textContaining('하차 정류소 도착 예상:'), findsOneWidget);
    expect(find.textContaining('앞차 간격 기반 추정 · 검증 전'), findsOneWidget);
    expect(find.text('확인한 차량: 대전75자1234'), findsOneWidget);
    state.journey!['guidance'] = {'baseStateVersion': 1};
    state.notifyListeners();
    await tester.pumpAndSettle();
    expect(find.text('하차 정류소 도착 예상: 확인 불가'), findsOneWidget);
    boarded['matchesPlannedRoute'] = false;
    state.notifyListeners();
    await tester.pumpAndSettle();
    expect(find.textContaining('하차 정류소 도착 예상:'), findsNothing);
    state.journey!['movementState'] = 'walking';
    state.journey!['currentProgress'] = {'nextBusLegIndex': null};
    state.journey!['guidance'] = {
      'baseStateVersion': 1,
      'arrival': {'finalWalkSeconds': 180, 'plannedArrivalAt': null},
    };
    state.notifyListeners();
    await tester.pumpAndSettle();
    expect(find.text('마지막 도보: 3분'), findsOneWidget);
    expect(find.textContaining('목적지 도착 예상:'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('처음 열린 확인 창이 늦게 도착한 차량번호를 받되 수동 입력은 유지한다', (tester) async {
    final state = _state();
    addTearDown(state.dispose);
    await _show(tester, state);

    for (final manual in [null, '대전75자9228']) {
      state.journey!['guidance'] = null;
      state.notifyListeners();
      await tester.pumpAndSettle();
      await _openBoarding(tester);
      final field = find.byType(TextField).last;
      expect(tester.widget<TextField>(field).controller!.text, isEmpty);
      expect(find.text('도착 예정 차량번호를 확인 중이에요.'), findsOneWidget);
      if (manual != null) await tester.enterText(field, manual);

      state.journey!['guidance'] = {
        'baseStateVersion': 1,
        'nextBoarding': {
          'legIndex': 1,
          'vehicle': {'vehicleId': '대전75자2511'},
        },
      };
      state.notifyListeners();
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(field).controller!.text,
        manual ?? '대전75자2511',
      );
      await tester.tap(find.text('확인한 정보 저장'));
      await tester.pumpAndSettle();
      expect(state.event!['payload']['vehicleId'], manual ?? '대전75자2511');
      expect(
        state.event!['payload']['confirmation'],
        manual == null ? 'user_confirmed' : 'user_entered_vehicle',
      );
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('평가 차량을 우선 입력하고 확인·직접 수정·비움을 구분해 저장한다', (tester) async {
    final state = _state(
      guidance: {
        'nextBoarding': {
          'legIndex': 1,
          'routeId': '1',
          'patternKey': 'planned',
          'vehicle': {'vehicleId': '대전75자1234'},
          'upcoming': [
            {'vehicleId': '대전75자5678'},
          ],
        },
      },
    );
    addTearDown(state.dispose);
    await _show(tester, state);

    for (final (input, vehicleId, confirmation) in [
      (null, '대전75자1234', 'user_confirmed'),
      ('대전75자9999', '대전75자9999', 'user_entered_vehicle'),
      ('', null, 'user_selected_route'),
    ]) {
      await _openBoarding(tester);
      final field = find.byType(TextField).last;
      expect(tester.widget<TextField>(field).controller!.text, '대전75자1234');
      if (input != null) await tester.enterText(field, input);
      await tester.tap(find.text('확인한 정보 저장'));
      await tester.pumpAndSettle();
      expect(state.event, {
        'eventType': 'board',
        'payload': {
          'legIndex': 1,
          'routeId': '1',
          'patternKey': 'planned',
          'directionCode': '0',
          'vehicleId': vehicleId,
          'confirmation': confirmation,
        },
      });
    }
    await _openBoarding(tester);
    await tester.enterText(find.byType(TextField).first, '916');
    await tester.pump();
    expect(
      tester.widget<TextField>(find.byType(TextField).last).controller!.text,
      isEmpty,
    );
    await tester.tap(find.text('지금은 확인하기 어려워요'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('평가 차량번호가 없으면 같은 구간의 유일한 도착 예정 차량번호를 입력한다', (tester) async {
    final state = _state(
      guidance: {
        'nextBoarding': {
          'legIndex': 1,
          'vehicle': {'vehicleId': null},
          'upcoming': [
            {'vehicleId': null},
            {'vehicleId': '대전75자5678'},
            {'vehicleId': '대전75자5678'},
          ],
        },
      },
    );
    addTearDown(state.dispose);
    await _show(tester, state);
    await _openBoarding(tester);
    expect(
      tester.widget<TextField>(find.byType(TextField).last).controller!.text,
      '대전75자5678',
    );
    await tester.tap(find.text('확인한 정보 저장'));
    await tester.pumpAndSettle();
    expect(state.event!['payload']['vehicleId'], '대전75자5678');
    expect(state.event!['payload']['confirmation'], 'user_confirmed');
    expect(tester.takeException(), isNull);
  });

  testWidgets('구간·상태·노선이 다르거나 차량 후보가 여러 대면 자동 입력하지 않는다', (tester) async {
    final state = _state();
    addTearDown(state.dispose);
    state.activeRoute!.legs.single['vehicle'] = {'vehicleId': '검색 당시 차량'};
    await _show(tester, state);
    const next = <String, dynamic>{
      'legIndex': 1,
      'routeId': '1',
      'patternKey': 'planned',
      'vehicle': {'vehicleId': '대전75자1234'},
    };
    for (final scenario in <String, Json>{
      '다른 구간': {
        'nextBoarding': {...next, 'legIndex': 3},
      },
      '오래된 상태': {'baseStateVersion': 0, 'nextBoarding': next},
      '다른 노선': {
        'nextBoarding': {...next, 'routeId': '2'},
      },
      '다른 패턴': {
        'nextBoarding': {...next, 'patternKey': 'other'},
      },
      '여러 도착 예정 차량': {
        'nextBoarding': {
          'legIndex': 1,
          'upcoming': [
            {'vehicleId': '대전75자1234'},
            {'vehicleId': '대전75자5678'},
          ],
        },
      },
    }.entries) {
      state.journey!['guidance'] = {'baseStateVersion': 1, ...scenario.value};
      state.notifyListeners();
      await tester.pumpAndSettle();
      await _openBoarding(tester);
      expect(
        tester.widget<TextField>(find.byType(TextField).last).controller!.text,
        isEmpty,
        reason: scenario.key,
      );
      await tester.tap(find.text('지금은 확인하기 어려워요'));
      await tester.pumpAndSettle();
    }
    expect(state.event, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('차량번호만 정정할 때 실제 저장한 노선·패턴·방향을 보존한다', (tester) async {
    final state = _state(
      movement: 'onboard',
      boarded: {
        'legIndex': 1,
        'routeId': '9007199254740993',
        'patternKey': 'actual-pattern',
        'directionCode': '1',
        'vehicleId': 'old-vehicle',
        'matchesPlannedRoute': false,
        'eventId': '90',
      },
      guidance: {
        'nextBoarding': {
          'legIndex': 1,
          'vehicle': {'vehicleId': 'newly-suggested-vehicle'},
        },
      },
    );
    addTearDown(state.dispose);
    await _show(tester, state);
    await tester.ensureVisible(find.text('탑승 노선·방향·차량 수정'));
    await tester.tap(find.text('탑승 노선·방향·차량 수정'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField).last).controller!.text,
      'old-vehicle',
    );
    await tester.enterText(find.byType(TextField).last, 'new-vehicle');
    await tester.tap(find.text('확인한 정보 저장'));
    await tester.pumpAndSettle();
    expect(state.event, {
      'eventType': 'correction',
      'payload': {
        'supersedesEventId': '90',
        'routeId': '9007199254740993',
        'patternKey': 'actual-pattern',
        'directionCode': '1',
        'vehicleId': 'new-vehicle',
      },
    });
    expect(tester.takeException(), isNull);
  });
}
