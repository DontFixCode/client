import 'package:flutter/material.dart';

import '../../config/app_routes.dart';
import '../theme/app_theme.dart';
import '../widgets/bus_logo.dart';
import '../widgets/route_map.dart';
import '../widgets/status_pill.dart';

class SplashPage extends StatelessWidget {
  const SplashPage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight - 56),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const BusLogo(),
                    Text(
                      'DAEJEON',
                      style: Theme.of(context).textTheme.labelMedium
                          ?.copyWith(color: AppColors.muted, letterSpacing: 2),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 38),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const StatusPill(
                        '대전에서 시작하는 여유로운 이동',
                        icon: Icons.spa_outlined,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        '버스 타는 일상에,\n작은 여유를.',
                        style: Theme.of(context).textTheme.displaySmall,
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        '갈아탈 수 있을까, 걱정하지 않도록.\n출발부터 도착까지 버스로가 함께해요.',
                        style: TextStyle(color: AppColors.muted, height: 1.8),
                      ),
                      const SizedBox(height: 30),
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          const RouteMap(height: 240),
                          Positioned(
                            bottom: 18,
                            left: 18,
                            right: 18,
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: AppColors.primaryDark,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primaryDark.withValues(
                                      alpha: .12,
                                    ),
                                    blurRadius: 20,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: const Row(
                                children: [
                                  Icon(
                                    Icons.check_circle_rounded,
                                    color: AppColors.lime,
                                    size: 27,
                                  ),
                                  SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '서두르지 않아도 괜찮아요',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 13,
                                          ),
                                        ),
                                        SizedBox(height: 3),
                                        Text(
                                          '환승 여유까지 생각한 길찾기',
                                          style: TextStyle(
                                            color: AppColors.lime,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    '8분\n여유',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: AppColors.lime,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FilledButton(
                      onPressed: () =>
                          Navigator.pushNamed(context, AppRoutes.login),
                      child: const Text('로그인하고 시작하기'),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton(
                      onPressed: () =>
                          Navigator.pushNamed(context, AppRoutes.signup),
                      child: const Text('처음이라면, 회원가입'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pushReplacementNamed(
                        context,
                        AppRoutes.main,
                      ),
                      child: const Text(
                        '먼저 둘러보기',
                        style: TextStyle(color: AppColors.muted, fontSize: 13),
                      ),
                    ),
                    const SizedBox(height: 7),
                    const Text(
                      '대전 일부 구간 · 프론트엔드 체험 버전',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 10, color: AppColors.muted),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
