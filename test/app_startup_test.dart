import 'package:bus/app.dart';
import 'package:bus/state/app_state.dart';
import 'package:bus/ui/pages/auth/reset_password_page.dart';
import 'package:bus/ui/pages/main_page.dart';
import 'package:bus/ui/pages/splash_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _StartupState extends AppState {
  _StartupState({this.restored = false}) : super(demoMode: true);
  final bool restored;

  @override
  bool get hasServerSession => restored && !accountDeleted;

  void recoverPassword() {
    passwordRecovery = true;
    notifyListeners();
  }

  void markDeleted() {
    accountDeleted = true;
    passwordRecovery = false;
    notifyListeners();
  }
}

Future<void> _show(WidgetTester tester, _StartupState state) async {
  addTearDown(state.dispose);
  await tester.pumpWidget(BusroApp(state: state));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('복원된 인증 세션은 로그인 화면을 거치지 않고 홈으로 진입한다', (tester) async {
    await _show(tester, _StartupState(restored: true));
    expect(find.byType(MainPage), findsOneWidget);
    expect(find.text('로그인하고 시작하기'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('비로그인 시작은 환영 화면을 유지한다', (tester) async {
    await _show(tester, _StartupState());
    expect(find.byType(SplashPage), findsOneWidget);
    expect(find.byType(MainPage), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('복원 세션의 비밀번호 복구와 탈퇴 화면 전환을 유지한다', (tester) async {
    final state = _StartupState(restored: true);
    await _show(tester, state);
    expect(find.byType(MainPage), findsOneWidget);
    state.recoverPassword();
    await tester.pumpAndSettle();
    expect(find.byType(ResetPasswordPage), findsOneWidget);
    state.markDeleted();
    await tester.pumpAndSettle();
    expect(find.byType(SplashPage), findsOneWidget);
    expect(find.byType(MainPage, skipOffstage: false), findsNothing);
    expect(find.byType(ResetPasswordPage, skipOffstage: false), findsNothing);
    expect(
      tester.state<NavigatorState>(find.byType(Navigator)).canPop(),
      isFalse,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
