import 'package:flutter/material.dart';

import '../../../config/app_routes.dart';
import '../../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_card.dart';
import '../../widgets/api_action.dart';
import '../../widgets/bus_logo.dart';
import '../../widgets/demo_notice.dart';
import '../../widgets/section_header.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  Future<bool> _confirm(
    BuildContext context, {
    required String title,
    required String message,
    required String action,
    bool destructive = false,
  }) async =>
      await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: destructive
                  ? TextButton.styleFrom(foregroundColor: AppColors.error)
                  : null,
              child: Text(action),
            ),
          ],
        ),
      ) ??
      false;

  Future<void> _editName(BuildContext context, AppState state) async {
    var editedName = state.userName ?? '';
    final formKey = GlobalKey<FormState>();
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('이름 변경'),
        content: Form(
          key: formKey,
          child: TextFormField(
            initialValue: editedName,
            onChanged: (value) => editedName = value,
            autofocus: true,
            maxLength: 20,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              labelText: '이름',
              hintText: '이름을 입력해 주세요',
            ),
            validator: (value) =>
                (value?.trim().isEmpty ?? true) ? '이름을 입력해 주세요.' : null,
            onFieldSubmitted: (_) {
              if (formKey.currentState!.validate()) {
                Navigator.pop(dialogContext, editedName.trim());
              }
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(dialogContext, editedName.trim());
              }
            },
            child: const Text('저장'),
          ),
        ],
      ),
    );
    if (name != null && context.mounted) {
      await apiAction(context, () => state.updateProfile(name: name));
    }
  }

  void _about(BuildContext context) => showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const BusLogo(size: 32),
      content: Text(
        !AppScope.of(context).demoMode
            ? '대전 버스 길찾기 · 서버 연동 버전\n\n자료가 부족한 시간·확률은 확인 불가로 표시합니다. 카카오 지도에서 경로를 확인할 수 있습니다. 백그라운드 위치·알림, 대체 경로 추천은 준비 중입니다.'
            : '대전의 일상을 잇는, 여유로운 버스 길찾기\n\n버전 1.0.0 · 프론트엔드 체험판\n\n배경은 카카오 지도이며, 경로·운행정보와 환승 확률은 예시입니다. 계정과 이동 기록은 앱 실행 중에만 유지되며 서버에 저장되지 않습니다.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('확인'),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('내정보'),
        automaticallyImplyLeading: false,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        children: [
          if (state.isLoggedIn)
            AppCard(
              color: AppColors.primaryLight,
              borderColor: AppColors.primaryLight,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 54,
                        height: 54,
                        decoration: const BoxDecoration(
                          color: AppColors.surface,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.person_outline_rounded,
                          size: 30,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${state.userName}님',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            Text(
                              state.email ?? '',
                              style: const TextStyle(
                                color: AppColors.muted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: '이름 변경',
                        onPressed: state.busy
                            ? null
                            : () => _editName(context, state),
                        icon: const Icon(
                          Icons.edit_outlined,
                          size: 20,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    '오늘도 한 정거장 더 여유롭게.',
                    style: TextStyle(color: AppColors.primary, fontSize: 14),
                  ),
                ],
              ),
            )
          else
            AppCard(
              color: AppColors.primaryLight,
              borderColor: AppColors.primaryLight,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.waving_hand_outlined,
                    color: AppColors.primary,
                    size: 28,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    '반가워요, 여행자님',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    '로그인하고 나만의 이동을 시작해요.',
                    style: TextStyle(color: AppColors.muted, fontSize: 14),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton(
                          onPressed: () =>
                              Navigator.pushNamed(context, AppRoutes.login),
                          child: const Text('로그인'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () =>
                              Navigator.pushNamed(context, AppRoutes.signup),
                          child: const Text('회원가입'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          const SizedBox(height: 28),
          const SectionHeader('저장한 장소'),
          const SizedBox(height: 12),
          if (state.favoritePlaces.isEmpty)
            const AppCard(
              child: Row(
                children: [
                  Icon(Icons.bookmark_border_rounded, color: AppColors.muted),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '장소 검색에서 별을 눌러\n자주 가는 곳을 저장해 보세요.',
                      style: TextStyle(color: AppColors.muted, fontSize: 14),
                    ),
                  ),
                ],
              ),
            )
          else
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (
                    var index = 0;
                    index < state.favoritePlaces.length;
                    index++
                  ) ...[
                    if (index > 0) const Divider(indent: 56, endIndent: 16),
                    ListTile(
                      contentPadding: const EdgeInsets.only(left: 16, right: 8),
                      leading: const Icon(
                        Icons.place_outlined,
                        color: AppColors.primary,
                        size: 22,
                      ),
                      title: Text(
                        state.favoritePlaces[index].name,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        state.favoritePlaces[index].address,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.muted,
                        ),
                      ),
                      onTap: () {
                        state.setDestination(state.favoritePlaces[index]);
                        Navigator.pushNamedAndRemoveUntil(
                          context,
                          AppRoutes.main,
                          (_) => false,
                        );
                      },
                      trailing: IconButton(
                        tooltip: '${state.favoritePlaces[index].name} 저장 해제',
                        onPressed: () =>
                            state.toggleFavorite(state.favoritePlaces[index]),
                        icon: const Icon(
                          Icons.star_rounded,
                          color: AppColors.amber,
                          size: 22,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          const SizedBox(height: 28),
          const SectionHeader('설정'),
          const SizedBox(height: 12),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  secondary: const Icon(
                    Icons.notifications_none_rounded,
                    color: AppColors.primary,
                    size: 23,
                  ),
                  title: const Text(
                    '이동 안내 알림',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    state.demoMode ? '하차·환승 알림 화면 설정 체험' : '시스템 알림 준비 중',
                    style: TextStyle(fontSize: 12, color: AppColors.muted),
                  ),
                  value: state.demoMode && state.alertsEnabled,
                  onChanged: state.demoMode ? state.setAlertsEnabled : null,
                ),
                const Divider(indent: 56, endIndent: 16),
                ListTile(
                  leading: const Icon(
                    Icons.info_outline_rounded,
                    color: AppColors.primary,
                    size: 22,
                  ),
                  title: const Text(
                    '갈아타슈 소개',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  trailing: const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.muted,
                  ),
                  onTap: () => _about(context),
                ),
                if (state.isLoggedIn) ...[
                  const Divider(indent: 56, endIndent: 16),
                  ListTile(
                    leading: const Icon(
                      Icons.logout_rounded,
                      color: AppColors.primary,
                      size: 22,
                    ),
                    title: const Text(
                      '로그아웃',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    trailing: const Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.muted,
                    ),
                    onTap: () async {
                      if (await _confirm(
                        context,
                        title: '로그아웃할까요?',
                        message: state.demoMode
                            ? '이 기기의 체험 로그인을 종료합니다.'
                            : '이 기기에서 로그아웃해요. 서버의 진행 중 이동과 기록은 유지됩니다.',
                        action: '로그아웃',
                      )) {
                        if (context.mounted &&
                            await apiAction(context, state.signOut) &&
                            context.mounted) {
                          Navigator.pushNamedAndRemoveUntil(
                            context,
                            AppRoutes.welcome,
                            (_) => false,
                          );
                        }
                      }
                    },
                  ),
                ],
              ],
            ),
          ),
          if (state.isLoggedIn) ...[
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                style: TextButton.styleFrom(foregroundColor: AppColors.muted),
                onPressed: state.busy
                    ? null
                    : () async {
                        if (await _confirm(
                          context,
                          title: state.demoMode ? '체험 정보를 삭제할까요?' : '회원 탈퇴할까요?',
                          message: state.demoMode
                              ? '회원 탈퇴를 체험합니다. 현재 이름, 이메일, 저장한 장소와 이동 기록이 모두 삭제됩니다.'
                              : '탈퇴하면 진행 중인 이동이 취소되고 이 계정으로 서비스를 이용할 수 없어요. 되돌릴 수 없으며 계정과 이동 기록은 서버에 보관됩니다.',
                          action: state.demoMode ? '정보 삭제' : '탈퇴하기',
                          destructive: true,
                        )) {
                          if (context.mounted) {
                            await apiAction(context, state.deleteAccount);
                          }
                        }
                      },
                child: const Text('회원 탈퇴', style: TextStyle(fontSize: 12)),
              ),
            ),
          ],
          const SizedBox(height: 28),
          DemoNotice(
            message: state.demoMode
                ? '체험 정보는 앱을 다시 시작하면 초기화돼요'
                : '회원정보·이동 기록은 서버에 저장돼요. 저장한 장소는 앱 실행 중에만 유지돼요.',
          ),
          const SizedBox(height: 8),
          const Text(
            'GALATASHU · A LITTLE MORE ROOM TO GO',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              letterSpacing: 1.6,
              color: AppColors.muted,
            ),
          ),
        ],
      ),
    );
  }
}
