import 'package:flutter/material.dart';

import '../../../config/app_routes.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_card.dart';
import 'widgets/auth_scaffold.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  bool _confirmed = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AuthScaffold(
    title: _confirmed ? '이메일을 확인했어요' : '비밀번호를 잊으셨나요?',
    subtitle: _confirmed
        ? '비밀번호 재설정 화면 체험이 완료되었어요.'
        : '가입할 때 사용한 이메일을 입력해 주세요.',
    child: _confirmed
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppCard(
                color: AppColors.primaryLight,
                child: Column(
                  children: [
                    const Icon(
                      Icons.mark_email_read_outlined,
                      size: 44,
                      color: AppColors.primary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _email.text.trim(),
                      style: Theme.of(context).textTheme.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      '체험 버전에서는 이메일을 발송하지 않아요.\n실제 비밀번호도 변경되지 않습니다.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              FilledButton(
                onPressed: () =>
                    Navigator.pushReplacementNamed(context, AppRoutes.login),
                child: const Text('로그인으로 돌아가기'),
              ),
              TextButton(
                onPressed: () => setState(() => _confirmed = false),
                child: const Text('다른 이메일 입력'),
              ),
            ],
          )
        : Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AuthField(
                  label: '이메일',
                  child: TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(
                      hintText: 'hello@example.com',
                      prefixIcon: Icon(Icons.mail_outline_rounded, size: 20),
                    ),
                    validator: validateEmail,
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () {
                    if (_formKey.currentState!.validate()) {
                      setState(() => _confirmed = true);
                    }
                  },
                  child: const Text('재설정 안내 확인'),
                ),
                const SizedBox(height: 20),
                const Text(
                  '이메일 확인 후 재설정 안내를 보여드려요.\n이 화면에서는 실제 메일이 발송되지 않아요.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.muted, fontSize: 13),
                ),
              ],
            ),
          ),
  );
}
