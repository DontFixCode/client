import 'package:bus/config/app_routes.dart';
import 'package:bus/data/demo_data.dart';
import 'package:bus/models/journey_record.dart';
import 'package:bus/state/app_state.dart';
import 'package:bus/ui/pages/history/history_page.dart';
import 'package:bus/ui/pages/journey/journey_guide_page.dart';
import 'package:bus/ui/pages/main_page.dart';
import 'package:bus/ui/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> mountGuide(WidgetTester tester, AppState state) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(state.dispose);
  await tester.pumpWidget(
    AppScope(
      state: state,
      child: MaterialApp(
        theme: AppTheme.light,
        initialRoute: AppRoutes.main,
        routes: {
          AppRoutes.main: (context) => Scaffold(
            body: SafeArea(
              child: Column(
                children: [
                  FilledButton(
                    onPressed: () =>
                        Navigator.pushNamed(context, AppRoutes.guide),
                    child: const Text('안내 열기'),
                  ),
                  const Expanded(child: HistoryPage()),
                ],
              ),
            ),
          ),
          AppRoutes.guide: (_) => const JourneyGuidePage(),
        },
      ),
    ),
  );
  await tapText(tester, '안내 열기');
}

Future<void> tapText(WidgetTester tester, String text) async {
  final finder = find.text(text).last;
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'transfer guide saves the selected outcome and history can delete it',
    (tester) async {
      final state = AppState();
      final route = DemoData.routes(
        DemoData.places[0],
        DemoData.places[1],
      ).first;
      state.startJourney(route);
      await mountGuide(tester, state);

      await tapText(tester, '정류장에 도착했어요');
      expect(state.guideStep, 1);
      await tapText(tester, '버스에 탑승했어요');
      expect(find.text('탑승한 버스를 확인해주세요'), findsOneWidget);
      await tapText(tester, '이 버스에 탑승했어요');
      expect(state.guideStep, 2);
      await tapText(tester, '하차 정류장에 도착했어요');
      expect(state.guideStep, 3);
      await tapText(tester, '연결 버스에 탑승했어요');
      await tapText(tester, '이 버스에 탑승했어요');
      expect(state.guideStep, 4);
      await tapText(tester, '버스에서 내렸어요');
      expect(state.guideStep, 5);
      await tapText(tester, '목적지에 도착했어요');
      expect(state.guideStep, 6);
      await tapText(tester, '이동 기록 남기기');
      await tapText(tester, '환승 성공');
      await tapText(tester, '이동 완료하고 저장하기');

      expect(state.activeRoute, isNull);
      expect(state.history, hasLength(1));
      expect(state.history.single.outcome, JourneyOutcome.success);
      expect(find.text('환승 성공'), findsOneWidget);
      await tapText(tester, '${route.origin.name} → ${route.destination.name}');
      await tapText(tester, '이 기록 삭제하기');
      expect(state.history, hasLength(1));
      await tapText(tester, '삭제');
      expect(state.history, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('direct journey skips both transfer stages', (tester) async {
    final state = AppState();
    final route = DemoData.routes(
      DemoData.places[0],
      DemoData.places[1],
    ).firstWhere((route) => route.transfers == 0);
    state.startJourney(route);
    await mountGuide(tester, state);
    await tapText(tester, '정류장에 도착했어요');
    await tapText(tester, '버스에 탑승했어요');
    await tapText(tester, '이 버스에 탑승했어요');
    await tapText(tester, '하차 정류장에 도착했어요');
    expect(state.guideStep, 5);
    expect(find.text('목적지까지 조금만 더 걸어요'), findsOneWidget);
    expect(find.text('연결 버스에 탑승했어요'), findsNothing);
    await tapText(tester, '목적지에 도착했어요');
    await tapText(tester, '이동 기록 남기기');
    expect(find.text('환승 성공'), findsNothing);
    await tapText(tester, '이동 완료하고 저장하기');
    expect(state.history.single.route.transfers, 0);
    expect(state.activeRoute, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'leaving preserves progress and cancellation requires confirmation',
    (tester) async {
      final state = AppState();
      state.startJourney(
        DemoData.routes(DemoData.places[0], DemoData.places[1]).first,
      );
      await mountGuide(tester, state);
      await tapText(tester, '정류장에 도착했어요');
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(state.activeRoute, isNotNull);
      expect(state.guideStep, 1);
      await tapText(tester, '안내 열기');
      expect(find.text('605번 버스를 기다려요'), findsOneWidget);
      await tapText(tester, '안내 종료');
      await tapText(tester, '계속 안내받기');
      expect(state.activeRoute, isNotNull);
      await tapText(tester, '안내 종료');
      await tapText(tester, '안내 종료');
      expect(state.activeRoute, isNull);
      expect(state.history, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('guide without an active route can open search', (tester) async {
    final state = AppState();
    addTearDown(state.dispose);
    await tester.pumpWidget(
      AppScope(
        state: state,
        child: MaterialApp(
          theme: AppTheme.light,
          home: const JourneyGuidePage(),
          routes: {AppRoutes.main: (_) => const MainPage()},
        ),
      ),
    );
    expect(find.text('진행 중인 이동이 없어요'), findsOneWidget);
    await tapText(tester, '길찾기 시작하기');
    expect(find.text('도착지를 입력해 주세요'), findsOneWidget);
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      1,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'boarding correction survives resume and resets for the connecting bus',
    (tester) async {
      final state = AppState();
      state.startJourney(
        DemoData.routes(DemoData.places[0], DemoData.places[1]).first,
      );
      await mountGuide(tester, state);
      await tapText(tester, '정류장에 도착했어요');
      await tapText(tester, '버스에 탑승했어요');
      await tester.enterText(find.byType(TextFormField).at(0), '999');
      await tester.enterText(find.byType(TextFormField).at(1), '수정한 정류장');
      await tapText(tester, '이 버스에 탑승했어요');
      expect(state.confirmedBus, '999');
      expect(state.confirmedDirection, '수정한 정류장');
      expect(find.text('94%'), findsNothing);
      expect(find.text('확인 불가'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tapText(tester, '안내 열기');
      expect(find.text('999번 버스로 이동 중이에요'), findsOneWidget);
      expect(find.text('수정한 정류장 방향'), findsOneWidget);

      await tapText(tester, '하차 정류장에 도착했어요');
      expect(state.confirmedBus, isNull);
      expect(state.boardingUncertain, isFalse);
      await tapText(tester, '연결 버스에 탑승했어요');
      expect(find.text('705'), findsOneWidget);
      expect(find.text('999'), findsNothing);
      await tapText(tester, '지금은 확인하기 어려워요');
      expect(state.boardingUncertain, isTrue);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tapText(tester, '안내 열기');
      expect(find.text('탑승 정보 확인이 필요해요'), findsOneWidget);
      expect(find.text('94%'), findsNothing);
      expect(find.text('확인 불가'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
