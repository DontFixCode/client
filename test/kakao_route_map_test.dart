import 'dart:convert';

import 'package:bus/config/backend_config.dart';
import 'package:bus/data/bus_api.dart';
import 'package:bus/models/place.dart';
import 'package:bus/ui/widgets/kakao_place_map.dart';
import 'package:bus/ui/widgets/kakao_route_map.dart';
import 'package:bus/ui/widgets/route_geometry.dart';
import 'package:bus/ui/widgets/route_map_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kakao_map_sdk/kakao_map_sdk.dart' as kakao;

class _MapConfig extends CachingAssetBundle {
  _MapConfig([this.keyValue = 'public-test-native-key']);
  final String keyValue;

  @override
  Future<ByteData> load(String key) async => ByteData.sublistView(
    Uint8List.fromList(utf8.encode(jsonEncode({'KAKAO_NATIVE_KEY': keyValue}))),
  );
}

void main() {
  const sdkChannel = MethodChannel('flutter_kakao_maps_sdk');
  const legs = <Json>[
    {
      'kind': 'bus',
      'geometryStatus': 'available',
      'geometry': {
        'type': 'LineString',
        'coordinates': [
          [127.38, 36.35],
          [127.43, 36.33],
        ],
      },
    },
  ];
  const origin = Place(
    id: 'origin',
    name: '시청',
    address: '',
    latitude: 36.35,
    longitude: 127.38,
  );
  Widget screen(List<Json> legs, {bool withOrigin = true}) => MaterialApp(
    home: Scaffold(
      body: RouteGeometry(legs: legs, origin: withOrigin ? origin : null),
    ),
  );

  Future<List<MethodCall>> prepare(
    WidgetTester tester, {
    bool configured = true,
  }) async {
    final messenger = tester.binding.defaultBinaryMessenger;
    final platformCalls = <MethodCall>[];
    messenger.setMockMethodCallHandler(sdkChannel, (_) async => null);
    messenger.setMockMethodCallHandler(SystemChannels.platform_views, (
      call,
    ) async {
      platformCalls.add(call);
      return null;
    });
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await BackendConfig.load(bundle: _MapConfig(''));
      await KakaoPlaceMap.initialize();
      messenger.setMockMethodCallHandler(sdkChannel, null);
      messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
    });
    await BackendConfig.load(
      bundle: _MapConfig(configured ? 'public-test-native-key' : ''),
    );
    await KakaoPlaceMap.initialize();
    return platformCalls;
  }

  testWidgets('SDK 지도 오류가 나면 오류 안내를 표시하고 가상 경로를 그리지 않는다', (tester) async {
    await prepare(tester);
    await tester.pumpWidget(screen(legs));
    await tester.pump();
    expect(find.byType(UiKitView), findsOneWidget);

    tester.widget<kakao.KakaoMap>(find.byType(kakao.KakaoMap)).onMapError!(
      kakao.KakaoMapError('test', '지도 로딩 실패'),
    );
    await tester.pump();

    expect(find.byType(kakao.KakaoMap), findsNothing);
    expect(find.text('카카오 지도를 불러오지 못했어요'), findsOneWidget);
    expect(find.text('아래 정류소·이동 순서로 계속 확인할 수 있어요.'), findsOneWidget);
    expect(find.textContaining('선택한 경로'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(RouteGeometry),
        matching: find.byType(CustomPaint),
      ),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant({TargetPlatform.iOS}));

  testWidgets('SDK를 사용할 수 없어도 가상 지도 대신 오류 안내를 표시한다', (tester) async {
    final calls = await prepare(tester, configured: false);
    await tester.pumpWidget(screen(legs));
    await tester.pump();

    expect(find.byType(UiKitView), findsNothing);
    expect(find.text('카카오 지도를 불러오지 못했어요'), findsOneWidget);
    expect(find.text('아래 정류소·이동 순서로 계속 확인할 수 있어요.'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(RouteGeometry),
        matching: find.byType(CustomPaint),
      ),
      findsNothing,
    );
    expect(calls.where((call) => call.method == 'create'), isEmpty);
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant({TargetPlatform.iOS}));

  testWidgets('출발·도착 장소가 없어도 노선 형상을 카카오 지도에 표시한다', (tester) async {
    final calls = await prepare(tester);
    await tester.pumpWidget(screen(legs, withOrigin: false));
    await tester.pump();

    expect(find.byType(KakaoRouteMap), findsOneWidget);
    expect(find.byType(UiKitView), findsOneWidget);
    expect(calls.where((call) => call.method == 'create'), hasLength(1));
    expect(
      tester
          .widget<kakao.KakaoMap>(find.byType(kakao.KakaoMap))
          .option!
          .position,
      const kakao.LatLng(36.35, 127.38),
    );
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant({TargetPlatform.iOS}));

  testWidgets('경로 좌표가 없으면 대전 배경 지도를 생성한다', (tester) async {
    final calls = await prepare(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 280,
            child: KakaoRouteMap(
              data: RouteMapData.fromLegs(const []),
              fallback: const Text('지도 오류'),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(UiKitView), findsOneWidget);
    expect(find.text('지도 오류'), findsNothing);
    expect(calls.where((call) => call.method == 'create'), hasLength(1));
    expect(
      tester
          .widget<kakao.KakaoMap>(find.byType(kakao.KakaoMap))
          .option!
          .position,
      const kakao.LatLng(36.3324, 127.4342),
    );
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant({TargetPlatform.iOS}));

  testWidgets('같은 내용으로 부모가 갱신되면 지도를 유지하고 경로 변경 때만 다시 만든다', (tester) async {
    final calls = await prepare(tester);
    await tester.pumpWidget(screen(legs));
    await tester.pump();
    final mapState = tester.state(find.byType(KakaoRouteMap));
    final nativeMapState = tester.state(find.byType(kakao.KakaoMap));
    expect(calls.where((call) => call.method == 'create'), hasLength(1));

    final copied = (jsonDecode(jsonEncode(legs)) as List).cast<Json>();
    await tester.pumpWidget(screen(copied));
    await tester.pump();
    expect(tester.state(find.byType(KakaoRouteMap)), same(mapState));
    expect(tester.state(find.byType(kakao.KakaoMap)), same(nativeMapState));
    expect(calls.where((call) => call.method == 'create'), hasLength(1));

    copied.single['geometry']['coordinates'][1] = [127.44, 36.33];
    await tester.pumpWidget(screen(copied));
    await tester.pump();
    expect(tester.state(find.byType(KakaoRouteMap)), isNot(same(mapState)));
    expect(
      tester.state(find.byType(kakao.KakaoMap)),
      isNot(same(nativeMapState)),
    );
    expect(mapState.mounted, isFalse);
    expect(calls.where((call) => call.method == 'create'), hasLength(2));
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant({TargetPlatform.iOS}));
}
