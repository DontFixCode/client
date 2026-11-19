import 'dart:convert';
import 'dart:ui' show Size;

import 'package:bus/data/bus_api.dart';
import 'package:bus/models/place.dart';
import 'package:bus/ui/widgets/route_map_data.dart';
import 'package:flutter_test/flutter_test.dart';

Json _line(List<dynamic> coordinates) => {
  'type': 'LineString',
  'coordinates': coordinates,
};

void main() {
  const coordinates = [
    [127.38, 36.35],
    [127.43, 36.33],
  ];

  test('대전 경로 카메라는 실제 뷰 크기로 계산하며 먼 목적지도 제외하지 않는다', () {
    final data = RouteMapData.fromLegs([
      {'kind': 'walk', 'geometry': _line(coordinates)},
    ]);
    final camera = data.cameraFor(const Size(360, 280))!;
    expect(camera.center.dx, closeTo(127.405, .00001));
    expect(camera.center.dy, closeTo(36.34, .00001));
    expect(camera.zoomLevel, inInclusiveRange(12, 14));
    expect(data.cameraFor(Size.zero), isNull);
    expect(data.cameraFor(const Size(1, 1)), isNull);
    expect(
      data.cameraFor(const Size(200, 280))!.zoomLevel,
      lessThan(camera.zoomLevel),
    );
    final longRoute = RouteMapData.fromLegs([
      {
        'kind': 'walk',
        'geometry': _line([
          ...coordinates,
          [129.0756, 35.1796],
        ]),
      },
    ]).cameraFor(const Size(360, 280))!;
    expect(longRoute.zoomLevel, lessThan(camera.zoomLevel));
    expect(longRoute.center.dx, greaterThan(128));
  });

  test('확보된 버스 형상과 사용 가능한 도보만 경도·위도 순서로 읽는다', () {
    final geometry = _line(coordinates);
    final data = RouteMapData.fromLegs([
      for (final status in ['available', 'unavailable', 'error', null])
        {'kind': 'bus', 'geometryStatus': status, 'geometry': geometry},
      {'kind': 'walk', 'status': 'available', 'geometry': geometry},
      {'kind': 'walk', 'status': 'unavailable', 'geometry': geometry},
      {'kind': 'walk', 'geometry': geometry},
    ]);

    expect(data.lines, hasLength(3));
    expect(data.lines.map((line) => line.walking), [false, true, true]);
    for (final line in data.lines) {
      expect(line.points, [
        const Offset(127.38, 36.35),
        const Offset(127.43, 36.33),
      ]);
    }
  });

  test('GeoJSON 포장 형식을 읽되 서로 떨어진 선을 연결하지 않는다', () {
    final first = _line(coordinates);
    const secondCoordinates = [
      [127.45, 36.31],
      [127.46, 36.32],
    ];
    final second = _line(secondCoordinates);
    final data = RouteMapData.fromLegs([
      {
        'kind': 'walk',
        'geometry': {'type': 'Feature', 'geometry': first},
      },
      {
        'kind': 'walk',
        'geometry': {
          'type': 'FeatureCollection',
          'features': [
            {
              'type': 'Feature',
              'geometry': {
                'type': 'MultiLineString',
                'coordinates': [coordinates, secondCoordinates],
              },
            },
          ],
        },
      },
      {
        'kind': 'walk',
        'geometry': {
          'type': 'GeometryCollection',
          'geometries': [first, second],
        },
      },
    ]);

    expect(data.lines, hasLength(5));
    expect(data.lines.map((line) => line.points.first), [
      const Offset(127.38, 36.35),
      const Offset(127.38, 36.35),
      const Offset(127.45, 36.31),
      const Offset(127.38, 36.35),
      const Offset(127.45, 36.31),
    ]);
    expect(data.lines.every((line) => line.points.length == 2), isTrue);
  });

  test('잘못된 좌표는 선을 끊고 인접 중복·한 점 구간은 그리지 않는다', () {
    for (final invalid in <dynamic>[
      [181, 36],
      [-181, 36],
      [127, 91],
      [127, -91],
      [double.nan, 36],
      [127, double.infinity],
      null,
      <num>[],
      [127],
      ['127', 36],
    ]) {
      final data = RouteMapData.fromLegs([
        {
          'kind': 'walk',
          'geometry': _line([
            [127.38, 36.35],
            [127.38, 36.35],
            [127.39, 36.34],
            invalid,
            [127.41, 36.32],
            [127.41, 36.32],
            [127.43, 36.33],
          ]),
        },
      ]);
      expect(data.lines.map((line) => line.points), [
        [const Offset(127.38, 36.35), const Offset(127.39, 36.34)],
        [const Offset(127.41, 36.32), const Offset(127.43, 36.33)],
      ], reason: 'invalid point: $invalid');
    }

    final isolated = RouteMapData.fromLegs([
      {
        'kind': 'walk',
        'geometry': _line([
          [127.38, 36.35],
          [127.38, 36.35],
          null,
          [127.43, 36.33],
        ]),
      },
    ]);
    expect(isolated.lines, isEmpty);
  });

  test('출발·도착과 같은 위치의 승하차·환승 마커를 이름과 함께 합친다', () {
    final data = RouteMapData.fromLegs(
      [
        {
          'kind': 'bus',
          'route': {'routeNo': '707'},
          'board': {
            'name': '시청',
            'location': {'latitude': 36.35, 'longitude': 127.38},
          },
          'alight': {
            'name': '환승 정류장',
            'location': {'latitude': 36.34, 'longitude': 127.40},
          },
        },
        {
          'kind': 'bus',
          'route': {'routeNo': '102'},
          'board': {
            'name': '환승 정류장',
            'location': {'latitude': 36.34, 'longitude': 127.40},
          },
          'alight': {
            'name': '대전역',
            'location': {'latitude': 36.33, 'longitude': 127.43},
          },
        },
      ],
      origin: const Place(
        id: 'origin',
        name: '출발 장소',
        address: '',
        latitude: 36.35,
        longitude: 127.38,
      ),
      destination: const Place(
        id: 'destination',
        name: '도착 장소',
        address: '',
        latitude: 36.33,
        longitude: 127.43,
      ),
    );

    expect(data.markers, hasLength(3));
    final origin = data.markers.singleWhere(
      (m) => m.point == const Offset(127.38, 36.35),
    );
    expect(origin.endpoint, RouteEndpoint.departure);
    expect(
      origin.label,
      allOf(
        contains('출발 장소'),
        contains('707'),
        contains('승차'),
        contains('시청'),
        contains('\n'),
      ),
    );
    final transfer = data.markers.singleWhere(
      (m) => m.point == const Offset(127.40, 36.34),
    );
    expect(transfer.endpoint, isNull);
    expect(
      transfer.label,
      allOf(
        contains('707'),
        contains('하차'),
        contains('102'),
        contains('승차'),
        contains('환승 정류장'),
        contains('\n'),
      ),
    );
    final destination = data.markers.singleWhere(
      (m) => m.point == const Offset(127.43, 36.33),
    );
    expect(destination.endpoint, RouteEndpoint.arrival);
    expect(
      destination.label,
      allOf(
        contains('도착 장소'),
        contains('102'),
        contains('하차'),
        contains('대전역'),
        contains('\n'),
      ),
    );
  });

  test('출발과 도착 좌표가 같으면 두 역할을 하나의 마커에 표시한다', () {
    const place = Place(
      id: 'station',
      name: '대전역',
      address: '',
      latitude: 36.33,
      longitude: 127.43,
    );
    final data = RouteMapData.fromLegs([], origin: place, destination: place);

    expect(data.markers.single.endpoint, RouteEndpoint.both);
    expect(data.markers.single.label, '출발 · 대전역\n도착 · 대전역');
  });

  test('누락되거나 범위 밖인 출발·도착·정류장 좌표는 마커로 만들지 않는다', () {
    final data = RouteMapData.fromLegs(
      [
        {
          'kind': 'bus',
          'route': {'routeNo': '707'},
          'board': {
            'name': '잘못된 위치',
            'location': {'latitude': double.nan, 'longitude': 127.38},
          },
          'alight': {
            'name': '범위 밖 위치',
            'location': {'latitude': 36.33, 'longitude': 181},
          },
        },
      ],
      origin: const Place(
        id: 'origin',
        name: '범위 밖 출발',
        address: '',
        latitude: 91,
        longitude: 127.38,
      ),
      destination: const Place(
        id: 'destination',
        name: '좌표 없는 도착',
        address: '',
      ),
    );
    expect(data.markers, isEmpty);
  });

  test('내용이 같은 새 응답은 동일한 fingerprint이며 선·마커 변경은 구분한다', () {
    final legs = <Json>[
      {'kind': 'walk', 'geometry': _line(coordinates)},
    ];
    const origin = Place(
      id: 'origin',
      name: '시청',
      address: '',
      latitude: 36.35,
      longitude: 127.38,
    );
    final first = RouteMapData.fromLegs(legs, origin: origin);
    final copied = (jsonDecode(jsonEncode(legs)) as List).cast<Json>();
    expect(
      RouteMapData.fromLegs(
        copied,
        origin: Place.fromJson(origin.toJson()),
      ).fingerprint,
      first.fingerprint,
    );
    copied.single['geometry']['coordinates'][1] = [127.44, 36.33];
    expect(
      RouteMapData.fromLegs(copied, origin: origin).fingerprint,
      isNot(first.fingerprint),
    );
    expect(
      RouteMapData.fromLegs(
        legs,
        origin: Place.fromJson({...origin.toJson(), 'name': '변경한 출발지'}),
      ).fingerprint,
      isNot(first.fingerprint),
    );
  });
}
