import 'dart:convert';

import 'package:bus/data/bus_api.dart';
import 'package:bus/models/place.dart';
import 'package:bus/models/travel_route.dart';
import 'package:bus/state/app_state.dart';
import 'package:bus/ui/pages/routes/route_detail_page.dart';
import 'package:bus/ui/pages/search/place_search_page.dart';
import 'package:bus/ui/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Future<void> _show(
  WidgetTester tester,
  Widget page, {
  required Size size,
  double scale = 1,
  double keyboard = 0,
  AppState? appState,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetViewInsets);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  final state = appState ?? AppState();
  addTearDown(state.dispose);
  await tester.pumpWidget(
    AppScope(
      state: state,
      child: MaterialApp(theme: AppTheme.light, home: page),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('작은 화면의 큰 글자에서도 배차간격 예상 경로 상세가 넘치지 않는다', (tester) async {
    const origin = Place(id: 'origin', name: '대전역', address: '');
    const destination = Place(id: 'destination', name: '대전시청', address: '');
    final route = TravelRoute.fromJson(
      {
        'candidateId': 'candidate',
        'estimated': true,
        'legs': [
          {
            'kind': 'bus',
            'legIndex': 1,
            'route': {'id': '1', 'routeNo': '605'},
            'board': {'name': '대전역'},
            'alight': {'name': '대전시청'},
          },
        ],
      },
      searchId: 'search',
      origin: origin,
      destination: destination,
      recommendedId: 'candidate',
    );
    await _show(
      tester,
      RouteDetailPage(route: route),
      size: const Size(320, 740),
      scale: 1.3,
    );
    expect(find.text('배차간격 기반 예상'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('작은 화면에서 키보드가 열려도 출발지 검색이 넘치지 않는다', (tester) async {
    await _show(
      tester,
      const PlaceSearchPage(isOrigin: true),
      size: const Size(320, 568),
      keyboard: 300,
    );
    expect(find.byType(TextField), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('키보드가 열린 작은 화면에서도 검색 결과를 스크롤해 선택할 수 있다', (tester) async {
    final state = AppState(
      api: BusApi(
        accessToken: () async => 'test-token',
        client: MockClient((request) async {
          expect(request.url.path, '/api/v1/places/search');
          expect(request.url.queryParameters['q'], '시청');
          return http.Response(
            jsonEncode({
              'items': [
                {
                  'name': '대전광역시청',
                  'address': '대전 서구 둔산로 100',
                  'latitude': 36.3504,
                  'longitude': 127.3845,
                  'provider': 'kakao',
                  'externalId': 'city-hall',
                },
              ],
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      ),
    );
    Place? selected;
    await _show(
      tester,
      Scaffold(
        body: Builder(
          builder: (context) => FilledButton(
            onPressed: () async {
              selected = await Navigator.push<Place>(
                context,
                MaterialPageRoute(
                  builder: (_) => const PlaceSearchPage(isOrigin: true),
                ),
              );
            },
            child: const Text('출발지 선택'),
          ),
        ),
      ),
      size: const Size(320, 568),
      scale: 1.3,
      keyboard: 300,
      appState: state,
    );
    await tester.tap(find.text('출발지 선택'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '시청');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('대전광역시청'),
      100,
      scrollable: find
          .descendant(
            of: find.byType(PlaceSearchPage),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(tester.view.viewInsets.bottom, 300);
    await tester.tap(find.text('대전광역시청'));
    await tester.pumpAndSettle();
    expect(selected?.name, '대전광역시청');
    expect(selected?.externalId, 'city-hall');
    expect(selected?.latitude, 36.3504);
    expect(find.text('출발지 선택'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
