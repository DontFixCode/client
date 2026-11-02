import 'package:bus/config/app_routes.dart';
import 'package:bus/data/demo_data.dart';
import 'package:bus/state/app_state.dart';
import 'package:bus/ui/pages/main_page.dart';
import 'package:bus/ui/pages/routes/route_results_page.dart';
import 'package:bus/ui/theme/app_theme.dart';
import 'package:bus/ui/widgets/route_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(AppState state, Widget home) => AppScope(
  state: state,
  child: MaterialApp(
    theme: AppTheme.light,
    home: home,
    routes: {
      AppRoutes.main: (_) => const MainPage(),
      AppRoutes.results: (_) => const RouteResultsPage(),
    },
  ),
);

void _phoneSize(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  testWidgets('장소를 검색해 즐겨찾기를 바꾸고 선택한 경로를 비교한다', (tester) async {
    _phoneSize(tester);
    final state = AppState();
    addTearDown(state.dispose);
    await tester.pumpWidget(_app(state, const MainPage()));

    await tester.ensureVisible(find.text('도착지를 입력해 주세요'));
    await tester.tap(find.text('도착지를 입력해 주세요'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '한밭');
    await tester.pumpAndSettle();
    expect(find.text('한밭수목원'), findsOneWidget);
    expect(find.text('대전복합터미널'), findsNothing);
    await tester.tap(find.byTooltip('한밭수목원 즐겨찾기 해제'));
    await tester.pump();
    expect(state.isFavorite(DemoData.places[1]), isFalse);
    await tester.tap(find.text('한밭수목원'));
    await tester.pumpAndSettle();
    expect(state.destination?.id, 'arboretum');

    await tester.tap(find.byTooltip('출발지와 도착지 바꾸기'));
    await tester.pumpAndSettle();
    expect(state.origin.id, 'arboretum');
    expect(state.destination?.id, 'daejeon_station');
    await tester.tap(find.widgetWithText(NavigationDestination, '이용기록'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('새로운 길 찾아보기'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      1,
    );
    await tester.tap(find.widgetWithText(NavigationDestination, '내정보'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(NavigationDestination, '홈'));
    await tester.pumpAndSettle();
    expect(state.origin.id, 'arboretum');
    expect(state.destination?.id, 'daejeon_station');

    await tester.tap(find.widgetWithText(NavigationDestination, '내정보'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.widgetWithText(ListTile, '충남대학교'));
    await tester.tap(find.widgetWithText(ListTile, '충남대학교'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      1,
    );
    expect(state.origin.id, 'arboretum');
    expect(state.destination?.id, 'chungnam');

    await tester.ensureVisible(
      find.byKey(const ValueKey('searchRoutesButton')),
    );
    await tester.tap(find.byKey(const ValueKey('searchRoutesButton')));
    await tester.pumpAndSettle();
    expect(find.text('경로 비교'), findsOneWidget);
    expect(
      tester.widget<RouteCard>(find.byType(RouteCard).first).route.id,
      'relaxed',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('출발지와 도착지가 같거나 지원 지역 밖이면 빈 경로를 안내한다', (tester) async {
    _phoneSize(tester);
    final state = AppState()..setDestination(DemoData.places.first);
    addTearDown(state.dispose);
    await tester.pumpWidget(_app(state, const RouteResultsPage()));
    expect(find.text('출발지와 도착지가 같아요'), findsOneWidget);
    expect(find.byType(RouteCard), findsNothing);

    state.setDestination(DemoData.places.last);
    await tester.pump();
    expect(find.text('아직 안내할 수 없는 구간이에요'), findsOneWidget);
    expect(find.byType(RouteCard), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('빠른순과 환승 적은순이 경로 순서를 바꾸며 미확인 확률을 표시한다', (tester) async {
    _phoneSize(tester);
    final state = AppState()..setDestination(DemoData.places[1]);
    addTearDown(state.dispose);
    await tester.pumpWidget(_app(state, const RouteResultsPage()));
    expect(
      tester.widget<RouteCard>(find.byType(RouteCard).first).route.id,
      'relaxed',
    );

    await tester.tap(find.text('빠른순'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<RouteCard>(find.byType(RouteCard).first).route.id,
      'fast',
    );
    await tester.tap(find.text('환승 적은순'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<RouteCard>(find.byType(RouteCard).first).route.id,
      'direct',
    );

    await tester.scrollUntilVisible(
      find.text('환승 확률 확인 불가'),
      450,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    expect(find.text('환승 확률 확인 불가'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
