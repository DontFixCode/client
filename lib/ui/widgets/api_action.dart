import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../state/app_state.dart';

Future<bool> apiAction(
  BuildContext context,
  Future<void> Function() action,
) async {
  final state = AppScope.of(context);
  try {
    await state.perform(action);
    return true;
  } catch (error) {
    if (context.mounted) {
      final message = error is AuthException
          ? switch (error.code) {
              'invalid_credentials' => '이메일 또는 비밀번호를 확인해 주세요.',
              'email_not_confirmed' => '인증 이메일을 먼저 확인해 주세요.',
              'user_already_exists' => '이미 가입된 이메일이에요.',
              _
                  when error.message.contains(
                    'Error sending confirmation email',
                  ) =>
                '인증 이메일을 보내지 못했어요. 관리자에게 문의해 주세요.',
              _ when error.message.contains('Error sending recovery email') =>
                '비밀번호 재설정 이메일을 보내지 못했어요. 관리자에게 문의해 주세요.',
              _ when error.statusCode?.startsWith('5') ?? false =>
                '인증 서버에서 오류가 발생했어요. 잠시 후 다시 시도해 주세요.',
              _ => error.message,
            }
          : error.toString();
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
    return false;
  }
}
