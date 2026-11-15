import 'dart:async';

import 'package:bus/data/bus_api.dart';
import 'package:bus/models/place.dart';
import 'package:bus/state/app_state.dart';
import 'package:bus/ui/pages/home/home_page.dart';
import 'package:bus/ui/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _gps = Place(
  id: 'gps',
  name: '현재 위치',
  address: 'GPS로 확인한 위치',
  latitude: 36.33,
  longitude: 127.43,
);
const _manual = Place(
  id: 'manual',
  name: '선택한 출발지',
  address: '',
  latitude: 36.35,
  longitude: 127.38,
);

class _LocationState extends AppState {
  _LocationState({super.demoMode});
  Completer<Place> location = Completer<Place>();
  int calls = 0;
  bool? sharedWithJourney;

  @override
  Future<Place> currentLocation({bool shareWithJourney = true}) {
    calls++;
    sharedWithJourney = shareWithJourney;
    return location.future;
  }
}

Future<void> _showHome(WidgetTester tester, AppState state) async {
  addTearDown(state.dispose);
  await tester.pumpWidget(
    AppScope(
      state: state,
      child: MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(body: HomePage()),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets(
    'home locates once without blocking actions or sharing a journey',
    (tester) async {
      final state = _LocationState()..journey = {'journeyId': 'active'};
      await _showHome(tester, state);
      expect(state.calls, 1);
      expect(state.sharedWithJourney, isFalse);
      expect(state.busy, isFalse);
      expect(find.text('현재 위치를 찾는 중…'), findsOneWidget);

      state.setDestination(_manual);
      await tester.pump();
      expect(state.calls, 1);
      state.location.complete(_gps);
      await tester.pumpAndSettle();
      expect(state.origin, same(_gps));
      expect(find.text('현재 위치'), findsOneWidget);
      expect(state.locatingOrigin, isFalse);
    },
  );

  testWidgets(
    'denied location keeps manual selection and only retries on tap',
    (tester) async {
      final state = _LocationState();
      await _showHome(tester, state);
      state.location.completeError(
        const ApiException('LOCATION_DENIED', '위치 권한이 필요해요.'),
      );
      await tester.pumpAndSettle();
      expect(state.origin.id, 'unset');
      expect(find.text('출발지를 선택해 주세요'), findsOneWidget);
      expect(find.text('위치 권한이 필요해요.'), findsOneWidget);
      await state.locateOrigin();
      expect(state.calls, 1);

      state.location = Completer<Place>();
      await tester.ensureVisible(find.text('다시 찾기'));
      await tester.tap(find.text('다시 찾기'));
      await tester.pump();
      expect(state.calls, 2);
      state.location.complete(_gps);
      await tester.pumpAndSettle();
      expect(state.origin, same(_gps));
      expect(find.text('위치 권한이 필요해요.'), findsNothing);
    },
  );

  test('late GPS never overwrites a manually selected origin', () async {
    final state = _LocationState();
    addTearDown(state.dispose);
    final locating = state.locateOrigin();
    state.setOrigin(_manual);
    state.location.complete(_gps);
    await locating;
    expect(state.origin, same(_manual));
  });

  testWidgets('demo and preselected origins never trigger automatic GPS', (
    tester,
  ) async {
    final demo = _LocationState(demoMode: true);
    await _showHome(tester, demo);
    expect(demo.calls, 0);
    final selected = _LocationState()..setOrigin(_manual);
    addTearDown(selected.dispose);
    await selected.locateOrigin();
    expect(selected.calls, 0);
    expect(selected.origin, same(_manual));
  });
}
