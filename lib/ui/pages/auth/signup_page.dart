import 'package:flutter/material.dart';

import '../../../config/app_routes.dart';
import '../../../state/app_state.dart';
import '../../theme/app_theme.dart';
import 'widgets/auth_scaffold.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  bool _obscure = true;
  bool _serviceAgreed = false;
  bool _privacyAgreed = false;
  bool _showAgreementError = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  void _signup() {
    final valid = _formKey.currentState!.validate();
    setState(() => _showAgreementError = !_serviceAgreed || !_privacyAgreed);
    if (!valid || _showAgreementError) return;
    AppScope.of(context)
        .signIn(name: _name.text.trim(), email: _email.text.trim());
    Navigator.pushNamedAndRemoveUntil(context, AppRoutes.main, (_) => false);
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('반가워요! 버스로 화면 체험을 시작합니다.')));
  }

  void _showTerms(bool privacy) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                privacy ? '개인정보 안내' : '서비스 이용 안내',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              Text(
                privacy
                    ? '현재는 프론트엔드 체험 버전입니다. 입력한 이름과 이메일은 앱 실행 중에만 사용하며 외부로 전송하지 않습니다. 비밀번호는 저장하지 않습니다. 앱을 다시 시작하면 체험 정보가 초기화됩니다.'
                    : '버스로는 대전에서의 편안한 버스 이동을 돕는 서비스입니다. 현재 경로와 환승 확률, 지도 및 운행정보는 화면 체험을 위한 예시이며 실제 이동 안내에 사용할 수 없습니다. 실제 계정은 생성되지 않습니다.',
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('확인했어요'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _agreement({
    required bool value,
    required String label,
    required ValueChanged<bool> onChanged,
    required VoidCallback onView,
  }) => Row(
    children: [
      Checkbox(
        value: value,
        onChanged: (checked) => onChanged(checked ?? false),
      ),
      Expanded(
        child: GestureDetector(
          onTap: () => onChanged(!value),
          child: Text(label, style: const TextStyle(fontSize: 13)),
        ),
      ),
      IconButton(
        tooltip: '$label 보기',
        onPressed: onView,
        icon: const Icon(
          Icons.chevron_right_rounded,
          size: 20,
          color: AppColors.muted,
        ),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) => AuthScaffold(
    title: '여유로운 이동의 시작',
    subtitle: '버스로와 함께, 대전의 일상을 이어가요.',
    child: Form(
      key: _formKey,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AuthField(
            label: '이름',
            child: TextFormField(
              controller: _name,
              textInputAction: TextInputAction.next,
              maxLength: 20,
              decoration: const InputDecoration(
                hintText: '어떻게 불러드릴까요?',
                counterText: '',
              ),
              validator: (value) =>
                  (value?.trim().isEmpty ?? true) ? '이름을 입력해 주세요.' : null,
            ),
          ),
          AuthField(
            label: '이메일',
            child: TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(hintText: 'hello@example.com'),
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
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                hintText: '8자 이상 입력해 주세요',
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
          AuthField(
            label: '비밀번호 확인',
            child: TextFormField(
              controller: _confirmation,
              obscureText: _obscure,
              enableSuggestions: false,
              autocorrect: false,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                hintText: '비밀번호를 한 번 더 입력해 주세요',
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return '비밀번호를 한 번 더 입력해 주세요.';
                }
                return value != _password.text ? '비밀번호가 일치하지 않아요.' : null;
              },
            ),
          ),
          const Divider(),
          const SizedBox(height: 8),
          _agreement(
            value: _serviceAgreed,
            label: '서비스 이용 안내 확인 (필수)',
            onChanged: (v) => setState(() => _serviceAgreed = v),
            onView: () => _showTerms(false),
          ),
          _agreement(
            value: _privacyAgreed,
            label: '개인정보 안내 확인 (필수)',
            onChanged: (v) => setState(() => _privacyAgreed = v),
            onView: () => _showTerms(true),
          ),
          if (_showAgreementError && (!_serviceAgreed || !_privacyAgreed))
            const Padding(
              padding: EdgeInsets.fromLTRB(12, 4, 0, 8),
              child: Text(
                '필수 안내를 확인하고 동의해 주세요.',
                style: TextStyle(color: AppColors.error, fontSize: 12),
              ),
            ),
          const SizedBox(height: 20),
          FilledButton(onPressed: _signup, child: const Text('가입하고 시작하기')),
          const SizedBox(height: 14),
          TextButton(
            onPressed: () =>
                Navigator.pushReplacementNamed(context, AppRoutes.login),
            child: const Text('이미 계정이 있어요'),
          ),
        ],
      ),
    ),
  );
}
