import 'package:flutter/material.dart';

import '../../models/travel_route.dart';
import '../theme/app_theme.dart';
import 'route_card.dart';
import 'status_pill.dart';

class RouteSwipeCard extends StatelessWidget {
  const RouteSwipeCard({
    super.key,
    required this.route,
    required this.onTap,
    required this.onStart,
    this.startKey,
  });
  final TravelRoute route;
  final Key? startKey;
  final VoidCallback onTap;
  final VoidCallback? onStart;

  String get title {
    if (route.recommended) return '갈아타슈 추천';
    if (route.transfers == 0) return '환승 없이';
    return '환승 ${route.transfers}회';
  }

  String get info {
    if (route.transfers == 0) return '${route.walkLabel} · 갈아타지 않아요';
    final margin = route.marginMinutes;
    return [
      route.walkLabel,
      if (margin != null) '환승 여유 $margin분',
      if (route.tightestTransferGrade case final grade?)
        '최소 여유 $grade'
      else if (margin == null)
        '환승 여유 확인 불가',
    ].join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: route.recommended ? AppColors.primaryLight : AppColors.background,
      borderRadius: BorderRadius.circular(16),
      elevation: 3,
      shadowColor: AppColors.primaryDark.withValues(alpha: .2),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  if (route.transfers > 0) ...[
                    const Text(
                      '환승 성공 확률',
                      style: TextStyle(color: AppColors.muted, fontSize: 12),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: TransferProbabilityPill(
                        route.probability,
                        label: route.probabilityLabel,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (route.minutes == null)
                    const Text(
                      '시간 미정',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    )
                  else ...[
                    Text(
                      '${route.minutes}',
                      style: AppNumbers.large.copyWith(color: AppColors.text),
                    ),
                    const Padding(
                      padding: EdgeInsets.only(left: 2, bottom: 3),
                      child: Text(
                        '분',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                  if (route.estimated) ...[
                    const SizedBox(width: 10),
                    const Padding(
                      padding: EdgeInsets.only(bottom: 3),
                      child: StatusPill(
                        '배차간격 기반 예상',
                        color: AppColors.amber,
                        background: AppColors.amberLight,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              RouteSegmentBar(route: route),
              const SizedBox(height: 10),
              Text(
                info,
                style: const TextStyle(color: AppColors.muted, fontSize: 14),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton.icon(
                  key: startKey,
                  onPressed: onStart,
                  style: FilledButton.styleFrom(minimumSize: Size.zero),
                  icon: const Icon(Icons.near_me_rounded, size: 18),
                  label: const Text('안내 시작'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
