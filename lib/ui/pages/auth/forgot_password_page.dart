import 'package:flutter/material.dart';

import '../../../config/app_routes.dart';
import '../../../state/app_state.dart';
import '../../widgets/api_action.dart';
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
    title: _confirmed ? '이메일을 확인해 주세요' : '비밀번호를 잊으셨나요?',
    subtitle: _confirmed
        ? (AppScope.of(context).demoMode
              ? '비밀번호 재설정 화면 체험이 완료되었어요.'
              : '재설정 링크를 통해 새 비밀번호를 입력해 주세요.')
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
                    Text(
                      AppScope.of(context).demoMode
                          ? '체험 버전에서는 이메일을 발송하지 않아요.\n실제 비밀번호도 변경되지 않습니다.'
                          : '가입된 이메일이라면 재설정 안내가 도착해요.\n메일의 링크를 열어 새 비밀번호를 설정해 주세요.',
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
                  onPressed: AppScope.of(context).busy
                      ? null
                      : () async {
                          if (!_formKey.currentState!.validate()) return;
                          final state = AppScope.of(context);
                          if (await apiAction(
                                context,
                                () => state.resetPassword(_email.text.trim()),
                              ) &&
                              mounted) {
                            setState(() => _confirmed = true);
                          }
                        },
                  child: const Text('재설정 안내 확인'),
                ),
                const SizedBox(height: 20),
                Text(
                  AppScope.of(context).demoMode
                      ? '이메일 확인 후 재설정 안내를 보여드려요.\n이 화면에서는 실제 메일이 발송되지 않아요.'
                      : '재설정 이메일이 오지 않으면 스팸함을 확인해 주세요.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.muted, fontSize: 13),
                ),
              ],
            ),
          ),
  );
}
