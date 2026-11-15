import 'package:flutter/material.dart';

import '../../../state/app_state.dart';
import '../../widgets/api_action.dart';
import 'widgets/auth_scaffold.dart';

class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({super.key});
  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final _form = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  @override
  void dispose() {
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AuthScaffold(
    title: '새 비밀번호 설정',
    subtitle: '다음 로그인에 사용할 비밀번호를 입력해 주세요.',
    child: Form(
      key: _form,
      child: Column(
        children: [
          TextFormField(
            controller: _password,
            obscureText: true,
            validator: validatePassword,
            decoration: const InputDecoration(labelText: '새 비밀번호'),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _confirmation,
            obscureText: true,
            validator: (v) => v == _password.text ? null : '비밀번호가 일치하지 않아요.',
            decoration: const InputDecoration(labelText: '새 비밀번호 확인'),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: AppScope.of(context).busy
                ? null
                : () async {
                    if (!_form.currentState!.validate()) return;
                    final state = AppScope.of(context);
                    if (await apiAction(
                          context,
                          () => state.changeRecoveredPassword(_password.text),
                        ) &&
                        context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('비밀번호를 변경했어요.')),
                      );
                    }
                  },
            child: const Text('비밀번호 변경'),
          ),
        ],
      ),
    ),
  );
}
