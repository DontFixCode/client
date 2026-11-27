import 'package:flutter/material.dart';

import '../../models/congestion.dart';
import '../../models/travel_route.dart';
import '../theme/app_theme.dart';
import 'app_card.dart';
import 'status_pill.dart';

class RouteCard extends StatelessWidget {
  const RouteCard({super.key, required this.route, required this.onTap});
  final TravelRoute route;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final probability = route.probability;
    return AppCard(
      onTap: onTap,
      borderColor: route.recommended
          ? AppColors.primary.withValues(alpha: .45)
          : AppColors.border,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              StatusPill(
                route.recommended
                    ? '갈아타슈 추천'
                    : route.transfers == 0
                    ? '환승 없이'
                    : route.id == 'fast'
                    ? '가장 빠르게'
                    : '다른 경로',
                icon: route.recommended ? Icons.eco_rounded : null,
                background: route.recommended
                    ? AppColors.lime
                    : AppColors.primaryLight,
              ),
              const Spacer(),
              const Icon(
                Icons.arrow_forward_rounded,
                color: AppColors.muted,
                size: 19,
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (route.estimated) ...[
            const StatusPill('배차간격 기반 예상', background: AppColors.amberLight),
            const SizedBox(height: 12),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (route.minutes == null)
                Text('시간 미정', style: textTheme.titleLarge)
              else ...[
                Text('${route.minutes}', style: textTheme.displaySmall),
                const Padding(
                  padding: EdgeInsets.only(left: 3, bottom: 4),
                  child: Text(
                    '분',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
              const SizedBox(width: 14),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 5),
                  child: Text(
                    route.transfers == 0
                        ? '${route.walkLabel} · 환승 없음'
                        : [
                            route.walkLabel,
                            '환승 ${route.transfers}회',
                            if (route.tightestTransferGrade case final grade?)
                              '최소 여유 $grade',
                          ].join(' · '),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.muted,
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (!route.isLive) ...[
            const SizedBox(height: 14),
            RouteSegmentBar(route: route),
          ],
          const SizedBox(height: 14),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 7,
            runSpacing: 6,
            children: [
              const Icon(
                Icons.directions_walk_rounded,
                color: AppColors.muted,
                size: 17,
              ),
              for (var i = 0; i < route.busNumbers.length; i++) ...[
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 16,
                  color: AppColors.muted,
                ),
                BusNumberChip(
                  route.busNumbers[i],
                  blue: i > 0,
                  type: route.busType(i),
                ),
              ],
              const Icon(
                Icons.chevron_right_rounded,
                size: 16,
                color: AppColors.muted,
              ),
              const Icon(
                Icons.directions_walk_rounded,
                color: AppColors.muted,
                size: 17,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${route.boardingStop}에서 탑승',
            style: const TextStyle(fontSize: 12, color: AppColors.muted),
          ),
          if (routeCongestionSummary(route.busLegs) case final String summary)
            Text(summary, style: textTheme.bodySmall),
          const SizedBox(height: 14),
          const Divider(),
          const SizedBox(height: 14),
          if (route.transfers > 0)
            Row(
              children: [
                Icon(
                  probability == null
                      ? Icons.help_outline_rounded
                      : Icons.check_circle_outline_rounded,
                  color: probability == null
                      ? AppColors.muted
                      : AppColors.primary,
                  size: 17,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    route.isLive && route.transfers > 1
                        ? '환승 ${route.transfers}회 · 상세에서 연결별 평가 확인'
                        : probability == null
                        ? '환승 확률 확인 불가'
                        : '환승 성공 가능성',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: probability == null
                          ? AppColors.muted
                          : AppColors.primary,
                    ),
                  ),
                ),
                if (probability != null)
                  TransferProbabilityPill(
                    probability,
                    label: route.probabilityLabel,
                  ),
              ],
            )
          else
            const Row(
              children: [
                Icon(
                  Icons.chair_alt_outlined,
                  color: AppColors.primary,
                  size: 17,
                ),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '갈아타는 걱정 없이 한 번에 가요',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          if (route.recommended ||
              route.estimated ||
              (route.isLive && !route.startable)) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                route.reason,
                style: const TextStyle(fontSize: 12, color: AppColors.primary),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class BusNumberChip extends StatelessWidget {
  const BusNumberChip(this.number, {super.key, this.blue = false, this.type});
  final String number;
  final bool blue;
  final String? type;

  Color? get typeColor {
    final value = type ?? '';
    if (value.contains('급행')) return AppColors.busExpress;
    if (value.contains('간선')) return AppColors.busTrunk;
    if (value.contains('지선')) return AppColors.busFeeder;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final fill = typeColor;
    final color = fill != null
        ? Colors.white
        : blue
        ? AppColors.blue
        : AppColors.primaryDark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: fill ?? (blue ? AppColors.blueLight : AppColors.primaryLight),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.directions_bus_rounded, size: 14, color: color),
          const SizedBox(width: 4),
          Text(number, style: AppNumbers.small.copyWith(color: color)),
        ],
      ),
    );
  }
}

class RouteSegmentBar extends StatelessWidget {
  const RouteSegmentBar({super.key, required this.route});
  final TravelRoute route;
  @override
  Widget build(BuildContext context) => route.isLive
      ? Wrap(
          spacing: 6,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (var i = 0; i < route.busNumbers.length; i++) ...[
              if (i > 0) const Icon(Icons.chevron_right, size: 16),
              BusNumberChip(
                route.busNumbers[i],
                blue: i > 0,
                type: route.busType(i),
              ),
            ],
          ],
        )
      : Row(
          children: [
            Expanded(flex: 8, child: _walkSegment()),
            for (var i = 0; i < route.busNumbers.length; i++) ...[
              const SizedBox(width: 4),
              if (i > 0) ...[
                Tooltip(
                  message: route.marginMinutes == null
                      ? '환승 여유 확인 불가'
                      : '환승 여유 ${route.marginMinutes}분',
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.amber,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      route.marginMinutes == null
                          ? '미정'
                          : '${route.marginMinutes}분',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
              ],
              Expanded(
                flex: route.transfers == 0 ? 80 : 36,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    color: i == 0 ? AppColors.primary : AppColors.blue,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    route.busNumbers[i],
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(width: 4),
            Expanded(flex: 8, child: _walkSegment()),
          ],
        );

  Widget _walkSegment() => Container(
    height: 7,
    decoration: BoxDecoration(
      color: AppColors.border,
      borderRadius: BorderRadius.circular(5),
    ),
  );
}
