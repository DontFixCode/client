import 'package:bus/data/demo_data.dart';
import 'package:bus/state/app_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'journey_flow_test.dart' show mountGuide, tapText;

void main() {
  final routes = DemoData.routes(DemoData.places[0], DemoData.places[1]);
  final transfer = routes.first;
  final banner = find.byKey(const ValueKey('alightingBanner'));
  final nextStop = find.byKey(const ValueKey('nextDemoStopButton'));
  final previewTransfer = find.byKey(
    const ValueKey('previewFasterTransferButton'),
  );

  testWidgets('하차 안내와 환승 변경은 알림 설정과 무관하며 진행 상태를 유지한다', (tester) async {
    final state = AppState()
      ..startJourney(transfer)
      ..setAlertsEnabled(false)
      ..setBoardingInfo(
        bus: transfer.busNumbers.first,
        direction: transfer.transferStop!,
        uncertain: false,
      )
      ..setGuideStep(2);
    await mountGuide(tester, state);
    expect(banner, findsOneWidget);
    expect(find.text('2정류장 후 하차'), findsOneWidget);

    await tester.ensureVisible(nextStop);
    await tester.tap(nextStop);
    await tester.pumpAndSettle();
    expect(state.remainingStops, 1);
    expect(find.text('5분 더 빠른 환승 경로가 있어요'), findsOneWidget);
    expect(state.transferSuggestionSeen, isTrue);
    await tapText(tester, '유지');
    expect(state.activeRoute, same(transfer));
    expect(state.guideStep, 2);
    expect(state.remainingStops, 1);
    expect(state.confirmedBus, transfer.busNumbers.first);
    expect(find.text('1정류장 후 하차'), findsOneWidget);

    final alternative = state.fasterTransfer!;
    expect(alternative.minutes, transfer.minutes - 5);
    expect(alternative.transferStop, transfer.transferStop);
    expect(alternative.busNumbers.first, transfer.busNumbers.first);
    expect(alternative.busNumbers.last, isNot(transfer.busNumbers.last));
    await tester.ensureVisible(previewTransfer);
    await tester.tap(previewTransfer);
    await tester.pumpAndSettle();
    await tapText(tester, '${alternative.busNumbers.last}번으로 변경');
    expect(state.activeRoute?.id, alternative.id);
    expect(state.guideStep, 2);
    expect(state.remainingStops, 1);
    expect(state.confirmedBus, transfer.busNumbers.first);
    expect(state.confirmedDirection, transfer.transferStop);
    expect(state.fasterTransfer, isNull);
    expect(previewTransfer, findsNothing);

    await tester.ensureVisible(nextStop);
    await tester.tap(nextStop);
    await tester.pumpAndSettle();
    expect(state.remainingStops, 0);
    expect(banner, findsOneWidget);
    expect(find.text('이번 정류장에서 하차'), findsOneWidget);
    expect(find.text('5분 더 빠른 환승 경로가 있어요'), findsNothing);
    state.passDemoStop();
    expect(state.remainingStops, 0);
    await tapText(tester, '하차 정류장에 도착했어요');
    expect(banner, findsNothing);
    await tapText(tester, '연결 버스에 탑승했어요');
    await tapText(tester, '이 버스에 탑승했어요');
    expect(state.remainingStops, 2);
    expect(find.text('2정류장 후 하차'), findsOneWidget);
    await tapText(tester, '버스에서 내렸어요');
    expect(banner, findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('탑승 정보가 미확인이거나 노선·방향이 다르면 안내를 예측하지 않는다', (tester) async {
    final state = AppState()
      ..startJourney(transfer)
      ..setGuideStep(2);
    await mountGuide(tester, state);
    expect(banner, findsNothing);
    expect(previewTransfer, findsNothing);
    expect(state.fasterTransfer, isNull);

    for (final boarding in [
      (
        bus: transfer.busNumbers.first,
        direction: transfer.transferStop!,
        uncertain: true,
      ),
      (bus: '999', direction: transfer.transferStop!, uncertain: false),
      (bus: transfer.busNumbers.first, direction: '다른 방향', uncertain: false),
    ]) {
      state.setBoardingInfo(
        bus: boarding.bus,
        direction: boarding.direction,
        uncertain: boarding.uncertain,
      );
      await tester.pumpAndSettle();
      expect(banner, findsNothing);
      expect(nextStop, findsNothing);
      expect(previewTransfer, findsNothing);
      expect(state.fasterTransfer, isNull);
      state.passDemoStop();
      expect(state.remainingStops, 2);
    }
    state.setBoardingInfo(
      bus: transfer.busNumbers.first,
      direction: transfer.transferStop!,
      uncertain: false,
    );
    await tester.pumpAndSettle();
    expect(banner, findsOneWidget);
    expect(previewTransfer, findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('직행 경로는 하차 정류장 수만 안내하고 환승 팝업을 띄우지 않는다', (tester) async {
    final route = routes.firstWhere((route) => route.transfers == 0);
    final state = AppState()
      ..startJourney(route)
      ..setBoardingInfo(
        bus: route.busNumbers.first,
        direction: route.arrivalStop,
        uncertain: false,
      )
      ..setGuideStep(2);
    await mountGuide(tester, state);
    expect(find.text('2정류장 후 하차'), findsOneWidget);
    expect(previewTransfer, findsNothing);
    expect(state.fasterTransfer, isNull);
    for (var stop = 1; stop >= 0; stop--) {
      await tester.ensureVisible(nextStop);
      await tester.tap(nextStop);
      await tester.pumpAndSettle();
      expect(state.remainingStops, stop);
      expect(find.text('5분 더 빠른 환승 경로가 있어요'), findsNothing);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('작은 화면과 확대 글자에서도 하차 배너와 환승 팝업을 사용할 수 있다', (tester) async {
    final state = AppState()
      ..startJourney(transfer)
      ..setBoardingInfo(
        bus: transfer.busNumbers.first,
        direction: transfer.transferStop!,
        uncertain: false,
      )
      ..setGuideStep(2);
    await mountGuide(tester, state);
    tester.view.physicalSize = const Size(320, 844);
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpAndSettle();
    expect(banner, findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(previewTransfer);
    await tester.tap(previewTransfer);
    await tester.pumpAndSettle();
    expect(find.text('5분 더 빠른 환승 경로가 있어요'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tapText(tester, '유지');
    expect(state.activeRoute, same(transfer));
    expect(tester.takeException(), isNull);
  });
}
