import 'dart:convert';

import 'package:bus/state/app_state.dart';
import 'package:bus/ui/widgets/api_action.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  testWidgets(
    'SDK email failures and invalid credentials show friendly errors',
    (tester) async {
      final auth = GoTrueClient(
        url: 'https://auth.example.test/auth/v1',
        flowType: AuthFlowType.implicit,
        autoRefreshToken: false,
        httpClient: MockClient((request) async {
          final message = switch (request.url.path) {
            '/auth/v1/signup' => 'Error sending confirmation email',
            '/auth/v1/recover' => 'Error sending recovery email',
            '/auth/v1/token' => 'Invalid login credentials',
            _ => throw StateError('Unexpected request: ${request.url.path}'),
          };
          final login = request.url.path.endsWith('/token');
          return http.Response(
            jsonEncode({
              'code': login ? 'invalid_credentials' : 'unexpected_failure',
              'message': message,
            }),
            login ? 400 : 500,
            headers: {'x-supabase-api-version': '2024-01-01'},
          );
        }),
      );
      final state = AppState();
      addTearDown(auth.dispose);
      addTearDown(state.dispose);
      bool? succeeded;
      final actions = <String, Future<void> Function()>{
        '가입': () async {
          await auth.signUp(
            email: 'test@example.test',
            password: 'test-password',
          );
        },
        '재설정': () => auth.resetPasswordForEmail('test@example.test'),
        '로그인': () async {
          await auth.signInWithPassword(
            email: 'test@example.test',
            password: 'test-password',
          );
        },
        '서버 오류': () async => throw AuthRetryableFetchException(
          message: '<html>Bad Gateway</html>',
          statusCode: '502',
        ),
      };
      await tester.pumpWidget(
        AppScope(
          state: state,
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  return Column(
                    children: [
                      for (final action in actions.entries)
                        TextButton(
                          onPressed: () async {
                            succeeded = await apiAction(context, action.value);
                          },
                          child: Text(action.key),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      );

      for (final (button, message) in [
        ('가입', '인증 이메일을 보내지 못했어요. 관리자에게 문의해 주세요.'),
        ('재설정', '비밀번호 재설정 이메일을 보내지 못했어요. 관리자에게 문의해 주세요.'),
        ('로그인', '이메일 또는 비밀번호를 확인해 주세요.'),
        ('서버 오류', '인증 서버에서 오류가 발생했어요. 잠시 후 다시 시도해 주세요.'),
      ]) {
        succeeded = null;
        await tester.tap(find.text(button));
        await tester.pumpAndSettle();
        expect(succeeded, isFalse);
        expect(state.busy, isFalse);
        expect(auth.currentSession, isNull);
        expect(find.text(message), findsOneWidget);
        expect(find.textContaining('unexpected_failure'), findsNothing);
        await tester.pump(const Duration(seconds: 5));
        await tester.pumpAndSettle();
      }
    },
  );
}
