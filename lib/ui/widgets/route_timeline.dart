import 'package:flutter/material.dart';

import '../../models/travel_route.dart';
import '../theme/app_theme.dart';
import 'route_card.dart';
import 'status_pill.dart';

class RouteTimeline extends StatelessWidget {
  const RouteTimeline({super.key, required this.route});
  final TravelRoute route;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      _TimelineStop(
        title: route.origin.name,
        subtitle: '출발 · 승차 정류장까지 도보',
        icon: Icons.trip_origin_rounded,
        detail: '도보 ${route.walkMinutes ~/ 2}분',
      ),
      _TimelineStop(
        title: route.boardingStop,
        subtitle: '${route.waitMinutes}분 대기 후 탑승 · 예시',
        icon: Icons.directions_bus_rounded,
        badge: BusNumberChip(route.busNumbers.first),
        detail: route.transfers == 0
            ? '버스 ${route.minutes - route.walkMinutes - route.waitMinutes}분'
            : '첫 번째 버스 이용',
      ),
      if (route.transferStop != null)
        _TimelineStop(
          title: route.transferStop!,
          subtitle: '하차 후 연결 정류장으로 이동',
          icon: Icons.transfer_within_a_station_rounded,
          badge: Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              BusNumberChip(route.busNumbers.last, blue: true),
              TransferProbabilityPill(route.probability),
            ],
          ),
          detail: route.marginMinutes == null
              ? '환승 여유 확인 불가'
              : '환승 여유 ${route.marginMinutes}분',
          blue: true,
        ),
      _TimelineStop(
        title: route.arrivalStop,
        subtitle: '버스에서 내려 목적지로 이동',
        icon: Icons.directions_walk_rounded,
        detail: '도보 ${route.walkMinutes - route.walkMinutes ~/ 2}분',
        blue: route.transfers > 0,
      ),
      _TimelineStop(
        title: route.destination.name,
        subtitle: '목적지 도착',
        icon: Icons.location_on_rounded,
        last: true,
      ),
    ],
  );
}

class _TimelineStop extends StatelessWidget {
  const _TimelineStop({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.detail,
    this.badge,
    this.last = false,
    this.blue = false,
  });
  final String title;
  final String subtitle;
  final IconData icon;
  final String? detail;
  final Widget? badge;
  final bool last;
  final bool blue;

  @override
  Widget build(BuildContext context) {
    final color = blue ? AppColors.blue : AppColors.primary;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 34,
            child: Column(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: blue ? AppColors.blueLight : AppColors.primaryLight,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 18),
                ),
                if (!last)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      color: color.withValues(alpha: .25),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(top: 4, bottom: last ? 0 : 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 3),
                  Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                  if (badge != null) ...[const SizedBox(height: 9), badge!],
                  if (detail != null) ...[
                    const SizedBox(height: 8),
                    Text(detail!, style: TextStyle(fontSize: 12, color: color)),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
