import 'dart:convert';

import 'package:bus/app.dart';
import 'package:bus/config/app_routes.dart';
import 'package:bus/data/bus_api.dart';
import 'package:bus/models/place.dart';
import 'package:bus/state/app_state.dart';
import 'package:bus/ui/pages/profile/profile_page.dart';
import 'package:bus/ui/pages/splash_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Future<NavigatorState> _openProfile(WidgetTester tester, AppState state) async {
  tester.view.physicalSize = const Size(360, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(state.dispose);
  state.setOrigin(const Place(id: 'test', name: '테스트 출발지', address: ''));
  await tester.pumpWidget(BusroApp(state: state));
  await tester.pumpAndSettle();
  final navigator = tester.state<NavigatorState>(find.byType(Navigator));
  navigator.pushNamed(AppRoutes.main);
  await tester.pumpAndSettle();
  await tester.tap(find.byType(NavigationDestination).at(2));
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(
    find.widgetWithText(TextButton, '회원 탈퇴'),
    300,
    scrollable: find.descendant(
      of: find.byType(ProfilePage),
      matching: find.byType(Scrollable),
    ),
  );
  return navigator;
}

http.Response _json(Json data, int status) => http.Response(
  jsonEncode(data),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

void main() {
  testWidgets('탈퇴 확인 취소는 요청하지 않고 202 pending 접수는 이전 화면을 지우고 시작 화면으로 이동한다', (
    tester,
  ) async {
    final requests = <http.Request>[];
    final state = AppState(
      api: BusApi(
        accessToken: () async => 'test-token',
        client: MockClient((request) async {
          requests.add(request);
          expect(request.method, 'DELETE');
          expect(request.url.path, '/api/v1/me');
          expect(request.headers['authorization'], 'Bearer test-token');
          return _json({
            'displayUserId': 'test-user_deleted',
            'deletedAt': '2026-11-17T03:00:00Z',
            'authBlockStatus': 'pending',
            'authBlockedAt': null,
            'cancelledJourneyIds': [],
          }, 202);
        }),
      ),
    )..userName = 'tester';
    final navigator = await _openProfile(tester, state);
    expect(navigator.canPop(), isTrue);
    await tester.tap(find.widgetWithText(TextButton, '회원 탈퇴'));
    await tester.pumpAndSettle();
    expect(find.text('회원 탈퇴할까요?'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, '취소'));
    await tester.pumpAndSettle();
    expect(requests, isEmpty);
    expect(state.isLoggedIn, isTrue);

    await tester.tap(find.widgetWithText(TextButton, '회원 탈퇴'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, '탈퇴하기'));
    await tester.pumpAndSettle();
    expect(requests, hasLength(1));
    expect(state.accountDeleted, isTrue);
    expect(state.isLoggedIn, isFalse);
    expect(find.byType(SplashPage), findsOneWidget);
    expect(find.byType(ProfilePage, skipOffstage: false), findsNothing);
    expect(navigator.canPop(), isFalse);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('탈퇴 API가 실패하면 계정과 내정보 화면을 유지하고 실패를 알린다', (tester) async {
    var requests = 0;
    final state = AppState(
      api: BusApi(
        accessToken: () async => 'test-token',
        client: MockClient((request) async {
          requests++;
          expect(request.method, 'DELETE');
          expect(request.url.path, '/api/v1/me');
          return _json({
            'error': {
              'code': 'SERVER_UNAVAILABLE',
              'message': '탈퇴 접수를 처리하지 못했어요.',
            },
          }, 503);
        }),
      ),
    )..userName = 'tester';
    final navigator = await _openProfile(tester, state);
    await tester.tap(find.widgetWithText(TextButton, '회원 탈퇴'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, '탈퇴하기'));
    await tester.pumpAndSettle();
    expect(requests, 1);
    expect(state.accountDeleted, isFalse);
    expect(state.userName, 'tester');
    expect(state.busy, isFalse);
    expect(find.byType(ProfilePage), findsOneWidget);
    expect(find.text('탈퇴 접수를 처리하지 못했어요.'), findsOneWidget);
    expect(navigator.canPop(), isTrue);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
