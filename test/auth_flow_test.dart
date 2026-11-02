import 'package:bus/config/app_routes.dart';
import 'package:bus/state/app_state.dart';
import 'package:bus/ui/pages/auth/forgot_password_page.dart';
import 'package:bus/ui/pages/auth/login_page.dart';
import 'package:bus/ui/pages/auth/signup_page.dart';
import 'package:bus/ui/pages/profile/profile_page.dart';
import 'package:bus/ui/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _showAuth(WidgetTester tester, AppState state, Widget page) async {
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
        home: page,
        routes: {
          AppRoutes.main: (_) => const ProfilePage(),
          AppRoutes.login: (_) => const LoginPage(),
          AppRoutes.signup: (_) => const SignupPage(),
          AppRoutes.forgotPassword: (_) => const ForgotPasswordPage(),
        },
      ),
    ),
  );
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('login rejects malformed email and a short password', (
    tester,
  ) async {
    final state = AppState();
    await _showAuth(tester, state, const LoginPage());
    await tester.enterText(find.byType(TextFormField).at(0), 'invalid-email');
    await tester.enterText(find.byType(TextFormField).at(1), '1234');
    await _tap(tester, find.widgetWithText(FilledButton, '로그인'));

    expect(find.text('이메일 주소를 다시 확인해 주세요.'), findsOneWidget);
    expect(find.text('비밀번호는 8자 이상 입력해 주세요.'), findsOneWidget);
    expect(state.isLoggedIn, isFalse);
  });

  testWidgets(
    'signup requires matching passwords and both notices before creating a demo session',
    (tester) async {
      final state = AppState();
      await _showAuth(tester, state, const SignupPage());
      await tester.enterText(find.byType(TextFormField).at(0), '대전 여행자');
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'traveler@example.com',
      );
      await tester.enterText(find.byType(TextFormField).at(2), 'busro1234');
      await tester.enterText(find.byType(TextFormField).at(3), 'different1234');
      await _tap(tester, find.widgetWithText(FilledButton, '가입하고 시작하기'));

      expect(find.text('비밀번호가 일치하지 않아요.'), findsOneWidget);
      expect(find.text('필수 안내를 확인하고 동의해 주세요.'), findsOneWidget);
      expect(state.isLoggedIn, isFalse);

      await tester.enterText(find.byType(TextFormField).at(3), 'busro1234');
      await _tap(tester, find.widgetWithText(FilledButton, '가입하고 시작하기'));
      expect(state.isLoggedIn, isFalse);
      expect(find.text('필수 안내를 확인하고 동의해 주세요.'), findsOneWidget);

      await _tap(tester, find.byType(Checkbox).at(0));
      await _tap(tester, find.widgetWithText(FilledButton, '가입하고 시작하기'));
      expect(state.isLoggedIn, isFalse);

      await _tap(tester, find.byType(Checkbox).at(1));
      await _tap(tester, find.widgetWithText(FilledButton, '가입하고 시작하기'));

      expect(state.isLoggedIn, isTrue);
      expect(state.userName, '대전 여행자');
      expect(state.email, 'traveler@example.com');
      expect(find.byType(ProfilePage), findsOneWidget);
      expect(find.text('대전 여행자님'), findsOneWidget);
      expect(find.text('traveler@example.com'), findsOneWidget);
      expect(find.byType(TextFormField), findsNothing);
    },
  );

  testWidgets('valid login opens the profile with the local demo identity', (
    tester,
  ) async {
    final state = AppState();
    await _showAuth(tester, state, const LoginPage());
    await tester.enterText(
      find.byType(TextFormField).at(0),
      'busro@example.com',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'busro1234');
    await _tap(tester, find.widgetWithText(FilledButton, '로그인'));

    expect(state.isLoggedIn, isTrue);
    expect(state.userName, 'busro');
    expect(state.email, 'busro@example.com');
    expect(find.byType(ProfilePage), findsOneWidget);
    expect(find.text('busro님'), findsOneWidget);
  });

  testWidgets(
    'profile name edit saves, reopens with saved text and preserves it on cancel',
    (tester) async {
      final state = AppState()
        ..signIn(name: '초록 여행자', email: 'traveler@example.com');
      await _showAuth(tester, state, const ProfilePage());
      await _tap(tester, find.byTooltip('이름 변경'));
      expect(
        tester.widget<TextFormField>(find.byType(TextFormField)).initialValue,
        '초록 여행자',
      );

      await tester.enterText(find.byType(TextFormField), '   ');
      await _tap(tester, find.widgetWithText(TextButton, '저장'));
      expect(find.text('이름을 입력해 주세요.'), findsOneWidget);
      expect(state.userName, '초록 여행자');

      await tester.enterText(find.byType(TextFormField), '하루');
      await _tap(tester, find.widgetWithText(TextButton, '저장'));
      expect(state.userName, '하루');
      expect(find.text('하루님'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await _tap(tester, find.byTooltip('이름 변경'));
      expect(
        tester.widget<TextFormField>(find.byType(TextFormField)).initialValue,
        '하루',
      );
      await tester.enterText(find.byType(TextFormField), '저장하지 않을 이름');
      await _tap(tester, find.widgetWithText(TextButton, '취소'));
      expect(state.userName, '하루');
      expect(find.text('하루님'), findsOneWidget);
      expect(find.byType(TextFormField), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'password reset acknowledges the demo without claiming an email was sent',
    (tester) async {
      final state = AppState();
      await _showAuth(tester, state, const ForgotPasswordPage());
      await tester.enterText(
        find.byType(TextFormField),
        'traveler@example.com',
      );
      await _tap(tester, find.widgetWithText(FilledButton, '재설정 안내 확인'));

      expect(find.text('이메일을 확인했어요'), findsOneWidget);
      expect(
        find.text('체험 버전에서는 이메일을 발송하지 않아요.\n실제 비밀번호도 변경되지 않습니다.'),
        findsOneWidget,
      );
      expect(state.isLoggedIn, isFalse);
    },
  );
}
