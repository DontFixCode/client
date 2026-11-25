import 'package:bus/data/bus_api.dart';
import 'package:bus/ui/theme/app_theme.dart';
import 'package:bus/ui/widgets/boarding_estimate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const Json _planned = {
  'legIndex': 1,
  'route': {'id': '42', 'routeNo': '605'},
  'patternKey': 'pattern-1',
  'board': {'directionCode': '1'},
};
const Json _suggestion = {
  'legIndex': 1,
  'routeId': '42',
  'patternKey': 'pattern-1',
  'directionCode': '1',
  'vehicleId': '대전75자1234',
  'matchedSamples': 3,
  'meanDistanceM': 18.4,
  'directionAlignment': 0.96,
  'requiresUserConfirmation': true,
};

Json _estimate({Json suggestion = _suggestion}) => {
  'status': 'suggested',
  'confidence': 'high',
  'evaluatedAt': '2026-11-23T10:00:00Z',
  'reasonCodes': [],
  'suggestion': suggestion,
};

Future<void> _show(
  WidgetTester tester, {
  required Json estimate,
  bool enabled = true,
  ValueChanged<Json>? onConfirm,
  ValueChanged<Json>? onEdit,
  double textScale = 1,
}) async {
  tester.view.physicalSize = const Size(320, 900);
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            BoardingEstimate(
              estimate: estimate,
              plannedLeg: _planned,
              enabled: enabled,
              onConfirm: onConfirm ?? (_) {},
              onEdit: onEdit ?? (_) {},
            ),
          ],
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('탑승 추정은 명시적 확인 후 계약의 board payload만 전달한다', (tester) async {
    Json? confirmed, edited;
    await _show(
      tester,
      estimate: _estimate(),
      onConfirm: (value) => confirmed = value,
      onEdit: (value) => edited = value,
    );
    expect(confirmed, isNull);
    expect(edited, isNull);
    expect(find.text('605번 · 차량 대전75자1234'), findsOneWidget);
    expect(find.textContaining('사용자 확인 필요'), findsOneWidget);
    expect(find.textContaining('추정 시각:'), findsOneWidget);
    await tester.tap(find.text('이 버스에 탑승했어요'));
    expect(confirmed, {
      'legIndex': 1,
      'routeId': '42',
      'patternKey': 'pattern-1',
      'directionCode': '1',
      'vehicleId': '대전75자1234',
      'confirmation': 'user_confirmed',
    });
    await tester.tap(find.text('탑승 버스 직접 확인·수정'));
    expect(edited, confirmed);
  });

  testWidgets('계획과 다른 후보와 nullable 방향을 계획 값으로 바꾸지 않는다', (tester) async {
    Json? confirmed, edited;
    await _show(
      tester,
      estimate: _estimate(
        suggestion: {
          ..._suggestion,
          'routeId': '99',
          'patternKey': 'alternate',
          'directionCode': null,
          'vehicleId': '대전75자9876',
        },
      ),
      onConfirm: (value) => confirmed = value,
      onEdit: (value) => edited = value,
    );
    expect(find.text('차량 대전75자9876'), findsOneWidget);
    expect(find.textContaining('605번'), findsNothing);
    expect(find.textContaining('계획한 노선·방향과 다를 수 있어요.'), findsOneWidget);
    await tester.tap(find.text('이 버스에 탑승했어요'));
    expect(confirmed?['routeId'], '99');
    expect(confirmed?['patternKey'], 'alternate');
    expect(confirmed?['directionCode'], isNull);
    await tester.tap(find.text('탑승 버스 직접 확인·수정'));
    expect(edited, confirmed);
  });

  testWidgets('저장 중이거나 pending 이벤트가 있으면 확인과 수정이 비활성화된다', (tester) async {
    var calls = 0;
    await _show(
      tester,
      estimate: _estimate(),
      enabled: false,
      onConfirm: (_) => calls++,
      onEdit: (_) => calls++,
    );
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    expect(
      tester.widget<TextButton>(find.byType(TextButton)).onPressed,
      isNull,
    );
    expect(calls, 0);
  });

  testWidgets('불완전하거나 다른 구간의 추정은 제출하지 않고 수동 확인을 연다', (tester) async {
    for (final change in <Json>[
      {'vehicleId': null},
      {'patternKey': ''},
      {'routeId': 'external-route'},
      {'legIndex': 3},
      {'requiresUserConfirmation': false},
    ]) {
      Json? edited;
      await _show(
        tester,
        estimate: _estimate(suggestion: {..._suggestion, ...change}),
        onEdit: (value) => edited = value,
      );
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      await tester.ensureVisible(find.text('탑승 버스 직접 확인·수정'));
      await tester.tap(find.text('탑승 버스 직접 확인·수정'));
      expect(edited, isEmpty);
    }
  });

  testWidgets('근거 부족·불일치 사유는 한국어로 표시하고 확인 버튼을 만들지 않는다', (tester) async {
    for (final entry in {
      'need_consecutive_accurate_locations': '연속된 정확한 위치가 더 필요해요.',
      'location_stale': '최근 위치가 없어 탑승을 추정할 수 없어요.',
      'vehicle_positions_unavailable': '비교할 버스 위치 정보가 아직 없어요.',
      'no_vehicle_trajectory_match': '현재 이동과 맞는 버스가 확인되지 않았어요.',
    }.entries) {
      await _show(
        tester,
        estimate: {
          'status': entry.key == 'no_vehicle_trajectory_match'
              ? 'no_match'
              : 'insufficient_evidence',
          'reasonCodes': [entry.key],
          'suggestion': null,
        },
      );
      expect(find.textContaining(entry.value), findsOneWidget);
      expect(find.textContaining(entry.key), findsNothing);
      expect(find.byType(FilledButton), findsNothing);
    }
    await _show(tester, estimate: {'status': 'not_applicable'});
    expect(find.textContaining('탑승 추정'), findsNothing);
  });

  testWidgets('작은 화면과 큰 글자에서 후보·확인 버튼이 넘치지 않는다', (tester) async {
    await _show(tester, estimate: _estimate(), textScale: 1.5);
    await tester.ensureVisible(find.text('탑승 버스 직접 확인·수정'));
    expect(tester.takeException(), isNull);
  });
}
