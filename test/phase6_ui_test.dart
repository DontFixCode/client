import 'dart:convert';

import 'package:bus/data/bus_api.dart';
import 'package:bus/state/app_state.dart';
import 'package:bus/ui/pages/history/history_page.dart';
import 'package:bus/ui/theme/app_theme.dart';
import 'package:bus/ui/widgets/transfer_results.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Json _transfer({Json? result}) => {
  'snapshotKey': 'journey:s1:t1',
  'selectionVersion': 1,
  'transferIndex': 1,
  'frontLegIndex': 1,
  'nextLegIndex': 3,
  'prediction': {
    'probability': null,
    'slackSeconds': 245.01939099999998,
    'fixedAt': '2026-11-17T03:00:00Z',
  },
  'result': result,
  'evaluationStatus': result == null ? 'no_response' : 'counted',
};

Json _journey({String status = 'completed', Json? transfer}) => {
  'journeyId': 'journey',
  'lifecycleStatus': status,
  'stateVersion': 8,
  'resultVersion': 2,
  'currentProgress': {'completedBusLegs': <int>[]},
  'transferResults': [transfer ?? _transfer()],
  'selectedRoute': {
    'searchId': 'search',
    'candidateId': 'candidate',
    'origin': {'name': 'A'},
    'destination': {'name': 'B'},
    'legs': [
      {
        'kind': 'bus',
        'legIndex': 1,
        'route': {'id': '1', 'routeNo': '605'},
        'board': {'name': 'A'},
        'alight': {'name': 'C'},
      },
      {
        'kind': 'bus',
        'legIndex': 3,
        'route': {'id': '2', 'routeNo': '102'},
        'board': {'name': 'C'},
        'alight': {'name': 'B'},
      },
    ],
  },
};

class _State extends AppState {
  _State(Json detail)
    : super(
        api: BusApi(
          accessToken: () async => 'test-token',
          client: MockClient(
            (_) async => http.Response(
              jsonEncode(detail),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            ),
          ),
        ),
      );

  Json? submittedTransfer;
  String? submittedResult;
  bool? submittedConnection;
  ApiException? submitError;
  bool pending = false;
  String? pendingId;
  Json? retried;
  String? deleted;

  @override
  bool get hasPendingEvent => pending;
  @override
  String? get pendingEventJourneyId => pendingId;

  @override
  Future<Json> submitTransferResult(
    Json journey,
    Json transfer, {
    required String result,
    bool? usedPlanned,
  }) async {
    submittedTransfer = transfer;
    submittedResult = result;
    submittedConnection = usedPlanned;
    if (submitError != null) throw submitError!;
    return {
      ...journey,
      'transferResults': [
        {
          ...transfer,
          'result': {'value': result, 'eventId': '91'},
          'evaluationStatus': usedPlanned == false ? 'excluded' : 'counted',
        },
      ],
    };
  }

  @override
  Future<Json?> retryPendingEvent() async => retried;

  @override
  Future<void> deleteJourneyRecord(String id) async {
    deleted = id;
    serverHistory.removeWhere((item) => item['journeyId'] == id);
    notifyListeners();
  }
}

Future<void> _show(WidgetTester tester, _State state, Widget page) async {
  tester.view.physicalSize = const Size(360, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(state.dispose);
  await tester.pumpWidget(
    AppScope(
      state: state,
      child: MaterialApp(theme: AppTheme.light, home: page),
    ),
  );
  await tester.pumpAndSettle();
}

Widget _results(Json data, {ValueChanged<Json>? onUpdated}) => Scaffold(
  body: SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: TransferResults(journey: data, onUpdated: onUpdated),
  ),
);

