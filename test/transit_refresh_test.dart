import 'dart:convert';

import 'package:bus/data/bus_api.dart';
import 'package:bus/models/place.dart';
import 'package:bus/state/app_state.dart';
import 'package:bus/ui/pages/transit/transit_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  testWidgets('정류소 상세 새로고침은 예외 없이 최신 응답을 표시한다', (tester) async {
    var detailRequests = 0;
    final state =
        AppState(
          api: BusApi(
            baseUrl: 'https://api.example.test',
            accessToken: () async => 'test-token',
            client: MockClient((request) async {
              final Json body = switch (request.url.path) {
                '/api/v1/stops/nearby' => {
                  'items': [
                    {'id': '1', 'name': '대전역', 'straightDistanceM': 10},
                  ],
                },
                '/api/v1/stops/1' => {'stopNo': '${1000 + ++detailRequests}'},
                '/api/v1/stops/1/arrivals' => {
                  'dataStatus': {'availability': 'empty'},
                  'items': [],
                },
                '/api/v1/stops/1/routes' => {'items': []},
                _ => throw StateError(
                  'Unexpected request: ${request.url.path}',
                ),
              };
              return http.Response(
                jsonEncode(body),
                200,
                headers: {'content-type': 'application/json; charset=utf-8'},
              );
            }),
          ),
        )..setOrigin(
          const Place(
            id: 'origin',
            name: '출발지',
            address: '',
            latitude: 36.3315,
            longitude: 127.4335,
          ),
        );
    addTearDown(state.dispose);
    await tester.pumpWidget(
      AppScope(
        state: state,
        child: const MaterialApp(home: TransitPage()),
      ),
    );
    await tester.tap(find.text('출발지 주변 정류소 조회'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('대전역'));
    await tester.pumpAndSettle();
    expect(find.text('정류소 번호: 1001'), findsOneWidget);

    await tester.tap(find.byTooltip('최신 자료 조회'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(detailRequests, 2);
    expect(find.text('정류소 번호: 1002'), findsOneWidget);
    expect(find.text('정류소 번호: 1001'), findsNothing);
  });
}
