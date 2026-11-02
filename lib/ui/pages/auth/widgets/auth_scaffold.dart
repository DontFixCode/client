import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import '../../../widgets/bus_logo.dart';
import '../../../widgets/demo_notice.dart';

class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(),
    body: SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const BusLogo(size: 38),
                const SizedBox(height: 36),
                Text(title, style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 10),
                Text(subtitle, style: const TextStyle(color: AppColors.muted)),
                const SizedBox(height: 32),
                child,
                const SizedBox(height: 30),
                const DemoNotice(message: '화면 체험 모드 · 실제 계정 인증 없이 동작해요'),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class AuthField extends StatelessWidget {
  const AuthField({super.key, required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        child,
      ],
    ),
  );
}

String? validateEmail(String? value) {
  final email = value?.trim() ?? '';
  if (email.isEmpty) return '이메일을 입력해 주세요.';
  if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
    return '이메일 주소를 다시 확인해 주세요.';
  }
  return null;
}

String? validatePassword(String? value) {
  if (value == null || value.isEmpty) return '비밀번호를 입력해 주세요.';
  if (value.length < 8) return '비밀번호는 8자 이상 입력해 주세요.';
  return null;
}
