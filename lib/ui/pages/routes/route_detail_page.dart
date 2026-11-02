import 'package:flutter/material.dart';

import '../../../config/app_routes.dart';
import '../../../models/travel_route.dart';
import '../../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_card.dart';
import '../../widgets/demo_notice.dart';
import '../../widgets/route_card.dart';
import '../../widgets/route_map.dart';
import '../../widgets/route_timeline.dart';
import '../../widgets/section_header.dart';
import '../../widgets/status_pill.dart';

class RouteDetailPage extends StatelessWidget {
  const RouteDetailPage({super.key, required this.route});
  final TravelRoute route;

  Future<void> _start(BuildContext context) async {
    final state = AppScope.of(context);
    if (state.activeRoute != null) {
      final replace = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('진행 중인 안내가 있어요'),
          content: const Text(
            '기존 안내를 이어보거나, 선택한 경로로 새로 시작할 수 있어요. 새로 시작하면 이전 안내는 종료돼요.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('기존 안내 이어보기'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('새로 시작'),
            ),
          ],
        ),
      );
      if (!context.mounted || replace == null) return;
      if (!replace) {
        Navigator.pushNamed(context, AppRoutes.guide);
        return;
      }
    }
    state.startJourney(route);
    if (context.mounted) Navigator.pushNamed(context, AppRoutes.guide);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('선택한 경로')),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
          children: [
            Row(
              children: [
                StatusPill(
                  route.recommended
                      ? '여유 있는 환승'
                      : route.transfers == 0
                      ? '환승 없는 경로'
                      : '환승 1회',
                  icon: Icons.route_rounded,
                ),
                const Spacer(),
                const Text(
                  '경로 체험',
                  style: TextStyle(fontSize: 12, color: AppColors.muted),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              '${route.origin.name}에서\n${route.destination.name}까지',
              style: textTheme.headlineSmall,
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('${route.minutes}분', style: textTheme.displaySmall),
                const SizedBox(width: 14),
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    '도보 ${route.walkMinutes}분 · 환승 ${route.transfers}회',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.muted,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            RouteSegmentBar(route: route),
            const SizedBox(height: 22),
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: RouteMap(
                height: 230,
                originLabel: route.origin.name,
                destinationLabel: route.destination.name,
              ),
            ),
            const SizedBox(height: 20),
            AppCard(
              color: AppColors.primaryLight,
              borderColor: AppColors.primaryLight,
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.eco_outlined,
                        color: AppColors.primary,
                        size: 21,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          route.transfers == 0
                              ? '편안하게, 한 번에'
                              : route.probability == null
                              ? '환승 정보 확인이 필요해요'
                              : '환승까지 미리 살펴봤어요',
                          style: textTheme.titleSmall?.copyWith(
                            color: AppColors.primaryDark,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    route.reason,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.primary,
                    ),
                  ),
                  if (route.transfers > 0) ...[
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _Metric(
                            label: '환승 성공 가능성',
                            value: route.probabilityLabel,
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 34,
                          color: AppColors.primary.withValues(alpha: .15),
                        ),
                        Expanded(
                          child: _Metric(
                            label: '환승 여유',
                            value: route.marginMinutes == null
                                ? '확인 불가'
                                : '${route.marginMinutes}분',
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 28),
            const SectionHeader('한눈에 보는 이동 순서'),
            const SizedBox(height: 20),
            AppCard(child: RouteTimeline(route: route)),
            const SizedBox(height: 24),
            const DemoNotice(message: '노선·지도·예측은 UI 체험을 위한 예시예요'),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
          child: FilledButton.icon(
            key: const ValueKey('startJourneyButton'),
            onPressed: () => _start(context),
            icon: const Icon(Icons.near_me_rounded, size: 18),
            label: const Text('이 경로로 안내 시작'),
          ),
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(
        label,
        style: const TextStyle(fontSize: 11, color: AppColors.primary),
      ),
      const SizedBox(height: 3),
      Text(
        value,
        style: Theme.of(context).textTheme.titleLarge
            ?.copyWith(color: AppColors.primaryDark),
      ),
    ],
  );
}
