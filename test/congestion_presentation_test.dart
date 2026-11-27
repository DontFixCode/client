import 'package:bus/models/congestion.dart';
import 'package:bus/models/place.dart';
import 'package:bus/models/travel_route.dart';
import 'package:bus/ui/pages/transit/transit_page.dart';
import 'package:bus/ui/widgets/route_card.dart';
import 'package:bus/ui/widgets/route_timeline.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const available = {
  'status': 'available',
  'level': 'very_crowded',
  'dayType': 'weekday',
  'hour': 9,
  'loadPerVehicle': 58.2,
  'guidedRiders': 0.25,
  'lowConfidence': true,
  'fallback': 'adjacent_hours',
};
const missing = {
  'status': 'unavailable',
  'reason': 'congestion_profile_missing',
};

void main() {
  testWidgets('경로와 정류소의 평소 예상 혼잡도를 표시하고 미집계 구간을 구분한다', (tester) async {
    const place = Place(id: 'a', name: 'A', address: '');
    final route = TravelRoute.fromJson(
      {
        'candidateId': 'r',
        'cost': {
          'timeSeconds': 600,
          'equilibriumBiasSeconds': 48,
          'costSeconds': 648,
        },
        'evaluation': {'expectedTotalSeconds': 750, 'nominalTotalSeconds': 600},
        'legs': [
          {'kind': 'bus', 'congestion': available},
          {'kind': 'bus', 'congestion': missing},
        ],
      },
      searchId: 's',
      origin: place,
      destination: place,
    );
    expect(route.minutes, 10);
    expect(
      rankingCostLabel(route.cost),
      '추천 순위 계산값 10분 48초 · 이동 10분 + 혼잡 가중 48초',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Column(
              children: [
                RouteCard(route: route, onTap: () {}),
                RouteTimeline(route: route),
                ...arrivalWidgets({
                  'dataStatus': {'availability': 'available'},
                  'items': [
                    {'congestion': available},
                  ],
                }),
              ],
            ),
          ),
        ),
      ),
    );
    expect(find.text('평소 이 시간대 예상 혼잡도 · 매우 혼잡 (1/2구간 확인)'), findsOneWidget);
    expect(find.textContaining('평소 평일 9시 예상 혼잡도 · 매우 혼잡'), findsNWidgets(2));
    expect(find.textContaining('앱 안내 인원 반영'), findsNWidgets(2));
    expect(find.textContaining('인접 시간대 집계 사용'), findsNWidgets(2));
    expect(find.textContaining('표본 일수 부족'), findsNWidgets(2));
    expect(find.textContaining('노선 승하차 집계 없음'), findsOneWidget);
  });

  test('기존 응답에 없는 혼잡도와 추천 비용을 추정하지 않는다', () {
    expect(congestionDetail(null), isNull);
    expect(
      routeCongestionSummary([
        {'kind': 'bus'},
      ]),
      isNull,
    );
    expect(rankingCostLabel(null), isNull);
  });
}