Future<void> _select(WidgetTester tester, int field, String text) async {
  await tester.tap(find.byType(DropdownButtonFormField<String>).at(field));
  await tester.pumpAndSettle();
  await tester.tap(find.text(text).last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('하차 전 결과 입력을 막고 실제 다른 연결 선택을 명시적으로 전달한다', (tester) async {
    final data = _journey(status: 'active');
    final state = _State(data);
    Json? updated;
    await _show(
      tester,
      state,
      _results(data, onUpdated: (value) => updated = value),
    );
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, '결과 입력'))
          .onPressed,
      isNull,
    );
    expect(find.text('앞 버스에서 하차한 뒤 입력할 수 있어요.'), findsOneWidget);
    expect(find.text('당시 예측: 확률 확인 불가 · 여유 245초'), findsOneWidget);
    data['currentProgress']['completedBusLegs'] = [1];
    state.notifyListeners();
    await tester.pumpAndSettle();
    await tester.tap(find.text('결과 입력'));
    await tester.pumpAndSettle();
    await _select(tester, 0, '환승 성공');
    await _select(tester, 1, '다른 버스 연결 이용');
    await tester.tap(find.text('결과 저장'));
    await tester.pumpAndSettle();
    expect(state.submittedResult, 'success');
    expect(state.submittedConnection, isFalse);
    expect(state.submittedTransfer!['snapshotKey'], 'journey:s1:t1');
    expect(updated!['transferResults'][0]['evaluationStatus'], 'excluded');
    expect(tester.takeException(), isNull);
  });

  testWidgets('결과 정정은 최신 이벤트와 기존 연결 정보를 유지하고 충돌 후 상세를 갱신한다', (tester) async {
    final original = _journey(
      transfer: _transfer(
        result: {
          'value': 'unknown',
          'eventId': '9007199254740993',
          'originalEventId': '80',
        },
      ),
    );
    final latest = _journey(
      transfer: _transfer(
        result: {
          'value': 'failure',
          'eventId': '9007199254740994',
          'originalEventId': '80',
        },
      ),
    );
    final state = _State(latest)
      ..submitError = const ApiException(
        'CORRECTION_TARGET_SUPERSEDED',
        '최신 결과를 확인해 주세요.',
        status: 409,
      );
    Json? updated;
    await _show(
      tester,
      state,
      _results(original, onUpdated: (value) => updated = value),
    );
    expect(find.textContaining('확률 확인 불가'), findsOneWidget);
    await tester.tap(find.text('결과 수정'));
    await tester.pumpAndSettle();
    expect(find.text('기존 정보 유지'), findsOneWidget);
    await _select(tester, 0, '환승 성공');
    await tester.tap(find.text('결과 저장'));
    await tester.pumpAndSettle();
    expect(state.submittedConnection, isNull);
    expect(state.submittedTransfer!['result']['eventId'], '9007199254740993');
    expect(
      updated!['transferResults'][0]['result']['eventId'],
      '9007199254740994',
    );
    expect(find.text('최신 결과를 확인해 주세요.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('해당 기록의 미확인 전송을 재확인하고 새 결과 입력은 차단한다', (tester) async {
    final data = _journey();
    final latest = _journey(
      transfer: _transfer(result: {'value': 'unknown', 'eventId': '90'}),
    );
    final state = _State(data)
      ..pending = true
      ..pendingId = 'journey'
      ..retried = latest;
    Json? updated;
    await _show(
      tester,
      state,
      _results(data, onUpdated: (value) => updated = value),
    );
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, '결과 입력'))
          .onPressed,
      isNull,
    );
    await tester.tap(find.text('전송 결과 다시 확인'));
    await tester.pumpAndSettle();
    expect(updated!['transferResults'][0]['result']['value'], 'unknown');
  });

  testWidgets('종료된 서버 이동은 상세 확인 후 삭제하고 목록으로 돌아간다', (tester) async {
    final data = _journey();
    final state = _State(data)
      ..userName = '테스트'
      ..serverHistory = [
        {
          'journeyId': 'journey',
          'lifecycleStatus': 'completed',
          'origin': {'name': 'A'},
          'destination': {'name': 'B'},
        },
      ];
    await _show(tester, state, const HistoryPage());
    await tester.tap(find.text('A → B'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('이 이동 기록 삭제'), 400);
    await tester.tap(find.text('이 이동 기록 삭제'));
    await tester.pumpAndSettle();
    expect(state.deleted, isNull);
    await tester.tap(find.text('기록 삭제'));
    await tester.pumpAndSettle();
    expect(state.deleted, 'journey');
    expect(find.text('저장된 이동 기록이 없어요.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
