import 'package:bus/models/place.dart';
import 'package:bus/models/travel_route.dart';
import 'package:bus/ui/theme/app_theme.dart';
import 'package:bus/ui/widgets/route_card.dart';
import 'package:bus/ui/widgets/route_timeline.dart';
import 'package:bus/ui/widgets/status_pill.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

TravelRoute _route({int? probability, int? margin, bool direct = false}) =>
    TravelRoute(
      id: 'test',
      origin: const Place(id: 'origin', name: '배재대학교', address: '대전'),
      destination: const Place(id: 'destination', name: '복합터미널', address: '대전'),
      minutes: 55,
      walkMinutes: 6,
      busNumbers: direct ? const ['216'] : const ['216', '102'],
      boardingStop: '배재대학교',
      arrivalStop: '복합터미널',
      transferStop: direct ? null : '정부청사역',
      reason: '환승을 확인했어요',
      probability: probability,
      marginMinutes: margin,
    );

void main() {
  test('환승 성공 가능성은 20 단위 5단계이며 미확인 값을 구분한다', () {
    for (final (probability, label) in [
      (null, '확인 불가'),
      (0, '매우 낮음'),
      (19, '매우 낮음'),
      (20, '낮음'),
      (39, '낮음'),
      (40, '보통'),
      (59, '보통'),
      (60, '높음'),
      (79, '높음'),
      (80, '매우 높음'),
      (100, '매우 높음'),
    ]) {
      expect(_route(probability: probability).probabilityLabel, label);
    }
  });

  testWidgets('작은 화면에서 두 버스 사이에 환승 여유를 표시한다', (tester) async {
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(20),
            child: RouteCard(
              route: _route(probability: 72, margin: 4),
              onTap: () {},
            ),
          ),
        ),
      ),
    );
    Finder inBar(String text) => find.descendant(
      of: find.byType(RouteSegmentBar),
      matching: find.text(text),
    );
    expect(
      tester.getCenter(inBar('216')).dx,
      lessThan(tester.getCenter(inBar('4분')).dx),
    );
    expect(
      tester.getCenter(inBar('4분')).dx,
      lessThan(tester.getCenter(inBar('102')).dx),
    );
    expect(find.text('높음'), findsOneWidget);
    expect(find.textContaining('%'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('미확인 환승과 무환승은 잘못된 여유시간을 표시하지 않는다', (tester) async {
    for (final direct in [false, true]) {
      final route = _route(direct: direct);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  RouteCard(route: route, onTap: () {}),
                  RouteTimeline(route: route),
                ],
              ),
            ),
          ),
        ),
      );
      expect(find.textContaining('null'), findsNothing);
      expect(find.textContaining('%'), findsNothing);
      expect(find.text('미정'), direct ? findsNothing : findsOneWidget);
      expect(
        find.byType(TransferProbabilityPill),
        direct ? findsNothing : findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    }
  });
}
