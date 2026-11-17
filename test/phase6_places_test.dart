import 'dart:async';
import 'dart:convert';

import 'package:bus/config/app_routes.dart';
import 'package:bus/data/bus_api.dart';
import 'package:bus/models/place.dart';
import 'package:bus/state/app_state.dart';
import 'package:bus/ui/pages/home/home_page.dart';
import 'package:bus/ui/pages/routes/route_results_page.dart';
import 'package:bus/ui/pages/search/place_search_page.dart';
import 'package:bus/ui/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _origin = Place(
  id: 'origin',
  name: '대전역',
  address: '대전 동구 중앙로 215',
  latitude: 36.3315,
  longitude: 127.4335,
);
const Json _keywordPlace = {
  'name': '대전광역시청',
  'address': '대전 서구 둔산로 100',
  'latitude': 36.3504119,
  'longitude': 127.3845475,
  'provider': 'kakao',
  'externalId': 'place-123',
};
const Json _addressPlace = {
  'name': '대전 서구 둔산로 100',
  'address': '대전 서구 둔산로 100',
  'latitude': 36.3504119,
  'longitude': 127.3845475,
  'provider': 'kakao',
  'externalId': null,
};

http.Response _json(Json body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

AppState _state(MockClient client) => AppState(
  api: BusApi(
    baseUrl: 'https://api.example.test',
    accessToken: () async => 'test-token',
    client: client,
  ),
);

Future<void> _show(WidgetTester tester, AppState state, Widget page) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    AppScope(
      state: state,
      child: MaterialApp(
        theme: AppTheme.light,
        home: page,
        routes: {AppRoutes.results: (_) => const RouteResultsPage()},
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  for (final entry in {
    'keyword': _keywordPlace,
    'address': _addressPlace,
  }.entries) {
    testWidgets(
      'Kakao ${entry.key} selection preserves route search location',
      (tester) async {
        final response = Completer<http.Response>();
        Json? routeRequest;
        final state = _state(
          MockClient((request) async {
            expect(request.headers['authorization'], 'Bearer test-token');
            if (request.url.path == '/api/v1/places/search') {
              expect(request.method, 'GET');
              expect(request.url.queryParameters['q'], '대전 시청');
              return response.future;
            }
            if (request.url.path == '/api/v1/route-searches') {
              expect(request.method, 'POST');
              routeRequest = jsonDecode(request.body) as Json;
              return _json({'searchId': 'search-1'}, 202);
            }
            expect(request.url.path, '/api/v1/route-searches/search-1');
            expect(request.method, 'GET');
            return _json({
              'searchId': 'search-1',
              'status': 'no_path',
              'candidates': [],
            });
          }),
        )..setOrigin(_origin);
        addTearDown(state.dispose);
        await _show(tester, state, const Scaffold(body: HomePage()));

        await tester.tap(find.text('도착지를 입력해 주세요'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), '  대전 시청  ');
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.text('검색 중…'), findsOneWidget);
        expect(find.text('검색 결과 0개'), findsNothing);

        response.complete(
          _json({
            'items': [entry.value],
          }),
        );
        await tester.pumpAndSettle();
        expect(find.text('검색 결과 1개'), findsOneWidget);
        expect(find.text('주요 장소\n${entry.value['address']}'), findsOneWidget);
        await tester.tap(find.text(entry.value['name'] as String));
        await tester.pumpAndSettle();

        expect(state.destination?.name, entry.value['name']);
        expect(state.destination?.address, entry.value['address']);
        expect(state.destination?.provider, 'kakao');
        expect(state.destination?.externalId, entry.value['externalId']);
        await tester.tap(find.byKey(const ValueKey('searchRoutesButton')));
        await tester.pumpAndSettle();
        expect(routeRequest?['origin'], _origin.toJson());
        expect(
          routeRequest?['destination'],
          Map<String, dynamic>.from(entry.value)
            ..removeWhere((_, value) => value == null),
        );
        expect(state.searchError, isNull);
        expect(state.searchResult?['status'], 'no_path');
        expect(find.text('경로 비교'), findsOneWidget);
      },
    );
  }

  testWidgets('place provider errors can retry and empty searches can change', (
    tester,
  ) async {
    final queries = <String>[];
    final state = _state(
      MockClient((request) async {
        expect(request.url.path, '/api/v1/places/search');
        queries.add(request.url.queryParameters['q']!);
        return switch (queries.length) {
          1 => _json({
            'error': {
              'code': 'PLACES_UNAVAILABLE',
              'message': '장소 검색 제공처에 일시적으로 연결할 수 없습니다.',
            },
          }, 503),
          2 => _json({'items': []}),
          _ => _json({
            'items': [_keywordPlace],
          }),
        };
      }),
    );
    addTearDown(state.dispose);
    await _show(tester, state, const PlaceSearchPage(isOrigin: false));
    expect(find.text('검색할 장소를 입력해 주세요'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '대전');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.text('장소 검색을 사용할 수 없어요'), findsOneWidget);
    expect(
      find.text('장소 검색에 일시적으로 연결할 수 없어요. 잠시 후 다시 시도하거나 좌표를 직접 입력해 주세요.'),
      findsOneWidget,
    );
    expect(find.text('검색 결과 0개'), findsNothing);

    await tester.tap(find.text('다시 시도'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(queries, ['대전', '대전']);
    expect(find.text('장소 검색을 사용할 수 없어요'), findsNothing);
    expect(find.text('일치하는 장소가 없어요'), findsOneWidget);
    expect(find.text('검색 결과 0개'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '대전시청');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(queries, ['대전', '대전', '대전시청']);
    expect(find.text('대전광역시청'), findsOneWidget);
    expect(find.text('검색 결과 1개'), findsOneWidget);
  });
}
