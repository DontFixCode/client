import 'package:flutter/material.dart';

import '../../../config/app_routes.dart';
import '../../../state/app_state.dart';
import '../../theme/app_theme.dart';
import 'widgets/auth_scaffold.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _login() {
    if (!_formKey.currentState!.validate()) return;
    final email = _email.text.trim();
    AppScope.of(context).signIn(name: email.split('@').first, email: email);
    Navigator.pushNamedAndRemoveUntil(context, AppRoutes.main, (_) => false);
  }

  @override
  Widget build(BuildContext context) => AuthScaffold(
    title: '다시 만나 반가워요',
    subtitle: '오늘의 이동도, 버스로 함께해요.',
    child: Form(
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
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email],
              decoration: const InputDecoration(
                hintText: 'hello@example.com',
                prefixIcon: Icon(Icons.mail_outline_rounded, size: 20),
              ),
              validator: validateEmail,
            ),
          ),
          AuthField(
            label: '비밀번호',
            child: TextFormField(
              controller: _password,
              obscureText: _obscure,
              enableSuggestions: false,
              autocorrect: false,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _login(),
              decoration: InputDecoration(
                hintText: '8자 이상 입력해 주세요',
                prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                suffixIcon: IconButton(
                  tooltip: _obscure ? '비밀번호 보기' : '비밀번호 숨기기',
                  onPressed: () => setState(() => _obscure = !_obscure),
                  icon: Icon(
                    _obscure
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    size: 20,
                  ),
                ),
              ),
              validator: validatePassword,
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () =>
                  Navigator.pushNamed(context, AppRoutes.forgotPassword),
              child: const Text(
                '비밀번호를 잊으셨나요?',
                style: TextStyle(fontSize: 13, color: AppColors.muted),
              ),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(onPressed: _login, child: const Text('로그인')),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: () {
              AppScope.of(context)
                  .signIn(name: '버스로 여행자', email: 'demo@busro.example');
              Navigator.pushNamedAndRemoveUntil(
                context,
                AppRoutes.main,
                (_) => false,
              );
            },
            icon: const Icon(Icons.directions_bus_outlined, size: 19),
            label: const Text('체험 계정으로 시작'),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                '아직 계정이 없으신가요?',
                style: TextStyle(color: AppColors.muted, fontSize: 13),
              ),
              TextButton(
                onPressed: () => Navigator.pushNamed(context, AppRoutes.signup),
                child: const Text('회원가입'),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
