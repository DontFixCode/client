import 'package:bus/app.dart';
import 'package:bus/ui/widgets/route_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('compact phone can browse, search, compare and start guidance', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const BusroApp());
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('먼저 둘러보기'));
    await tester.tap(find.text('먼저 둘러보기'));
    await tester.pumpAndSettle();
    expect(find.text('오늘의 이동도, 버스로.'), findsOneWidget);
    expect(
      tester
          .widgetList<NavigationDestination>(find.byType(NavigationDestination))
          .map((destination) => destination.label),
      ['이용기록', '홈', '내정보'],
    );
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      1,
    );
    expect(tester.takeException(), isNull);

    await tester.ensureVisible(
      find.byKey(const ValueKey('searchRoutesButton')),
    );
    await tester.tap(find.byKey(const ValueKey('searchRoutesButton')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '한밭수목원');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, '한밭수목원'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('searchRoutesButton')));
    await tester.pumpAndSettle();
    expect(find.text('경로 비교'), findsOneWidget);
    await tester.tap(find.byType(RouteCard).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('startJourneyButton')));
    await tester.pumpAndSettle();
    expect(find.text('첫 정류장으로 걸어가요'), findsOneWidget);
    await tester.tap(find.text('정류장에 도착했어요'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('한밭수목원까지 안내 중'), findsOneWidget);
    await tester.tap(find.text('계속하기'));
    await tester.pumpAndSettle();
    expect(find.text('605번 버스를 기다려요'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(NavigationDestination, '이용기록'));
    await tester.pumpAndSettle();
    expect(find.text('우리의 첫 번째 이동을 기다려요'), findsOneWidget);
    await tester.tap(find.widgetWithText(NavigationDestination, '내정보'));
    await tester.pumpAndSettle();
    expect(find.text('로그인'), findsWidgets);
    await tester.tap(find.widgetWithText(NavigationDestination, '홈'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('searchRoutesButton')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
