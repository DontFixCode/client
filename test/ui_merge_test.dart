import 'dart:async';

import 'package:bus/config/app_routes.dart';
import 'package:bus/data/bus_api.dart';
import 'package:bus/models/place.dart';
import 'package:bus/state/app_state.dart';
import 'package:bus/ui/pages/home/home_page.dart';
import 'package:bus/ui/pages/profile/profile_page.dart';
import 'package:bus/ui/pages/transit/transit_page.dart';
import 'package:bus/ui/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _PendingLogout extends AppState {
  _PendingLogout() {
    userName = '테스터';
    email = 'test@example.test';
  }

  final result = Completer<void>();

  @override
  Future<void> signOut() async {
    await result.future;
    await super.signOut();
  }
}

Future<void> _show(WidgetTester tester, AppState state, Widget page) async {
  tester.view.physicalSize = const Size(430, 1100);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(state.dispose);
  await tester.pumpWidget(
    AppScope(
      state: state,
      child: MaterialApp(
        theme: AppTheme.light,
        initialRoute: '/test',
        routes: {
          '/test': (_) => page,
          AppRoutes.welcome: (_) => const Scaffold(body: Text('시작 화면')),
        },
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'demo home shows the UI branch arrival rows with demo disclosure',
    (tester) async {
      await _show(
        tester,
        AppState(demoMode: true),
        const Scaffold(body: HomePage()),
      );
      expect(find.text('605'), findsOneWidget);
      expect(find.text('102'), findsOneWidget);
      expect(find.text('2정거장 전'), findsOneWidget);
      expect(find.text('1정거장 전'), findsOneWidget);
      expect(find.text('4분'), findsOneWidget);
      expect(find.text('2분'), findsOneWidget);
      expect(find.text('시연 데이터'), findsOneWidget);
      expect(find.text('정류소·노선 정보'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'real home keeps server transit navigation without demo arrivals',
    (tester) async {
      final state = AppState()
        ..setOrigin(
          const Place(
            id: 'test-origin',
            name: '출발지',
            address: '',
            latitude: 36.33,
            longitude: 127.43,
          ),
        );
      await _show(tester, state, const Scaffold(body: HomePage()));
      expect(find.text('605'), findsNothing);
      expect(find.text('2정거장 전'), findsNothing);
      expect(find.text('시연 데이터'), findsNothing);
      expect(find.text('로그인하고 서버 기능 이용하기'), findsOneWidget);
      await tester.ensureVisible(find.text('정류소·노선 정보'));
      await tester.tap(find.text('정류소·노선 정보'));
      await tester.pumpAndSettle();
      expect(find.byType(TransitPage), findsOneWidget);
      expect(find.text('출발지 주변 정류소 조회'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final success in [true, false]) {
    testWidgets(
      'logout waits; ${success ? 'success opens welcome' : 'failure stays on profile'}',
      (tester) async {
        final state = _PendingLogout();
        await _show(tester, state, const ProfilePage());
        final logout = find.widgetWithText(ListTile, '로그아웃');
        await tester.ensureVisible(logout);
        await tester.tap(logout);
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(TextButton, '로그아웃'));
        await tester.pumpAndSettle();

        expect(state.busy, isTrue);
        expect(find.byType(ProfilePage), findsOneWidget);
        expect(find.text('시작 화면'), findsNothing);
        if (success) {
          state.result.complete();
        } else {
          state.result.completeError(
            const ApiException('SIGN_OUT_FAILED', '로그아웃에 실패했어요.'),
          );
        }
        await tester.pumpAndSettle();
        expect(state.busy, isFalse);
        expect(state.isLoggedIn, !success);
        if (success) {
          expect(find.text('시작 화면'), findsOneWidget);
          expect(find.byType(ProfilePage), findsNothing);
          expect(
            tester.state<NavigatorState>(find.byType(Navigator)).canPop(),
            isFalse,
          );
        } else {
          expect(find.byType(ProfilePage), findsOneWidget);
          expect(find.text('시작 화면'), findsNothing);
          expect(find.text('로그아웃에 실패했어요.'), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
      },
    );
  }
}
