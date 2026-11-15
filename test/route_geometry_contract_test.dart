import 'package:bus/ui/widgets/route_geometry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('형상이 그려진 제공처만 표시하고 미확보 구간을 구분한다', (tester) async {
    const geometry = {
      'type': 'LineString',
      'coordinates': [
        [127.38, 36.35],
        [127.43, 36.33],
      ],
    };
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: RouteGeometry(
            legs: [
              {
                'kind': 'bus',
                'route': {'routeNo': '605'},
                'geometryStatus': 'available',
                'geometry': geometry,
                'geometrySource': 'odsay',
                'geometryVersion': 'sha256:test',
                'geometryFetchedAt': '2026-11-12T12:00:00Z',
              },
              {
                'kind': 'bus',
                'route': {'routeNo': '102'},
                'geometryStatus': 'unavailable',
                'geometry': geometry,
                'geometrySource': 'unavailable-provider',
                'geometryReason': 'pattern_shape_not_collected',
              },
            ],
          ),
        ),
      ),
    );
    expect(find.textContaining('출처: odsay · 수집: '), findsOneWidget);
    expect(find.textContaining('102번 형상:'), findsOneWidget);
    expect(find.textContaining('일부 버스 형상은 없어'), findsOneWidget);
    expect(find.textContaining('unavailable-provider'), findsNothing);
    expect(find.textContaining('pattern_shape_not_collected'), findsNothing);
    expect(find.textContaining('sha256:'), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: RouteGeometry(
            legs: [
              {
                'kind': 'bus',
                'geometryStatus': 'available',
                'geometry': null,
                'geometrySource': 'odsay',
              },
            ],
          ),
        ),
      ),
    );
    expect(find.textContaining('경로 형상이 없어'), findsOneWidget);
    expect(find.textContaining('출처:'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
